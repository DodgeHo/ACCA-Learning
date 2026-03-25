#!/usr/bin/env python3
"""Build question-bank assets (data.db + questions.json) from a UTF-8 txt source.

This script does not change database schema. It clones a template DB, rewrites only
`questions` table rows, and exports the same rows to JSON.
"""

import argparse
import json
import re
import shutil
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

Q_RE = re.compile(r"(?m)^\s*(\d{1,4})\.")
Q_LABEL_RE = re.compile(r"问题\s*#\s*(\d{1,4})")
ANS_RE = re.compile(r"(?:答案|正确答案|Answer|Correct\s*Answer)[:：]?\s*([A-F])", re.I)
EXP_MARK_RE = re.compile(r"(?:解析|解释|Explanation)", re.I)
OPT_RE = re.compile(
    r"(?ms)(?:^|\n)\s*([A-F])(?:\s*[、\.)\]:：-]+\s*|\s+)(?=[\u4e00-\u9fa5A-Z0-9])(.*?)"
    r"(?=(?:\n\s*[A-F](?:\s*[、\.)\]:：-]+\s*|\s+)(?=[\u4e00-\u9fa5A-Z0-9]))|(?:\n\s*(?:答案|正确答案|Answer|Correct\s*Answer|解析|解释|Explanation))|\Z)",
)


def clean_text(text: str) -> str:
    text = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    text = text.replace("\u00a0", " ")
    lines = [ln.strip() for ln in text.split("\n") if ln.strip()]
    return "\n".join(lines).strip()


def split_questions(all_text: str) -> dict[int, str]:
    matches = list(Q_RE.finditer(all_text))
    blocks: dict[int, str] = {}
    for i, m in enumerate(matches):
        q_num = int(m.group(1))
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(all_text)
        block = all_text[start:end].strip()
        label_match = Q_LABEL_RE.search(block)
        effective_q_num = int(label_match.group(1)) if label_match else q_num
        if effective_q_num not in blocks or len(block) > len(blocks[effective_q_num]):
            blocks[effective_q_num] = block
    return blocks


def preprocess_source_text(text: str) -> str:
    out_lines: list[str] = []
    for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        s = line.strip()
        if not s:
            out_lines.append("")
            continue

        if s.startswith("===== PAGE"):
            continue
        if re.fullmatch(r"\d{1,4}", s):
            continue
        if s.startswith("AWS SAP-C02"):
            continue
        if s in ("详细", "详细解析："):
            continue
        if s.startswith("https://") or s.startswith("http://"):
            continue
        if s.startswith("淘宝店"):
            continue

        out_lines.append(line)

    return "\n".join(out_lines)


def parse_block(block: str):
    header = re.match(r"\s*\d{1,4}\.\s*", block)
    body = block[header.end():] if header else block

    exp_match = EXP_MARK_RE.search(body)
    body_for_stem_opts = body[:exp_match.start()] if exp_match else body

    option_marks = list(OPT_RE.finditer(body_for_stem_opts))
    options = []
    if option_marks:
        stem = body_for_stem_opts[:option_marks[0].start()].strip()
        for om in option_marks:
            label = om.group(1).upper()
            content = clean_text(om.group(2))
            if content:
                options.append(f"{label}. {content}")
    else:
        stem = body_for_stem_opts.strip()

    ans_match = ANS_RE.search(body)
    answer = ans_match.group(1).upper() if ans_match else None

    explanation = None
    if exp_match:
        explanation = clean_text(body[exp_match.start():])

    return clean_text(stem) or None, options, answer, explanation


def build_rows(blocks: dict[int, str], source_doc: str | None) -> list[dict]:
    rows: list[dict] = []
    for q_num in sorted(blocks.keys()):
        stem_zh, options_zh, answer, explanation_zh = parse_block(blocks[q_num])
        rows.append(
            {
                "id": q_num,
                "q_num": str(q_num),
                "stem_en": None,
                "stem_zh": stem_zh,
                "options_en": None,
                "options_zh": json.dumps(options_zh, ensure_ascii=False) if options_zh else None,
                "correct_answer": answer,
                "explanation_en": None,
                "explanation_zh": explanation_zh,
                "source_doc": source_doc,
                "source_page": None,
            }
        )
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
    parser = argparse.ArgumentParser(description="Build bank assets from txt")
    parser.add_argument("--txt", required=True, help="UTF-8 source txt path")
    parser.add_argument("--bank", required=True, help="Bank key, e.g. saa or sap")
    parser.add_argument("--template-db", default="assets/data.db", help="Template db path")
    parser.add_argument("--out-root", default="assets/banks", help="Bank assets root")
    parser.add_argument("--source-doc", default=None, help="Optional source_doc value")
    args = parser.parse_args()

    txt_path = Path(args.txt)
    template_db = Path(args.template_db)
    out_dir = Path(args.out_root) / args.bank.lower().strip()

    if not txt_path.exists():
        raise FileNotFoundError(f"txt not found: {txt_path}")
    if not template_db.exists():
        raise FileNotFoundError(f"template db not found: {template_db}")

    raw = txt_path.read_text(encoding="utf-8", errors="replace")
    raw = preprocess_source_text(raw)
    blocks = split_questions(raw)
    if not blocks:
        raise RuntimeError("No question blocks detected; check txt format")

    rows = build_rows(blocks, args.source_doc)
    out_db = out_dir / "data.db"
    out_json = out_dir / "questions.json"
    write_db(rows, template_db, out_db)
    write_json(rows, out_json)

    manifest = {
        "bank": args.bank.lower().strip(),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "questions": len(rows),
        "txt": str(txt_path),
        "data_db": str(out_db),
        "questions_json": str(out_json),
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
