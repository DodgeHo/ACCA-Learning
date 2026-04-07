#!/usr/bin/env python3
"""Build ACCA question-bank assets from subject PDF folders.

Output for each subject:
  assets/banks/<subject>/data.db
  assets/banks/<subject>/questions.json
  assets/banks/<subject>/manifest.json

Database schema is unchanged; only rows in `questions` are rewritten.
"""

import argparse
import json
import os
import re
import shutil
import sqlite3
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from pypdf import PdfReader

SUBJECTS = {
    "pm": {"folder_hint": "5-PM", "default_mode": "objective"},
    "tx": {"folder_hint": "6-TX", "default_mode": "objective"},
    "fr": {"folder_hint": "7-FR", "default_mode": "objective"},
    "aa": {"folder_hint": "8-AA", "default_mode": "objective"},
    "fm": {"folder_hint": "9-FM", "default_mode": "objective"},
    "sbl": {"folder_hint": "10-SBL", "default_mode": "subjective"},
    "sbr": {"folder_hint": "11-SBR", "default_mode": "subjective"},
    "afm": {"folder_hint": "12-AFM", "default_mode": "subjective"},
    "apm": {"folder_hint": "13-APM", "default_mode": "subjective"},
    "aaa": {"folder_hint": "14-AAA", "default_mode": "subjective"},
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

OPTION_RE = re.compile(
    r"(?ms)(?:^|\n)\s*([A-F])[\.、\)]\s*(.*?)(?=(?:\n\s*[A-F][\.、\)]\s*)|\Z)",
)
ANSWER_RE = re.compile(r"(?:答案|正确答案|Answer|Key)\s*[:：]?\s*([A-F])", re.I)
COMMENTARY_SPLIT_RE = re.compile(r"(?:要点点评|解析|参考答案|Answer\s*Key)\s*[:：]", re.I)


def safe_text(text: str | None) -> str | None:
    if text is None:
        return None
    # Some PDFs may contain lone surrogate code points that SQLite rejects.
    cleaned = text.encode("utf-8", errors="ignore").decode("utf-8", errors="ignore")
    return cleaned.strip()


def resolve_tool(tool_name: str) -> str:
    direct = shutil.which(tool_name)
    if direct:
        return direct

    candidates = []
    local = Path(os.environ.get("LOCALAPPDATA", ""))
    if tool_name.lower() == "tesseract":
        candidates.extend(
            [
                Path("C:/Program Files/Tesseract-OCR/tesseract.exe"),
                local / "Programs" / "Tesseract-OCR" / "tesseract.exe",
            ]
        )
    else:
        candidates.extend(
            [
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
        )

    for c in candidates:
        if c.exists():
            return str(c)

    raise FileNotFoundError(f"Required tool not found: {tool_name}")


def normalize_text(text: str) -> str:
    text = safe_text(text) or ""
    text = text.replace("\r\n", "\n").replace("\r", "\n")
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


def extract_pdf_text(pdf_path: Path) -> str:
    # 1) pypdf text layer
    chunks = []
    try:
        reader = PdfReader(str(pdf_path))
        for page in reader.pages:
            text = normalize_text(page.extract_text() or "")
            if text:
                chunks.append(text)
    except Exception:
        chunks = []

    raw = "\n".join(chunks).strip()
    if len(raw) >= 300:
        return raw

    # 2) poppler pdftotext fallback
    try:
        pdftotext = resolve_tool("pdftotext")
        result = subprocess.run(
            [pdftotext, "-layout", "-enc", "UTF-8", str(pdf_path), "-"],
            capture_output=True,
            check=False,
        )
        if result.returncode == 0:
            text2 = normalize_text((result.stdout or b"").decode("utf-8", errors="ignore"))
            if len(text2) >= 300:
                return text2
    except Exception:
        pass

    return raw


def ocr_pdf_text(pdf_path: Path, max_pages: int = 36) -> str:
    lang = "chi_sim+eng"
    chunks = []
    pdftoppm = resolve_tool("pdftoppm")
    tesseract = resolve_tool("tesseract")

    with tempfile.TemporaryDirectory(prefix="acca_ocr_") as tmp:
        tmp_dir = Path(tmp)
        prefix = tmp_dir / "page"

        render = subprocess.run(
            [pdftoppm, "-r", "190", "-png", str(pdf_path), str(prefix)],
            capture_output=True,
            check=False,
        )
        if render.returncode != 0:
            return ""

        images = sorted(tmp_dir.glob("page-*.png"))[:max_pages]
        for img in images:
            out = subprocess.run(
                [tesseract, str(img), "stdout", "-l", lang, "--psm", "6"],
                capture_output=True,
                check=False,
            )
            if out.returncode != 0:
                continue
            t = normalize_text((out.stdout or b"").decode("utf-8", errors="ignore"))
            if t:
                chunks.append(t)

    return "\n".join(chunks).strip()


def split_objective_blocks(text: str) -> list[str]:
    matches = list(re.finditer(r"(?m)^\s*(\d{1,4})[\.、]\s*", text))
    if not matches:
        return [text] if text else []

    blocks = []
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        block = text[start:end].strip()
        if block:
            blocks.append(block)
    return blocks


def split_subjective_blocks(text: str) -> list[str]:
    matches = list(
        re.finditer(
            r"(?m)^\s*(?:Question\s*\d+|Q\d+|试题[一二三四五六七八九十]|要求[：:]?)",
            text,
            re.I,
        )
    )
    if not matches:
        return [text] if text else []

    blocks = []
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        block = text[start:end].strip()
        if block:
            blocks.append(block)
    return blocks


def parse_objective_block(block: str):
    answer_match = ANSWER_RE.search(block)
    answer = answer_match.group(1).upper() if answer_match else None

    split = COMMENTARY_SPLIT_RE.split(block, maxsplit=1)
    prompt = split[0].strip()
    commentary = split[1].strip() if len(split) > 1 else None

    options = []
    marks = list(OPTION_RE.finditer(prompt))
    if marks:
        stem = prompt[: marks[0].start()].strip()
        for om in marks:
            label = om.group(1).upper()
            content = om.group(2).strip()
            if content:
                options.append(f"{label}. {content}")
    else:
        stem = prompt

    safe_options = [safe_text(x) for x in (options or [])]
    safe_options = [x for x in safe_options if x]
    return safe_text(stem), safe_options or None, safe_text(answer), safe_text(commentary)


def parse_subjective_block(block: str):
    split = COMMENTARY_SPLIT_RE.split(block, maxsplit=1)
    stem = split[0].strip()
    commentary = split[1].strip() if len(split) > 1 else None
    return safe_text(stem), None, None, safe_text(commentary)


def pick_subject_dir(pdf_root: Path, subject: str) -> Path:
    hint = SUBJECTS[subject]["folder_hint"]

    candidates = [p for p in pdf_root.rglob("*") if p.is_dir() and hint in p.name]
    if not candidates:
        raise FileNotFoundError(f"Cannot find subject folder for {subject} under: {pdf_root}")

    # Prefer shallower paths when multiple folders match the same subject hint.
    candidates.sort(key=lambda p: (len(p.parts), str(p)))
    return candidates[0]


def find_pdfs(subject_dir: Path) -> list[Path]:
    items = []
    for pdf in sorted(subject_dir.rglob("*.pdf")):
        name = pdf.name
        if "无答案" in name:
            continue
        items.append(pdf)
    return items


def build_rows(subject: str, pdf_root: Path, enable_ocr: bool, min_text_threshold: int) -> tuple[list[dict], dict]:
    subject_dir = pick_subject_dir(pdf_root, subject)
    default_mode = SUBJECTS[subject]["default_mode"]
    pdfs = find_pdfs(subject_dir)

    rows = []
    qid = 1
    stats = {
        "subject_dir": str(subject_dir),
        "pdf_count": len(pdfs),
        "ocr_used": 0,
        "text_only": 0,
        "by_type": {"objective": 0, "case": 0, "essay": 0},
    }

    for pdf in pdfs:
        text = extract_pdf_text(pdf)
        used_ocr = False
        if len(text) < min_text_threshold and enable_ocr:
            ocr_text = ocr_pdf_text(pdf)
            if len(ocr_text) > len(text):
                text = ocr_text
                used_ocr = True

        if not text:
            continue

        if used_ocr:
            stats["ocr_used"] += 1
        else:
            stats["text_only"] += 1

        block_mode = default_mode
        if default_mode == "subjective" and re.search(r"(?m)^\s*[A-D][\.、\)]\s+", text):
            block_mode = "objective"

        if block_mode == "objective":
            blocks = split_objective_blocks(text)
        else:
            blocks = split_subjective_blocks(text)

        for idx, block in enumerate(blocks, start=1):
            if block_mode == "objective":
                stem, options, answer, commentary = parse_objective_block(block)
                qtype = "objective"
            else:
                stem, options, answer, commentary = parse_subjective_block(block)
                qtype = "essay" if subject in ("sbl", "sbr") else "case"

            if not stem:
                continue

            source_doc = f"ACCA:{subject}:{qtype}:{pdf.name}"
            if len(blocks) > 1:
                source_doc = f"{source_doc}#{idx}"

            rows.append(
                {
                    "id": qid,
                    "q_num": str(qid),
                    "stem_en": None,
                    "stem_zh": safe_text(stem),
                    "options_en": None,
                    "options_zh": json.dumps(options, ensure_ascii=False) if options else None,
                    "correct_answer": safe_text(answer),
                    "explanation_en": None,
                    "explanation_zh": safe_text(commentary),
                    "source_doc": source_doc,
                    "source_page": None,
                }
            )
            qid += 1
            stats["by_type"][qtype] += 1

    return rows, stats


def write_db(rows: list[dict], template_db: Path, out_db: Path) -> None:
    out_db.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(template_db, out_db)
    conn = sqlite3.connect(str(out_db))
    cur = conn.cursor()

    cur.execute("DELETE FROM questions")
    for row in rows:
        cur.execute(
            """
            INSERT INTO questions (
              id, q_num, stem_en, stem_zh, options_en, options_zh,
              correct_answer, explanation_en, explanation_zh, source_doc, source_page
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                row["id"],
                row["q_num"],
                row["stem_en"],
                row["stem_zh"],
                row["options_en"],
                row["options_zh"],
                row["correct_answer"],
                row["explanation_en"],
                row["explanation_zh"],
                row["source_doc"],
                row["source_page"],
            ),
        )

    conn.commit()
    conn.close()


def write_json(rows: list[dict], out_json: Path) -> None:
    out_json.parent.mkdir(parents=True, exist_ok=True)
    with out_json.open("w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build one ACCA subject bank from PDFs")
    parser.add_argument("--subject", required=True, choices=sorted(SUBJECTS.keys()))
    parser.add_argument("--pdf-root", default=".", help="Search root for ACCA PDF folders")
    parser.add_argument("--template-db", default="assets/data.db")
    parser.add_argument("--out-root", default="assets/banks")
    parser.add_argument("--enable-ocr", action="store_true", help="Use OCR fallback for scanned PDFs")
    parser.add_argument("--min-text-threshold", type=int, default=240)
    args = parser.parse_args()

    subject = args.subject.lower().strip()
    pdf_root = Path(args.pdf_root)
    template_db = Path(args.template_db)
    out_dir = Path(args.out_root) / subject

    if not pdf_root.exists():
        raise FileNotFoundError(f"pdf root not found: {pdf_root}")
    if not template_db.exists():
        raise FileNotFoundError(f"template db not found: {template_db}")

    rows, stats = build_rows(subject, pdf_root, args.enable_ocr, args.min_text_threshold)
    if not rows:
        raise RuntimeError(f"No questions parsed for subject={subject}")

    out_db = out_dir / "data.db"
    out_json = out_dir / "questions.json"
    write_db(rows, template_db, out_db)
    write_json(rows, out_json)

    manifest = {
        "bank": subject,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "questions": len(rows),
        "pdf_root": str(pdf_root),
        "data_db": str(out_db),
        "questions_json": str(out_json),
        **stats,
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
