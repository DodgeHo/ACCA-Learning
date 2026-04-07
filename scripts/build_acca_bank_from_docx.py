#!/usr/bin/env python3
"""Build ACCA question-bank assets from OCR DOCX files.

Output for each subject:
  assets/banks/<subject>/data.db
  assets/banks/<subject>/questions.json
  assets/banks/<subject>/manifest.json

Database schema is unchanged; only rows in `questions` are rewritten.
"""

import argparse
import json
import re
import shutil
import sqlite3
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path
from zipfile import ZipFile

SUBJECTS = {
    "pm": {"default_mode": "objective"},
    "tx": {"default_mode": "objective"},
    "fr": {"default_mode": "objective"},
    "aa": {"default_mode": "objective"},
    "fm": {"default_mode": "objective"},
    "sbl": {"default_mode": "subjective"},
    "sbr": {"default_mode": "subjective"},
    "afm": {"default_mode": "subjective"},
    "apm": {"default_mode": "subjective"},
    "aaa": {"default_mode": "subjective"},
}

W_NS = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}

QUESTION_START_RE = re.compile(
    r"(?im)^\s*(?:question\s*\d+|q\s*\d+|\d{1,3}[\)\.]\s+|section\s*[ab]\s*)"
)
OPTION_RE = re.compile(
    r"(?ims)(?:^|\n)\s*([A-F])[\.\)\]:-]\s*(.*?)(?=(?:\n\s*[A-F][\.\)\]:-]\s*)|\Z)"
)
ANSWER_RE = re.compile(
    r"(?:answer|key|correct answer|\u7b54\u6848|\u6b63\u786e\u7b54\u6848)\s*[:\uff1a]?\s*([A-F](?:\s*[,/\\]\s*[A-F])*)",
    re.I,
)
COMMENTARY_SPLIT_RE = re.compile(
    r"(?:analysis|explanation|marking\s*scheme|sample\s*answer|\u89e3\u6790|\u53c2\u8003\u7b54\u6848|\u8981\u70b9\u70b9\u8bc4)\s*[:\uff1a]",
    re.I,
)


def safe_text(text: str | None) -> str | None:
    if text is None:
        return None
    cleaned = text.encode("utf-8", errors="ignore").decode("utf-8", errors="ignore")
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned or None


def read_docx_paragraphs(docx_path: Path) -> list[str]:
    with ZipFile(docx_path, "r") as zf:
        xml_data = zf.read("word/document.xml")

    root = ET.fromstring(xml_data)
    paragraphs: list[str] = []
    for p in root.findall(".//w:p", W_NS):
        parts: list[str] = []
        for t in p.findall(".//w:t", W_NS):
            if t.text:
                parts.append(t.text)
        line = "".join(parts)
        line = re.sub(r"\s+", " ", line).strip()
        if line:
            paragraphs.append(line)
    return paragraphs


def is_marker_line(line: str) -> bool:
    return bool(
        re.match(r"(?i)^\s*(?:question\s*\d+|q\s*\d+|\d{1,3}[\)\.]|answer|key|analysis|explanation|requirement)", line)
    )


def reflow_lines(lines: list[str]) -> list[str]:
    out: list[str] = []
    buffer = ""

    for raw in lines:
        line = re.sub(r"\s+", " ", raw).strip()
        if not line:
            continue

        if is_marker_line(line):
            if buffer:
                out.append(buffer.strip())
                buffer = ""
            out.append(line)
            continue

        if not buffer:
            buffer = line
            continue

        if re.search(r"[\.!\?\u3002\uff01\uff1f:]$", buffer):
            out.append(buffer.strip())
            buffer = line
        else:
            buffer = f"{buffer} {line}"

    if buffer:
        out.append(buffer.strip())

    return out


def split_blocks(text: str) -> list[str]:
    matches = list(QUESTION_START_RE.finditer(text))
    if not matches:
        return [text] if text.strip() else []

    blocks: list[str] = []
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        block = text[start:end].strip()
        if block:
            blocks.append(block)
    return blocks


