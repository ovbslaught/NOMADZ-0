#!/usr/bin/env python3
"""ADE-CORE Production Engine v1.2 — Samsung Galaxy S23 Ultra / Termux / ARM64"""
from __future__ import annotations
import argparse, hashlib, json, logging, os, platform, shutil
import signal, sqlite3, subprocess, sys, time, traceback, uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Optional

ENGINE_ROOT   = Path.home() / "ade"
DB_PATH       = ENGINE_ROOT / "ade_core.db"
LOG_PATH      = ENGINE_ROOT / "logs" / "ade_engine.log"
WORMHOLE_ROOT = Path("/sdcard/WORMHOLE")
TERMUX_PREFIX = Path("/data/data/com.termux/files")
CORE_PINS     = [4, 5, 6, 7]
QUARANTINE_MAX   = 3
VULTURE_INTERVAL = 30

def _setup_logging() -> logging.Logger:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    fmt = "%(asctime)s [ADE-%(levelname)s] %(message)s"
    logging.basicConfig(level=logging.INFO, format=fmt,
        handlers=[logging.StreamHandler(sys.stderr),
                  logging.FileHandler(LOG_PATH, encoding="utf-8")])
    return logging.getLogger("ade_core")

log = _setup_logging()

def resolve_binary(name: str) -> Optional[str]:
    p = shutil.which(name)
    if p: return p
    t = TERMUX_PREFIX / "usr" / "bin" / name
    return str(t) if t.exists() else None

def pin_to_big_cores() -> None:
    try:
        import ctypes
        mask = sum(1 << c for c in CORE_PINS)
        libc = ctypes.CDLL("libc.so", use_errno=True)
        libc.sched_setaffinity(0, ctypes.sizeof(ctypes.c_ulong),
                               ctypes.byref(ctypes.c_ulong(mask)))
        log.info("CPU pinned cores=%s mask=0x%x", CORE_PINS, mask)
    except Exception as e:
        log.warning("CPU pin skipped: %s", e)

@contextmanager
def get_db():
    con = sqlite3.connect(DB_PATH, timeout=10, check_same_thread=False)
    con.row_factory = sqlite3.Row
    try:
        con.execute("PRAGMA journal_mode=WAL")
        con.execute("PRAGMA synchronous=NORMAL")
        con.execute("PRAGMA foreign_keys=ON")
        yield con; con.commit()
    except Exception:
        con.rollback(); raise
    finally:
        con.close()

SCHEMA_SQL = (
    "CREATE TABLE IF NOT EXISTS ade_skills("
    "skill_id INTEGER PRIMARY KEY AUTOINCREMENT,"
    "name TEXT NOT NULL UNIQUE,sha256 TEXT NOT NULL,"
    "runtime TEXT NOT NULL DEFAULT \'python3\',"
    "entrypoint TEXT NOT NULL,enabled INTEGER NOT NULL DEFAULT 1,"
    "registered_at REAL NOT NULL DEFAULT (unixepoch(\'now\')));"
    "CREATE TABLE IF NOT EXISTS ade_runtime_logs("
    "log_id INTEGER PRIMARY KEY AUTOINCREMENT,"
    "skill_id INTEGER REFERENCES ade_skills(skill_id),"
    "execution_id TEXT NOT NULL,event_type TEXT NOT NULL,"
    "exit_code INTEGER,duration_ms INTEGER,payload TEXT,"
    "created_at REAL NOT NULL DEFAULT (unixepoch(\'now\')));"
    "CREATE TABLE IF NOT EXISTS ade_error_traces("
    "trace_id INTEGER PRIMARY KEY AUTOINCREMENT,"
    "skill_id INTEGER REFERENCES ade_skills(skill_id),"
    "error_class TEXT NOT NULL,fingerprint TEXT NOT NULL,"
    "traceback TEXT,occurrence_count INTEGER NOT NULL DEFAULT 1,"
    "quarantined INTEGER NOT NULL DEFAULT 0,quarantined_at REAL,"
    "first_seen REAL NOT NULL DEFAULT (unixepoch(\'now\')),last_seen REAL NOT NULL DEFAULT (unixepoch(\'now\')));"
    "CREATE TABLE IF NOT EXISTS ade_state_vectors("
    "vec_id INTEGER PRIMARY KEY AUTOINCREMENT,"
    "session_id TEXT NOT NULL,db_path TEXT NOT NULL,"
    "engine_root TEXT NOT NULL,wormhole TEXT NOT NULL,"
    "skills_count INTEGER NOT NULL DEFAULT 0,"
    "open_errors INTEGER NOT NULL DEFAULT 0,"
    "wal_mode TEXT NOT NULL DEFAULT \'wal\',"
    "last_run_ts REAL NOT NULL DEFAULT (unixepoch(\'now\')),heartbeat_node TEXT NOT NULL DEFAULT \'ADE-CORE\',"
    "updated_at REAL NOT NULL DEFAULT (unixepoch(\'now\')));"
    "CREATE INDEX IF NOT EXISTS idx_rt_ts  ON ade_runtime_logs(created_at);"
    "CREATE INDEX IF NOT EXISTS idx_err_fp ON ade_error_traces(fingerprint);"
    "CREATE INDEX IF NOT EXISTS idx_sv_sid ON ade_state_vectors(session_id);"
)

