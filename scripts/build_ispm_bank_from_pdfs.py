#!/usr/bin/env python3
"""Build ISPM bank assets from a directory of PDF files.

Output:
  assets/banks/ispm/data.db
  assets/banks/ispm/questions.json
  assets/banks/ispm/manifest.json

No database schema changes.
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

HEADER_NOISE = (
    "全国计算机技术与软件专业技术资格",
    "信息系统项目管理师",
    "软考",
    "第",
)


def resolve_tool(tool_name: str) -> str:
    direct = shutil.which(tool_name)
    if direct:
        return direct

    candidates = []
    if tool_name.lower() == "tesseract":
        candidates.extend(
            [
                Path("C:/Program Files/Tesseract-OCR/tesseract.exe"),
                Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Tesseract-OCR" / "tesseract.exe",
            ]
        )
    else:
        local = Path(os.environ.get("LOCALAPPDATA", ""))
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
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = []
    for raw in text.split("\n"):
        s = raw.strip()
        if not s:
            continue
        if any(key in s for key in HEADER_NOISE) and len(s) < 28:
            continue
        if re.fullmatch(r"\d+", s):
            continue
        lines.append(s)
    return "\n".join(lines).strip()


def extract_pdf_text(pdf_path: Path) -> str:
    # 1) Try pypdf text layer.
    chunks = []
    try:
        reader = PdfReader(str(pdf_path))
        for page in reader.pages:
            text = page.extract_text() or ""
            text = normalize_text(text)
            if text:
                chunks.append(text)
    except Exception:
        chunks = []

    text = "\n".join(chunks).strip()
    if len(text) >= 240:
        return text

    # 2) Try poppler text extraction.
    try:
        pdftotext = resolve_tool("pdftotext")
        poppler_text = subprocess.run(
            [pdftotext, "-layout", "-enc", "UTF-8", str(pdf_path), "-"],
            capture_output=True,
            check=False,
        )
        if poppler_text.returncode == 0:
            stdout_text = (poppler_text.stdout or b"").decode("utf-8", errors="ignore")
            text2 = normalize_text(stdout_text)
            if len(text2) >= 240:
                return text2
    except Exception:
        pass

    # 3) OCR fallback for scanned PDFs.
    return ocr_pdf_text(pdf_path)


def _tesseract_lang() -> str:
    candidates = []
    tessdata = os.environ.get("TESSDATA_PREFIX", "")
    if tessdata:
        candidates.append(Path(tessdata))

    candidates.extend(
        [
            Path("C:/Program Files/Tesseract-OCR/tessdata"),
            Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Tesseract-OCR" / "tessdata",
        ]
    )

    for folder in candidates:
        if (folder / "chi_sim.traineddata").exists():
            return "chi_sim+eng"
    return "eng"


def ocr_pdf_text(pdf_path: Path, max_pages: int = 32) -> str:
    lang = _tesseract_lang()
    chunks: list[str] = []
    pdftoppm = resolve_tool("pdftoppm")
    tesseract = resolve_tool("tesseract")

    with tempfile.TemporaryDirectory(prefix="ispm_ocr_") as tmp:
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
            ocr = subprocess.run(
                [tesseract, str(img), "stdout", "-l", lang, "--psm", "6"],
                capture_output=True,
                check=False,
            )
            if ocr.returncode != 0:
                continue
            ocr_text = (ocr.stdout or b"").decode("utf-8", errors="ignore")
            text = normalize_text(ocr_text)
            if text:
                chunks.append(text)

    return "\n".join(chunks).strip()


def split_objective_blocks(text: str) -> list[str]:
    matches = list(re.finditer(r"(?m)^\s*(\d{1,3})[\.、]\s*", text))
    if not matches:
        return [text] if text else []

    blocks = []
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        blocks.append(text[start:end].strip())
    return [b for b in blocks if b]


def split_case_blocks(text: str) -> list[str]:
    matches = list(re.finditer(r"(?m)^\s*(?:试题[一二三四五六七八九十]|问题\s*[#：:]?\s*\d+)", text))
    if not matches:
        return [text] if text else []

    blocks = []
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        blocks.append(text[start:end].strip())
    return [b for b in blocks if b]


def split_essay_blocks(text: str) -> list[str]:
    matches = list(re.finditer(r"(?m)^\s*(?:试题[一二三四五六七八九十]|论文(?:题目)?[：:]?)", text))
    if not matches:
        return [text] if text else []

    blocks = []
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        blocks.append(text[start:end].strip())
    return [b for b in blocks if b]


def parse_objective(block: str):
    ans_match = re.search(r"(?:答案|参考答案|正确答案)\s*[：:]?\s*([A-F])", block, re.I)
    correct = ans_match.group(1).upper() if ans_match else None

    split = re.split(r"(?:答案|参考答案|正确答案|要点点评|解析)\s*[：:]", block, maxsplit=1)
    prompt = split[0].strip()
    tail = split[1].strip() if len(split) > 1 else ""

    option_matches = list(
        re.finditer(
            r"(?ms)(?:^|\n)\s*([A-F])[\.、\)]\s*(.*?)(?=(?:\n\s*[A-F][\.、\)]\s*)|\Z)",
            prompt,
        )
    )
    options = []
    if option_matches:
        stem = prompt[: option_matches[0].start()].strip()
        for om in option_matches:
            label = om.group(1).upper()
            content = om.group(2).strip()
            if content:
                options.append(f"{label}. {content}")
    else:
        stem = prompt

    key_commentary = ""
    if re.search(r"要点点评", block):
        m = re.search(r"要点点评\s*[：:]?\s*(.*)$", block, re.S)
        key_commentary = m.group(1).strip() if m else ""
    elif tail:
        key_commentary = tail

    return stem or None, options, correct, key_commentary or None


def parse_case_or_essay(block: str):
    split = re.split(r"(?:参考答案|答案|要点点评|解析)\s*[：:]", block, maxsplit=1)
    stem = split[0].strip()
    commentary = split[1].strip() if len(split) > 1 else None
    return stem or None, None, None, commentary


def classify_from_path(path: Path) -> str:
    p = str(path)
    if "01-综合知识" in p:
        return "objective"
    if "02-案例分析" in p:
        return "case"
    return "essay"


def find_source_pdfs(root: Path) -> list[Path]:
    all_pdfs = sorted(root.rglob("*.pdf"))
    selected = []
    for pdf in all_pdfs:
        name = pdf.name
        if "无答案" in name:
            continue
        selected.append(pdf)
    return selected


def build_rows(pdf_root: Path) -> list[dict]:
    rows = []
    qid = 1

    for pdf in find_source_pdfs(pdf_root):
        qtype = classify_from_path(pdf)
        text = extract_pdf_text(pdf)
        if not text:
            continue

        if qtype == "objective":
            blocks = split_objective_blocks(text)
        elif qtype == "case":
            blocks = split_case_blocks(text)
        else:
            blocks = split_essay_blocks(text)

        for idx, block in enumerate(blocks, start=1):
            if qtype == "objective":
                stem, options, correct, commentary = parse_objective(block)
            else:
                stem, options, correct, commentary = parse_case_or_essay(block)

            if not stem:
                continue

            source_doc = f"ISPM:{qtype}:{pdf.name}"
            if len(blocks) > 1:
                source_doc = f"{source_doc}#{idx}"

            rows.append(
                {
                    "id": qid,
                    "q_num": str(qid),
                    "stem_en": None,
                    "stem_zh": stem,
                    "options_en": None,
                    "options_zh": json.dumps(options, ensure_ascii=False) if options else None,
                    "correct_answer": correct,
                    "explanation_en": None,
                    "explanation_zh": commentary,
                    "source_doc": source_doc,
                    "source_page": None,
                }
            )
            qid += 1

    return rows


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
    parser = argparse.ArgumentParser(description="Build ISPM bank assets from PDFs")
    parser.add_argument("--pdf-root", required=True, help="ISPM PDF root directory")
    parser.add_argument("--template-db", default="assets/data.db", help="Template DB path")
    parser.add_argument("--out-root", default="assets/banks", help="Output bank root")
    args = parser.parse_args()

    pdf_root = Path(args.pdf_root)
    template_db = Path(args.template_db)
    out_dir = Path(args.out_root) / "ispm"

    if not pdf_root.exists():
        raise FileNotFoundError(f"pdf root not found: {pdf_root}")
    if not template_db.exists():
        raise FileNotFoundError(f"template db not found: {template_db}")

    rows = build_rows(pdf_root)
    if not rows:
        raise RuntimeError("No ISPM questions parsed from PDFs")

    out_db = out_dir / "data.db"
    out_json = out_dir / "questions.json"
    write_db(rows, template_db, out_db)
    write_json(rows, out_json)

    by_type = {"objective": 0, "case": 0, "essay": 0}
    for row in rows:
        src = row.get("source_doc") or ""
        if ":objective:" in src:
            by_type["objective"] += 1
        elif ":case:" in src:
            by_type["case"] += 1
        elif ":essay:" in src:
            by_type["essay"] += 1

    manifest = {
        "bank": "ispm",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "questions": len(rows),
        "by_type": by_type,
        "pdf_root": str(pdf_root),
        "data_db": str(out_db),
        "questions_json": str(out_json),
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
