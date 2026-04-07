#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
全量重建assets/data.db和release/data.db，仅保留中文题干、选项、答案、解析。
用法：python rebuild_zh_db.py --txt "题库/AWS认证 SAA-C03 中文真题题库.txt" --db "assets/data.db" --db2 "release/data.db" [--backup]
"""
import argparse
import json
import re
import shutil
import sqlite3
from pathlib import Path

Q_RE = re.compile(r"(?m)^\s*(\d{1,4})\.")
ANS_RE = re.compile(r"(?:答案|正确答案)[:：]?\s*([A-E])", re.I)
EXP_MARK_RE = re.compile(r"(?:解析|解释)", re.I)
OPT_RE = re.compile(
    r"(?ms)(?:^|\n)\s*([A-E])(?:\s*[、\.)\]:：-]+\s*|\s+)(?=[\u4e00-\u9fa5A-Z0-9])(.*?)"
    r"(?=(?:\n\s*[A-E](?:\s*[、\.)\]:：-]+\s*|\s+)(?=[\u4e00-\u9fa5A-Z0-9]))|(?:\n\s*(?:答案|正确答案|解析|解释))|\Z)",
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

def rebuild_db(db_path: Path, blocks: dict, backup: bool = False):
    try:
        print(f"[INFO] 开始处理数据库: {db_path}")
        if backup and db_path.exists():
            shutil.copy2(db_path, db_path.with_suffix(db_path.suffix + ".bak"))
            print(f"[INFO] 已备份: {db_path.with_suffix(db_path.suffix + '.bak')}")
        conn = sqlite3.connect(str(db_path))
        cur = conn.cursor()
        print("[INFO] 清空 questions 表...")
        cur.execute("DELETE FROM questions")
        print(f"[INFO] 插入题目总数: {len(blocks)}")
        for q in sorted(blocks.keys()):
            stem_zh, options_zh, answer, explanation_zh = parse_block(blocks[q])
            cur.execute(
                """
                INSERT INTO questions (q_num, stem_zh, options_zh, correct_answer, explanation_zh)
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    str(q),
                    stem_zh,
                    json.dumps(options_zh, ensure_ascii=False) if options_zh else None,
                    answer,
                    explanation_zh,
                ),
            )
            if q % 100 == 0:
                print(f"[INFO] 已插入: {q}")
        conn.commit()
        conn.close()
        print(f"[SUCCESS] 数据库重建完成: {db_path}")
    except Exception as e:
        print(f"[ERROR] rebuild_db 失败: {e}")
        import traceback
        traceback.print_exc()

def main():
    parser = argparse.ArgumentParser(description="Rebuild Chinese-only data.db from txt")
    parser.add_argument("--txt", required=True, help="Path to Chinese txt")
    parser.add_argument("--db", required=True, help="Path to sqlite data.db")
    parser.add_argument("--db2", required=False, help="Path to 2nd sqlite data.db")
    parser.add_argument("--backup", action="store_true", help="Backup db before overwrite")
    args = parser.parse_args()

    try:
        txt_path = Path(args.txt)
        db_path = Path(args.db)
        db2_path = Path(args.db2) if args.db2 else None
        print(f"[INFO] txt: {txt_path}\ndb1: {db_path}\ndb2: {db2_path}")
        if not txt_path.exists():
            print(f"[ERROR] txt not found: {txt_path}")
            return
        if not db_path.exists():
            print(f"[ERROR] db not found: {db_path}")
            return
        if db2_path and not db2_path.exists():
            print(f"[ERROR] db2 not found: {db2_path}")
            return

        raw = txt_path.read_bytes().decode("utf-8", errors="replace")
        print(f"[INFO] 题库原始长度: {len(raw)} 字符")
        blocks = split_questions(raw)
        print(f"[INFO] 解析出题目数: {len(blocks)}")
        rebuild_db(db_path, blocks, backup=args.backup)
        if db2_path:
            rebuild_db(db2_path, blocks, backup=args.backup)
        print(f"[SUCCESS] Rebuild done: {db_path} and {db2_path if db2_path else ''}")
    except Exception as e:
        print(f"[FATAL] main 失败: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