def parse_objective_block(block: str):
    answer_match = ANSWER_RE.search(block)
    answer = answer_match.group(1).upper().replace(" ", "") if answer_match else None

    split = COMMENTARY_SPLIT_RE.split(block, maxsplit=1)
    prompt = split[0].strip()
    commentary = split[1].strip() if len(split) > 1 else None

    options = []
    marks = list(OPTION_RE.finditer(prompt))
    if marks:
        stem = prompt[: marks[0].start()].strip()
        for om in marks:
            label = om.group(1).upper()
            content = safe_text(om.group(2))
            if content:
                options.append(f"{label}. {content}")
    else:
        stem = prompt

    return safe_text(stem), options or None, safe_text(answer), safe_text(commentary)


def parse_subjective_block(block: str):
    split = COMMENTARY_SPLIT_RE.split(block, maxsplit=1)
    stem = split[0].strip()
    commentary = split[1].strip() if len(split) > 1 else None
    return safe_text(stem), None, None, safe_text(commentary)


def is_low_signal_block(stem: str | None, options: list[str] | None, answer: str | None) -> bool:
    if not stem:
        return True

    compact = re.sub(r"\s+", "", stem)
    if len(compact) < 24 and not options and not answer:
        return True

    alnum = re.sub(r"[^A-Za-z0-9]", "", compact)
    digits = re.sub(r"[^0-9]", "", compact)
    if alnum and len(digits) / max(len(alnum), 1) > 0.75 and not options and not answer:
        return True

    return False


def find_docx_files(ocr_root: Path, subject: str) -> list[Path]:
    return sorted(ocr_root.glob(f"{subject}-ocr-needed*.docx"))


def build_rows(subject: str, ocr_root: Path) -> tuple[list[dict], dict]:
    files = find_docx_files(ocr_root, subject)
    if not files:
        raise FileNotFoundError(f"No OCR docx found for subject={subject} under: {ocr_root}")

    rows = []
    qid = 1
    default_mode = SUBJECTS[subject]["default_mode"]
    stats = {
        "source_docx_count": len(files),
        "parsed_blocks": 0,
        "by_type": {"objective": 0, "case": 0, "essay": 0},
    }

    for docx in files:
        lines = read_docx_paragraphs(docx)
        lines = reflow_lines(lines)
        text = "\n".join(lines).strip()
        if not text:
            continue

        blocks = split_blocks(text)
        if not blocks:
            blocks = [text]

        for idx, block in enumerate(blocks, start=1):
            block_mode = default_mode
            if default_mode == "subjective" and re.search(r"(?m)^\s*[A-D][\.\)\]:-]\s+", block):
                block_mode = "objective"
            if default_mode == "objective" and not re.search(r"(?m)^\s*[A-D][\.\)\]:-]\s+", block):
                block_mode = "subjective"

            if block_mode == "objective":
                stem, options, answer, commentary = parse_objective_block(block)
                qtype = "objective"
            else:
                stem, options, answer, commentary = parse_subjective_block(block)
                qtype = "essay" if subject in ("sbl", "sbr") else "case"

            if is_low_signal_block(stem, options, answer):
                continue

            source_doc = f"ACCA:{subject}:{qtype}:{docx.name}"
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
            stats["parsed_blocks"] += 1
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


def as_posix(path_like: Path | str) -> str:
    return str(path_like).replace("\\", "/")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build one ACCA subject bank from OCR DOCX")
    parser.add_argument("--subject", required=True, choices=sorted(SUBJECTS.keys()))
    parser.add_argument("--ocr-root", default="ocr_packets", help="Folder containing OCR docx files")
    parser.add_argument("--template-db", default="assets/data.db")
    parser.add_argument("--out-root", default="assets/banks")
    args = parser.parse_args()

    subject = args.subject.lower().strip()
    ocr_root = Path(args.ocr_root)
    template_db = Path(args.template_db)
    out_dir = Path(args.out_root) / subject

    if not ocr_root.exists():
        raise FileNotFoundError(f"ocr root not found: {ocr_root}")
    if not template_db.exists():
        raise FileNotFoundError(f"template db not found: {template_db}")

    rows, stats = build_rows(subject, ocr_root)
    if not rows:
        raise RuntimeError(f"No questions parsed for subject={subject}")

    out_db = out_dir / "data.db"
    out_json = out_dir / "questions.json"
    write_db(rows, template_db, out_db)
    write_json(rows, out_json)

    manifest = {
        "bank": subject,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "ocr_docx",
        "questions": len(rows),
        "ocr_root": as_posix(ocr_root),
        "data_db": as_posix(out_db),
        "questions_json": as_posix(out_json),
        **stats,
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
