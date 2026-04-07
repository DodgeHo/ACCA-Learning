import sqlite3
import json

def export(db_path: str, out_path: str):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute('SELECT * FROM questions')
    rows = cur.fetchall()
    cols = [d[0] for d in cur.description]
    data = [dict(zip(cols, row)) for row in rows]
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False)
    print(f'exported {len(data)} questions to {out_path}')

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Export questions table to JSON')
    parser.add_argument('--db', help='path to source sqlite database', default='assets/data.db')
    parser.add_argument('--out', help='output json path', default='assets/questions.json')
    args = parser.parse_args()
    export(args.db, args.out)
