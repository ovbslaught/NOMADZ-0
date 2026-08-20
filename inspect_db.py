import sqlite3
import json

db_path = '/data/data/com.termux/files/home/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db'
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

# 1. Fetch all user tables
cursor.execute("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
tables = cursor.fetchall()

report = {}
for tbl in tables:
    t_name = tbl['name']
    t_sql = tbl['sql']
    
    # 2. Count rows
    cursor.execute(f'SELECT COUNT(*) as cnt FROM "{t_name}"')
    row_count = cursor.fetchone()['cnt']
    
    # 3. Fetch latest 3 sample rows
    cursor.execute(f'SELECT * FROM "{t_name}" ORDER BY rowid DESC LIMIT 3')
    samples = [dict(r) for r in cursor.fetchall()]
    
    report[t_name] = {
        'row_count': row_count,
        'schema': t_sql,
        'sample_latest': samples
    }

print(json.dumps(report, indent=2, default=str))