SESSION_ID = uuid.uuid4().hex[:12]

def init_schema() -> None:
    for d in [ENGINE_ROOT/"logs", ENGINE_ROOT/"state", ENGINE_ROOT/"tmp"]:
        d.mkdir(parents=True, exist_ok=True)
    WORMHOLE_ROOT.mkdir(parents=True, exist_ok=True)
    with get_db() as con:
        schema = SCHEMA_SQL.replace("\'", "'")
        for stmt in schema.split(";"):
            s = stmt.strip()
            if s:
                con.execute(s)
    log.info("Schema OK | db=%s | session=%s", DB_PATH, SESSION_ID)

def sha256_of(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()[:12]

def register_skill(name: str, entrypoint: str, runtime: str = "python3") -> int:
    sha = sha256_of(entrypoint)
    with get_db() as con:
        con.execute(
            "INSERT INTO ade_skills(name,sha256,runtime,entrypoint) VALUES(?,?,?,?) "
            "ON CONFLICT(name) DO UPDATE SET "
            "sha256=excluded.sha256,entrypoint=excluded.entrypoint,runtime=excluded.runtime",
            (name, sha, runtime, entrypoint))
        row = con.execute("SELECT skill_id FROM ade_skills WHERE name=?", (name,)).fetchone()
    log.info("Skill registered: %s [Runtime:%s SHA256:%s]", name, runtime, sha)
    return row["skill_id"]

def count_skills() -> int:
    with get_db() as con:
        return con.execute("SELECT COUNT(*) FROM ade_skills WHERE enabled=1").fetchone()[0]

def execute_skill(skill_id: int, name: str, entrypoint: str,
                  runtime: str = "python3") -> dict[str, Any]:
    exec_id = uuid.uuid4().hex[:8]
    bin_    = resolve_binary(runtime) or runtime
    t0 = time.monotonic()
    res: dict[str, Any] = {"exit_code": -1, "duration_ms": 0, "output": ""}
    try:
        p = subprocess.run([bin_, "-c", entrypoint],
                           capture_output=True, text=True, timeout=60)
        ms = int((time.monotonic() - t0) * 1000)
        res = {"exit_code": p.returncode, "duration_ms": ms,
               "output": p.stdout.strip()}
        log.info("Skill %s done (%dms exit=%d).", name, ms, p.returncode)
        if p.stdout.strip():
            print(p.stdout.strip())
    except subprocess.TimeoutExpired:
        res["exit_code"] = 124
        log.error("Skill %s timed out.", name)
    except Exception as exc:
        res["exit_code"] = 1
        log.error("Skill %s error: %s", name, exc)
        _record_error(skill_id, type(exc).__name__, traceback.format_exc())
    with get_db() as con:
        con.execute(
            "INSERT INTO ade_runtime_logs"
            "(skill_id,execution_id,event_type,exit_code,duration_ms,payload,created_at)"
            "VALUES(?,?,?,?,?,?,?)",
            (skill_id, exec_id, "execution", res["exit_code"],
             res["duration_ms"], res["output"], time.time()))
    return res

def _record_error(skill_id: int, ec: str, tb: str) -> None:
    fp = hashlib.md5(tb.encode()).hexdigest()[:16]
    with get_db() as con:
        row = con.execute(
            "SELECT trace_id,occurrence_count FROM ade_error_traces WHERE fingerprint=?",
            (fp,)).fetchone()
        if row:
            cnt = row["occurrence_count"] + 1
            q   = int(cnt >= QUARANTINE_MAX)
            con.execute(
                "UPDATE ade_error_traces SET occurrence_count=?,quarantined=?,"
                "quarantined_at=CASE WHEN ?=1 THEN unixepoch(\'now\') ELSE quarantined_at END,"
                "last_seen=unixepoch(\'now\') WHERE fingerprint=?".replace("\'", "'"),
                (cnt, q, q, fp))
            if q:
                log.warning("VULTURE: skill %d quarantined fp=%s", skill_id, fp)
        else:
            con.execute(
                "INSERT INTO ade_error_traces(skill_id,error_class,fingerprint,traceback)"
                "VALUES(?,?,?,?)", (skill_id, ec, fp, tb))

def open_error_count() -> int:
    with get_db() as con:
        return con.execute(
            "SELECT COUNT(*) FROM ade_error_traces WHERE quarantined=0").fetchone()[0]

def upsert_state_vector(skills_count: int = 0, open_errors: int = 0,
                         heartbeat_node: str = "ADE-CORE") -> None:
    with get_db() as con:
        con.execute(
            "INSERT INTO ade_state_vectors"
            "(session_id,db_path,engine_root,wormhole,skills_count,open_errors,"
            "wal_mode,last_run_ts,heartbeat_node,updated_at)"
            "VALUES(?,?,?,?,?,?,?,?,?,?)",
            (SESSION_ID, str(DB_PATH), str(ENGINE_ROOT), str(WORMHOLE_ROOT),
             skills_count, open_errors, "wal", time.time(), heartbeat_node, time.time()))

def vulture_brain_tick() -> None:
    e = open_error_count(); s = count_skills()
    upsert_state_vector(skills_count=s, open_errors=e,
                        heartbeat_node="MOTHER-BRAIN-CORE")
    status = "ZERO_ERROR_CONVERGENCE" if e == 0 else f"OPEN_ERRORS={e}"
    log.info("VULTURE-BRAIN | %s | skills=%d", status, s)

def wal_checkpoint() -> None:
    with get_db() as con:
        con.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    log.info("WAL checkpoint complete")

_SHUTDOWN = False
def _handle_signal(sig: int, _: Any) -> None:
    global _SHUTDOWN
    log.info("Signal %d received", sig); _SHUTDOWN = True

signal.signal(signal.SIGINT,  _handle_signal)
signal.signal(signal.SIGTERM, _handle_signal)

# ── Built-in skill code (single-line strings — no embedded newlines) ─────────
OMEGA_CODE = (
    "import platform,json,time,os; "
    "print(json.dumps({"
    "'node':'OMEGA-BRAIN',"
    "'platform':platform.platform(),"
    "'arch':platform.machine(),"
    "'python':platform.python_version(),"
    "'pid':os.getpid(),"
    "'timestamp':int(time.time()),"
    "'status':'OPERATIONAL'"
    "}))"
)

SYS_CODE = (
    "import platform,json,time,os; "
    "print(json.dumps({"
    "'node':'ADE-CORE',"
    "'platform':platform.platform(),"
    "'arch':platform.machine(),"
    "'python':platform.python_version(),"
    "'pid':os.getpid(),"
    "'timestamp':int(time.time()),"
    "'status':'OPERATIONAL'"
    "}))"
)

# ── Commands ─────────────────────────────────────────────────────────────────
def cmd_init(_: argparse.Namespace) -> None:
    init_schema()
    print(json.dumps({"status":"INIT_OK","db":str(DB_PATH),"session":SESSION_ID},indent=2))

def cmd_synth(args: argparse.Namespace) -> None:
    name      = args.skill or "omega_probe"
    entrypoint= args.entry or OMEGA_CODE
    runtime   = args.runtime or "python3"
    sid = register_skill(name, entrypoint, runtime)
    print(json.dumps({"status":"SYNTH_OK","skill_id":sid,"name":name,
                      "sha256":sha256_of(entrypoint)},indent=2))

def cmd_run(args: argparse.Namespace) -> None:
    name = args.skill or "omega_probe"
    with get_db() as con:
        row = con.execute(
            "SELECT skill_id,entrypoint,runtime FROM ade_skills WHERE name=? AND enabled=1",
            (name,)).fetchone()
    if not row:
        print(f"[ERROR] Skill not found: {name}", file=sys.stderr); sys.exit(1)
    res = execute_skill(row["skill_id"], name, row["entrypoint"], row["runtime"])
    print(json.dumps(res, indent=2))

def cmd_status(_: argparse.Namespace) -> None:
    s = count_skills(); e = open_error_count()
    print(json.dumps({
        "session_id":  SESSION_ID,
        "db_path":     str(DB_PATH),
        "engine_root": str(ENGINE_ROOT),
        "wormhole":    str(WORMHOLE_ROOT),
        "skills_count":s,
        "open_errors": e,
        "wal_mode":    "wal",
        "last_run_ts": int(time.time()),
        "convergence": "ZERO_ERROR_CONVERGENCE" if e == 0 else f"ERRORS={e}",
    }, indent=2))

def cmd_audit(_: argparse.Namespace) -> None:
    with get_db() as con:
        rows = con.execute(
            "SELECT log_id,skill_id,substr(execution_id,1,8) as eid,"
            "event_type,exit_code,duration_ms,"
            "datetime(created_at,\'unixepoch\') as ts "
            "FROM ade_runtime_logs ORDER BY log_id DESC LIMIT 10".replace("\'","'")
        ).fetchall()
    print(f"{'id':>4} {'sk':>4} {'exec_id':>8} {'event':>10} {'ex':>3} {'ms':>5}  ts")
    print("-"*56)
    for r in rows:
        print(f"{r['log_id']:>4} {r['skill_id']:>4} {r['eid']:>8} "
              f"{r['event_type']:>10} {r['exit_code']:>3} {r['duration_ms']:>5}  {r['ts']}")

def cmd_checkpoint(_: argparse.Namespace) -> None:
    wal_checkpoint(); print("[OK] WAL checkpoint complete")

def cmd_sync(_: argparse.Namespace) -> None:
    wal_checkpoint()
    rclone = resolve_binary("rclone")
    if not rclone:
        print("[SKIP] rclone not found"); return
    backup = WORMHOLE_ROOT / "ade" / "backups"
    backup.mkdir(parents=True, exist_ok=True)
    ts   = time.strftime("%Y%m%d_%H%M%S")
    dest = backup / f"ade_core_{ts}.db"
    import shutil as _sh; _sh.copy2(DB_PATH, dest)
    r = subprocess.run([rclone,"copy",str(backup),
                        "gdrive:WORMHOLE/ade/backups","--quiet"],
                       capture_output=True,text=True)
    print(json.dumps({"status":"OK" if r.returncode==0 else f"FAIL({r.returncode})",
                      "snapshot":str(dest)},indent=2))

def cmd_loop(_: argparse.Namespace) -> None:
    """VULTURE-BRAIN continuous loop."""
    log.info("VULTURE-BRAIN loop started (interval=%ds)", VULTURE_INTERVAL)
    last = time.monotonic()
    while not _SHUTDOWN:
        if time.monotonic() - last >= VULTURE_INTERVAL:
            vulture_brain_tick(); last = time.monotonic()
        time.sleep(1)
    wal_checkpoint()

def main() -> None:
    p = argparse.ArgumentParser(prog="ade",
        description="ADE-CORE Engine — NOMADZ-0")
    p.add_argument("command",
        choices=["init","synth","run","audit","status","sync","checkpoint","loop"])
    p.add_argument("--skill",   help="Skill name")
    p.add_argument("--entry",   help="Python code entrypoint (single-line)")
    p.add_argument("--runtime", help="Runtime binary (default: python3)")
    p.add_argument("--no-pin",  action="store_true", help="Skip CPU affinity")
    args = p.parse_args()

    if not args.no_pin:
        pin_to_big_cores()
    init_schema()
    log.info("ADE-CORE online | session=%s | db=%s", SESSION_ID, DB_PATH)

    {
        "init":       cmd_init,
        "synth":      cmd_synth,
        "run":        cmd_run,
        "audit":      cmd_audit,
        "status":     cmd_status,
        "sync":       cmd_sync,
        "checkpoint": cmd_checkpoint,
        "loop":       cmd_loop,
    }[args.command](args)

if __name__ == "__main__":
    main()
