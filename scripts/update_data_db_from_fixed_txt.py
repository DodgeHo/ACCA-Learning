#!/usr/bin/env python3
import argparse
import json
import re
import shutil
import sqlite3
from pathlib import Path


Q_RE = re.compile(r"(?m)^\s*(\d{1,4})\.")
ANS_RE = re.compile(r"(?:答案|正确答案|�𰸣�|Answer|Correct\s*Answer)[:：]?\s*([A-E])", re.I)
EXP_MARK_RE = re.compile(r"(?:解析|解释|����|Explanation|Detailed\s*Explanation|Correct\s*Answer)", re.I)
OPT_RE = re.compile(
    r"(?ms)(?:^|\n)\s*([A-E])(?:\s*[、\.)\]:：��-]+\s*|\s+)(?=[A-Z0-9])(.*?)"
    r"(?=(?:\n\s*[A-E](?:\s*[、\.)\]:：��-]+\s*|\s+)(?=[A-Z0-9]))|(?:\n\s*(?:答案|正确答案|�𰸣�|Answer|Correct\s*Answer|解析|解释|����|Explanation))|\Z)",
)


def clean_text(text: str) -> str:
    text = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"\u00a0", " ", text)
    lines = [ln.strip() for ln in text.split("\n")]
    lines = [ln for ln in lines if ln]
    return "\n".join(lines).strip()


def split_questions(all_text: str) -> dict[int, str]:
    matches = list(Q_RE.finditer(all_text))
    blocks: dict[int, str] = {}
    for i, m in enumerate(matches):
        q_num = int(m.group(1))
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(all_text)
        block = all_text[start:end].strip()
        if q_num not in blocks or len(block) > len(blocks[q_num]):
            blocks[q_num] = block
    return blocks


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

    stem = clean_text(stem)
    return stem or None, options, answer, explanation


def main():
    parser = argparse.ArgumentParser(description="Update qbank_trainer/data.db from fixed English txt")
    parser.add_argument("--txt", required=True, help="Path to fixed English txt")
    parser.add_argument("--db", required=True, help="Path to sqlite data.db")
    parser.add_argument("--backup", action="store_true", help="Create .bak backup before update")
    args = parser.parse_args()

    txt_path = Path(args.txt)
    db_path = Path(args.db)

    if not txt_path.exists():
        raise FileNotFoundError(f"txt not found: {txt_path}")
    if not db_path.exists():
        raise FileNotFoundError(f"db not found: {db_path}")

    if args.backup:
        backup = db_path.with_suffix(db_path.suffix + ".bak")
        shutil.copy2(db_path, backup)

    raw = txt_path.read_bytes().decode("utf-8", errors="replace")
    blocks = split_questions(raw)

    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()

    updated = 0
    missing = 0
    for q in range(1, 1020):
        block = blocks.get(q)
        if not block:
            missing += 1
            continue

        stem_en, options_en, answer, explanation_en = parse_block(block)
        cur.execute(
            """
            UPDATE questions
            SET stem_en = COALESCE(?, stem_en),
                options_en = CASE WHEN ? IS NOT NULL THEN ? ELSE options_en END,
                correct_answer = COALESCE(?, correct_answer),
                explanation_en = COALESCE(?, explanation_en)
            WHERE q_num = ?
            """,
            (
                stem_en,
                json.dumps(options_en, ensure_ascii=False) if options_en else None,
                json.dumps(options_en, ensure_ascii=False) if options_en else None,
                answer,
                explanation_en,
                str(q),
            ),
        )
        updated += cur.rowcount

    conn.commit()

    total = cur.execute("SELECT COUNT(*) FROM questions").fetchone()[0]
    remain_bad = cur.execute(
        "SELECT COUNT(*) FROM questions WHERE stem_en GLOB '*[A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z]*'"
    ).fetchone()[0]
    conn.close()

    print(
        json.dumps(
            {
                "db": str(db_path),
                "txt_blocks": len(blocks),
                "total_rows": total,
                "rows_updated": updated,
                "missing_blocks": missing,
                "rows_with_18plus_alpha_run": remain_bad,
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
