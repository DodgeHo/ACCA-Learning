#!/usr/bin/env python3
"""Build per-subject OCR packet PDFs for ACCA source materials.

For each subject, detect source PDFs with weak/no extractable text and merge them
into one OCR packet PDF:
  ocr_packets/<subject>/<subject>-ocr-needed.pdf

Also writes a manifest:
  ocr_packets/<subject>/manifest.json
"""

import argparse
import json
import os
import re
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from pypdf import PdfReader, PdfWriter

SUBJECTS = {
    "pm": {"folder_hint": "5-PM"},
    "tx": {"folder_hint": "6-TX"},
    "fr": {"folder_hint": "7-FR"},
    "aa": {"folder_hint": "8-AA"},
    "fm": {"folder_hint": "9-FM"},
    "sbl": {"folder_hint": "10-SBL"},
    "sbr": {"folder_hint": "11-SBR"},
    "afm": {"folder_hint": "12-AFM"},
    "apm": {"folder_hint": "13-APM"},
    "aaa": {"folder_hint": "14-AAA"},
}

HEADER_NOISE = (
    "ACCA",
    "Kaplan",
    "BPP",
    "Page",
    "版权所有",
    "高顿",
    "考官",
)


def safe_text(text: str | None) -> str:
    if not text:
        return ""
    return text.encode("utf-8", errors="ignore").decode("utf-8", errors="ignore")


def normalize_text(text: str) -> str:
    text = safe_text(text).replace("\r\n", "\n").replace("\r", "\n")
    lines = []
    for raw in text.split("\n"):
        s = raw.strip()
        if not s:
            continue
        if len(s) <= 5 and s.isdigit():
            continue
        if any(k in s for k in HEADER_NOISE) and len(s) <= 36:
            continue
        lines.append(s)
    return "\n".join(lines).strip()


def resolve_tool(tool_name: str) -> str | None:
    direct = shutil.which(tool_name)
    if direct:
        return direct

    local = Path(os.environ.get("LOCALAPPDATA", ""))
    candidates = [
        local
        / "Microsoft"
        / "WinGet"
        / "Packages"
        / "oschwartz10612.Poppler_Microsoft.Winget.Source_8wekyb3d8bbwe"
        / "poppler-25.07.0"
        / "Library"
        / "bin"
        / f"{tool_name}.exe",
        local / "Microsoft" / "WinGet" / "Links" / f"{tool_name}.exe",
    ]
    for c in candidates:
        if c.exists():
            return str(c)
    return None


def extract_text_len(pdf_path: Path) -> tuple[int, int, str | None]:
    """Return (text_len, pages, error)."""
    page_count = 0
    try:
        reader = PdfReader(str(pdf_path))
        chunks = []
        for page in reader.pages:
            page_count += 1
            text = normalize_text(page.extract_text() or "")
            if text:
                chunks.append(text)
        raw = "\n".join(chunks).strip()
        if raw:
            return len(raw), page_count, None
    except Exception as e:
        return 0, page_count, f"pypdf_error:{type(e).__name__}"

    # Optional fallback via pdftotext if pypdf produced empty text.
    pdftotext = resolve_tool("pdftotext")
    if pdftotext:
        try:
            result = subprocess.run(
                [pdftotext, "-layout", "-enc", "UTF-8", str(pdf_path), "-"],
                capture_output=True,
                check=False,
            )
            if result.returncode == 0:
                text2 = normalize_text((result.stdout or b"").decode("utf-8", errors="ignore"))
                return len(text2), page_count, None
            return 0, page_count, f"pdftotext_exit:{result.returncode}"
        except Exception as e:
            return 0, page_count, f"pdftotext_error:{type(e).__name__}"

    return 0, page_count, None


def pick_subject_dir(pdf_root: Path, subject: str) -> Path:
    hint = SUBJECTS[subject]["folder_hint"]
    candidates = [p for p in pdf_root.rglob("*") if p.is_dir() and hint in p.name]
    if not candidates:
        raise FileNotFoundError(f"Cannot find subject folder for {subject} under: {pdf_root}")
    candidates.sort(key=lambda p: (len(p.parts), str(p)))
    return candidates[0]


def find_pdfs(subject_dir: Path) -> list[Path]:
    items = []
    for pdf in sorted(subject_dir.rglob("*.pdf")):
        if "无答案" in pdf.name:
            continue
        items.append(pdf)
    return items


def build_subject_packet(
    subject: str,
    pdf_root: Path,
    out_root: Path,
    min_text_threshold: int,
    max_pages_per_pdf: int,
) -> dict:
    subject_dir = pick_subject_dir(pdf_root, subject)
    source_pdfs = find_pdfs(subject_dir)

    flagged = []
    writer = PdfWriter()

    for pdf in source_pdfs:
        text_len, pages, err = extract_text_len(pdf)
        needs_ocr = (text_len < min_text_threshold) or bool(err)
        if pages > max_pages_per_pdf:
            # Very large files are expensive for web OCR; skip from packet but record.
            needs_ocr = False

        if not needs_ocr:
            continue

        try:
            reader = PdfReader(str(pdf))
            for page in reader.pages:
                writer.add_page(page)
            flagged.append(
                {
                    "file": safe_text(pdf.as_posix()),
                    "pages": len(reader.pages),
                    "text_len": text_len,
                    "reason": err or f"text_len<{min_text_threshold}",
                }
            )
        except Exception as e:
            flagged.append(
                {
                    "file": safe_text(pdf.as_posix()),
                    "pages": pages,
                    "text_len": text_len,
                    "reason": f"merge_error:{type(e).__name__}",
                }
            )

    subject_out = out_root / subject
    subject_out.mkdir(parents=True, exist_ok=True)
    packet_pdf = subject_out / f"{subject}-ocr-needed.pdf"

    if writer.get_num_pages() > 0:
        with packet_pdf.open("wb") as f:
            writer.write(f)
    else:
        if packet_pdf.exists():
            packet_pdf.unlink()

    manifest = {
        "subject": subject,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "pdf_root": pdf_root.as_posix(),
        "source_pdf_count": len(source_pdfs),
        "ocr_pdf_count": len(flagged),
        "ocr_packet_pdf": packet_pdf.as_posix() if packet_pdf.exists() else None,
        "min_text_threshold": min_text_threshold,
        "max_pages_per_pdf": max_pages_per_pdf,
        "files": flagged,
    }
    (subject_out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description="Build ACCA OCR packet PDFs by subject")
    parser.add_argument("--subject", choices=sorted(SUBJECTS.keys()), required=True)
    parser.add_argument("--pdf-root", default=".", help="Search root for subject folders")
    parser.add_argument("--out-root", default="ocr_packets", help="Output root for OCR packets")
    parser.add_argument("--min-text-threshold", type=int, default=240)
    parser.add_argument("--max-pages-per-pdf", type=int, default=220)
    args = parser.parse_args()

    pdf_root = Path(args.pdf_root)
    if not pdf_root.exists():
        raise FileNotFoundError(f"pdf root not found: {pdf_root}")

    manifest = build_subject_packet(
        subject=args.subject,
        pdf_root=pdf_root,
        out_root=Path(args.out_root),
        min_text_threshold=args.min_text_threshold,
        max_pages_per_pdf=args.max_pages_per_pdf,
    )
    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
