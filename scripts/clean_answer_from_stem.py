import argparse
import json
import re
import shutil
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Any

ANSWER_AT_END_RE = re.compile(
    r'(?:\r?\n|\s)答案[:：]\s*([A-Fa-f][A-Fa-f\s、,，/]*)\s*$',
    flags=re.MULTILINE,
)

ANSWER_ANYWHERE_RE = re.compile(
    r'答案[:：]\s*([A-Fa-f][A-Fa-f\s、,，/]*)',
    flags=re.MULTILINE,
)


def normalize_answer(raw: str | None) -> str | None:
    if raw is None:
        return None
    text = raw.strip()
    if not text:
        return None

    letters = ''.join(m.group(0).upper() for m in re.finditer(r'[A-Fa-f]', text))
    if letters:
        return letters
    return text


def strip_answer_from_stem(stem_zh: str | None, aggressive: bool = False) -> tuple[str | None, str | None, bool]:
    if not stem_zh:
        return stem_zh, None, False

    match = ANSWER_AT_END_RE.search(stem_zh)
    if match:
        extracted = normalize_answer(match.group(1))
        cleaned = stem_zh[: match.start()].rstrip()
        return cleaned, extracted, True

    if not aggressive:
        return stem_zh, None, False

    # aggressive fallback: use the last "答案：X" marker even if not strict end-of-line.
    matches = list(ANSWER_ANYWHERE_RE.finditer(stem_zh))
    if not matches:
        return stem_zh, None, False

    match = matches[-1]
    if match.start() < int(len(stem_zh) * 0.55):
        # too early in the stem; likely descriptive text, skip to avoid false positives
        return stem_zh, None, False

    extracted = normalize_answer(match.group(1))
    cleaned = (stem_zh[: match.start()] + stem_zh[match.end() :]).rstrip()
    cleaned = re.sub(r'\s{2,}', ' ', cleaned)
    return cleaned, extracted, True


def backup_file(path: Path) -> Path:
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup = path.with_suffix(path.suffix + f'.bak.{ts}')
    shutil.copy2(path, backup)
    return backup


def clean_json(json_path: Path, dry_run: bool, aggressive: bool) -> tuple[int, int, int, int]:
    data: list[dict[str, Any]] = json.loads(json_path.read_text(encoding='utf-8'))

    touched_rows = 0
    stem_fixed = 0
    answer_filled = 0
    answer_conflicts = 0

    for row in data:
        original_stem = row.get('stem_zh')
        cleaned_stem, extracted_answer, changed = strip_answer_from_stem(original_stem, aggressive=aggressive)
        if not changed:
            continue

        touched_rows += 1
        stem_fixed += 1
        row['stem_zh'] = cleaned_stem

        existing = normalize_answer(row.get('correct_answer'))
        if not existing and extracted_answer:
            row['correct_answer'] = extracted_answer
            answer_filled += 1
        elif existing and extracted_answer and existing != extracted_answer:
            answer_conflicts += 1

    if touched_rows and not dry_run:
        backup = backup_file(json_path)
        json_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
        print(f'[JSON] 已写入: {json_path}')
        print(f'[JSON] 备份: {backup}')

    return touched_rows, stem_fixed, answer_filled, answer_conflicts


def clean_db(db_path: Path, dry_run: bool, aggressive: bool) -> tuple[int, int, int, int]:
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row

    rows = conn.execute('SELECT id, stem_zh, correct_answer FROM questions').fetchall()

    touched_rows = 0
    stem_fixed = 0
    answer_filled = 0
    answer_conflicts = 0

    updates: list[tuple[str | None, str | None, int]] = []

    for row in rows:
        qid = row['id']
        cleaned_stem, extracted_answer, changed = strip_answer_from_stem(row['stem_zh'], aggressive=aggressive)
        if not changed:
            continue

        touched_rows += 1
        stem_fixed += 1

        existing = normalize_answer(row['correct_answer'])
        final_answer = row['correct_answer']
        if not existing and extracted_answer:
            final_answer = extracted_answer
            answer_filled += 1
        elif existing and extracted_answer and existing != extracted_answer:
            answer_conflicts += 1

        updates.append((cleaned_stem, final_answer, qid))

    if updates and not dry_run:
        backup = backup_file(db_path)
        conn.executemany(
            'UPDATE questions SET stem_zh = ?, correct_answer = ? WHERE id = ?',
            updates,
        )
        conn.commit()
        print(f'[DB] 已写入: {db_path}')
        print(f'[DB] 备份: {backup}')

    conn.close()
    return touched_rows, stem_fixed, answer_filled, answer_conflicts


def main() -> None:
    parser = argparse.ArgumentParser(
        description='一次性清洗：把 stem_zh 末尾的「答案：X」迁移到 correct_answer。'
    )
    parser.add_argument(
        '--json',
        default='assets/questions.json',
        help='要清洗的 questions.json 路径（默认: assets/questions.json）',
    )
    parser.add_argument(
        '--db',
        default='assets/data.db',
        help='要清洗的 SQLite 路径（默认: assets/data.db）',
    )
    parser.add_argument(
        '--skip-json',
        action='store_true',
        help='跳过 JSON 清洗',
    )
    parser.add_argument(
        '--skip-db',
        action='store_true',
        help='跳过 DB 清洗',
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='仅统计，不写入文件',
    )
    parser.add_argument(
        '--aggressive',
        action='store_true',
        help='激进模式：尝试清理不在严格行尾的「答案：X」标记',
    )

    args = parser.parse_args()

    json_path = Path(args.json)
    db_path = Path(args.db)

    total_touched = 0

    if not args.skip_json:
        if not json_path.exists():
            print(f'[JSON] 文件不存在，跳过: {json_path}')
        else:
            touched, stem_fixed, answer_filled, answer_conflicts = clean_json(
                json_path, args.dry_run, args.aggressive
            )
            total_touched += touched
            print(
                f'[JSON] 命中: {touched}, 题干修复: {stem_fixed}, 回填答案: {answer_filled}, 答案冲突: {answer_conflicts}'
            )

    if not args.skip_db:
        if not db_path.exists():
            print(f'[DB] 文件不存在，跳过: {db_path}')
        else:
            touched, stem_fixed, answer_filled, answer_conflicts = clean_db(
                db_path, args.dry_run, args.aggressive
            )
            total_touched += touched
            print(
                f'[DB] 命中: {touched}, 题干修复: {stem_fixed}, 回填答案: {answer_filled}, 答案冲突: {answer_conflicts}'
            )

    if args.dry_run:
        print('Dry-run 完成（未写入）。')
    elif total_touched == 0:
        print('未发现需要清洗的数据。')
    else:
        print('清洗完成。')


if __name__ == '__main__':
    main()
