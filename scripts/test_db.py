import sqlite3
db = 'assets/data.db'
try:
    conn = sqlite3.connect(db)
    cur = conn.cursor()
    print(cur.execute('PRAGMA table_info(questions)').fetchall())
except Exception as e:
    print('ERROR:', e)