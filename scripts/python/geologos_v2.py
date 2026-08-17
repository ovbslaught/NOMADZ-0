# geologos_v2.py - GEOLOGOS v2.4 Geological Knowledge System
# Source: Perplexity VOLTRON Space
import sqlite3, json, os

DB = os.environ.get("GEOLOGOS_DB","geologos.db")

def init():
    con=sqlite3.connect(DB)
    con.executescript("""
    CREATE TABLE IF NOT EXISTS strata(id INTEGER PRIMARY KEY,name TEXT,age_ma REAL,lithology TEXT,description TEXT);
    CREATE TABLE IF NOT EXISTS formations(id INTEGER PRIMARY KEY,name TEXT,strata_id INTEGER,location TEXT,FOREIGN KEY(strata_id) REFERENCES strata(id));
    CREATE VIRTUAL TABLE IF NOT EXISTS geo_fts USING fts5(name,description,content=strata);
    """)
    con.commit();return con

def add_stratum(name,age_ma,lithology,desc):
    con=init()
    con.execute("INSERT INTO strata(name,age_ma,lithology,description) VALUES(?,?,?,?)",(name,age_ma,lithology,desc))
    con.commit()

def query_geo(q):
    con=init()
    return con.execute("SELECT name,age_ma,lithology FROM strata WHERE description LIKE ? LIMIT 20",(f'%{q}%',)).fetchall()

if __name__=="__main__":
    import sys
    if len(sys.argv)>1:print(json.dumps(query_geo(sys.argv[1]),indent=2))
