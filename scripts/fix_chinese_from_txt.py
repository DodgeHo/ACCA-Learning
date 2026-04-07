#!/usr/bin/env python3
import argparse
import json
import re
import sqlite3
from pathlib import Path

Q_RE = re.compile(r"(?m)^\s*(\d{1,4})\.")


def split_questions(text: str) -> dict[int, str]:
    matches = list(Q_RE.finditer(text))
    blocks: dict[int, str] = {}
    for i, m in enumerate(matches):
        q_num = int(m.group(1))
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        block = text[start:end].strip()
        if q_num not in blocks or len(block) > len(blocks[q_num]):
            blocks[q_num] = block
    return blocks


def clean_block(block: str) -> str:
    block = block.replace("\r\n", "\n").replace("\r", "\n")
    lines = [ln.strip() for ln in block.split("\n") if ln.strip()]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Repair stem_zh in sqlite using GB18030 source txt")
    parser.add_argument("--txt", default="题库/AWS认证 SAA-C03 中文真题题库.txt", help="Chinese source txt path")
    parser.add_argument("--db", default="assets/data.db", help="SQLite db path")
    args = parser.parse_args()

    txt_path = Path(args.txt)
    db_path = Path(args.db)

    if not txt_path.exists():
        raise FileNotFoundError(f"txt not found: {txt_path}")
    if not db_path.exists():
        raise FileNotFoundError(f"db not found: {db_path}")

    raw = txt_path.read_text(encoding="gb18030", errors="ignore")
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
        stem_zh = clean_block(block)
        cur.execute(
            "UPDATE questions SET stem_zh=? WHERE q_num=?",
            (stem_zh, str(q)),
        )
        updated += cur.rowcount

    conn.commit()
    row = cur.execute("SELECT stem_zh FROM questions WHERE q_num='1'").fetchone()
    sample = row[0][:120] if row and row[0] else ""
    conn.close()

    print(json.dumps({
        "txt_blocks": len(blocks),
        "rows_updated": updated,
        "missing_blocks": missing,
        "sample_q1": sample,
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
