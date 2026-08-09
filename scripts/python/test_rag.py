import sqlite3, struct, math, random, os
DB_PATH = os.path.expanduser("~/NOMADZ-0/omega_memory.db")

def cosine_similarity(v1, v2):
    dot = sum(a*b for a, b in zip(v1, v2))
    mag1 = math.sqrt(sum(a*a for a in v1))
    mag2 = math.sqrt(sum(b*b for b in v2))
    return dot / (mag1 * mag2) if mag1 and mag2 else 0.0

def pack_vec(v): return struct.pack('%uff' % len(v), *v)
def unpack_vec(b): return struct.unpack('%uff' % (len(b)//4), b)


conn = sqlite3.connect(DB_PATH)
c = conn.cursor()

c.execute('''CREATE TABLE IF NOT EXISTS entitymemories (
    memoryid TEXT, entityid TEXT, sessionid TEXT, timestamp TEXT,
    memorytype TEXT, content TEXT, embedding512D BLOB, relevancescore REAL)''')

c.execute("SELECT COUNT(*) FROM entitymemories")
if c.fetchone()[0] == 0:
    print("[*] Seeding omega_memory.db with test vectors...")
    v1 = [random.uniform(-1, 1) for _ in range(512)]
    v2 = [random.uniform(-1, 1) for _ in range(512)]
    v3 = [random.uniform(-1, 1) for _ in range(512)]
    
    c.execute("INSERT INTO entitymemories VALUES (?,?,?,?,?,?,?,?)", 
              ("mem-01", "Proxy", "s1", "2026", "action", "Player shattered the crystalline shrine.", pack_vec(v1), 0.9))
    c.execute("INSERT INTO entitymemories VALUES (?,?,?,?,?,?,?,?)", 
              ("mem-02", "Echo", "s1", "2026", "dialog", "Player asked about the WORMHOLE.", pack_vec(v2), 0.8))
    c.execute("INSERT INTO entitymemories VALUES (?,?,?,?,?,?,?,?)", 
              ("mem-03", "Node", "s1", "2026", "observation", "Player ignored the anomaly.", pack_vec(v3), 0.7))
    conn.commit()

print("[+] AI Agent asks: 'What did the player break?'")
c.execute("SELECT embedding512D FROM entitymemories WHERE memoryid='mem-01'")
base_vec = unpack_vec(c.fetchone()[0])
query_vec = [x + random.uniform(-0.1, 0.1) for x in base_vec]

results = []
c.execute("SELECT memoryid, content, embedding512D FROM entitymemories")
for row in c.fetchall():
    score = cosine_similarity(query_vec, unpack_vec(row[2]))
    results.append((score, row[1]))

results.sort(key=lambda x: x[0], reverse=True)

print("--- RETRIEVAL RESULTS ---")
for i, (score, txt) in enumerate(results):
    print("Rank %d [Similarity: .4f]: %s" % (i+1, score, txt))

conn.close()