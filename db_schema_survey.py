import sqlite3
from pathlib import Path
from collections import defaultdict

EXCLUDE = ["-VAULT-", ".git", "node_modules"]
schema_registry = defaultdict(list)
results = []

for db_path in Path.home().rglob("*.db"):
    if any(x in str(db_path) for x in EXCLUDE):
        continue
    try:
        conn = sqlite3.connect("file:" + str(db_path) + "?mode=ro&timeout=2", uri=True)
        conn.execute("PRAGMA wal_checkpoint(PASSIVE)")
        tables = conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        table_data = []
        total_rows = 0
        for (tname,) in tables:
            try:
                count = conn.execute('SELECT COUNT(*) FROM "' + tname + '"').fetchone()[0]
                table_data.append((tname, count))
                total_rows += count
                schema_registry[tname].append(db_path.name)
            except Exception:
                table_data.append((tname, -1))
        conn.close()
        results.append((total_rows, db_path, table_data))
    except Exception as e:
        print("  [SKIP] " + db_path.name + ": " + str(e))

results.sort(reverse=True, key=lambda x: x[0])

print("=" * 60)
print("  NOMADZ DB HEAT MAP")
print("=" * 60)
for total, db_path, table_data in results:
    print("")
    print(">> " + db_path.name + "  [" + str(total) + " rows]")
    print("   " + str(db_path.parent))
    for tname, count in sorted(table_data, key=lambda x: -x[1]):
        flag = " <OVERLAP>" if len(schema_registry[tname]) > 1 else ""
        row_display = str(count) if count >= 0 else "locked"
        print("   " + tname + ": " + row_display + flag)

print("")
print("=" * 60)
print("  SCHEMA OVERLAPS")
print("=" * 60)
overlaps = {k: v for k, v in schema_registry.items() if len(v) > 1}
if overlaps:
    for tname, owners in sorted(overlaps.items()):
        print("")
        print("  [" + tname + "]")
        for owner in owners:
            print("    -> " + owner)
else:
    print("  No overlaps. Clean.")

print("")
print("[DONE]")
