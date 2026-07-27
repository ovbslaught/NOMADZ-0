# local_rag_sqlite.py - SQLite RAG indexer for NOMADZ-0/VULTURE
import sqlite3, os, json

DB_PATH = os.environ.get("RAG_DB","vulture_rag.db")

def init_db():
    con=sqlite3.connect(DB_PATH)
    con.execute("CREATE VIRTUAL TABLE IF NOT EXISTS docs USING fts5(path,content)")
    con.commit();return con

def index_file(path,content):
    con=init_db()
    con.execute("INSERT INTO docs VALUES(?,?)",( path,content))
    con.commit()

def search(query,limit=10):
    con=init_db()
    rows=con.execute("SELECT path,snippet(docs,1,'[',']')'...'',15) FROM docs WHERE docs MATCH ? ORDER BY rank LIMIT ?",( query,limit)).fetchall()
    return rows

if __name__=="__main__":
    import sys
    if len(sys.argv)>2 and sys.argv[1]=="index":
        index_file(sys.argv[2],open(sys.argv[2]).read())
    elif len(sys.argv)>2 and sys.argv[1]=="search":
        for row in search(sys.argv[2]):print(row)
