#!/usr/bin/env python3
"""
daemon_runner.py - 24/7 persistent automation daemon
Runs firecrawl_pipeline.py every INTERVAL seconds
Start: python3 daemon_runner.py &
Stop: kill $(cat /tmp/nomadz_daemon.pid)
"""
import os, sys, time, subprocess, signal
from datetime import datetime

REPO = os.environ.get('NOMADZ_REPO', '/workspaces/NOMADZ-0')
LOG = os.path.join(REPO, 'logs', 'daemon.log')
PID_FILE = '/tmp/nomadz_daemon.pid'
PIPELINE = os.path.join(REPO, 'scripts/automation/firecrawl_pipeline.py')
SNAPSHOT = os.path.join(REPO, 'scripts/ouroboros_snapshot.py')
GIT_PUSH = os.path.join(REPO, 'scripts/automation/git_autopush.sh')

PIPELINE_INTERVAL = int(os.environ.get('PIPELINE_INTERVAL', '900'))   # 15 min
SNAPSHOT_INTERVAL = int(os.environ.get('SNAPSHOT_INTERVAL', '3600'))  # 1 hr
GITPUSH_INTERVAL = int(os.environ.get('GITPUSH_INTERVAL', '21600'))   # 6 hr

def log(msg):
    ts = datetime.now().isoformat()
    line = f'[DAEMON][{ts}] {msg}'
    print(line)
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG, 'a') as f: f.write(line + '\n')

def run_script(path, label):
    try:
        result = subprocess.run(['python3', path], capture_output=True, text=True, timeout=300)
        log(f'{label} OK (exit {result.returncode})')
        if result.stdout: log(f'{label} stdout: {result.stdout[-500:]}')
        if result.stderr: log(f'{label} stderr: {result.stderr[-300:]}')
    except subprocess.TimeoutExpired:
        log(f'{label} TIMEOUT')
    except Exception as e:
        log(f'{label} ERROR: {e}')

def run_bash(path, label):
    try:
        result = subprocess.run(['bash', path], capture_output=True, text=True, timeout=120)
        log(f'{label} OK (exit {result.returncode})')
    except Exception as e:
        log(f'{label} ERROR: {e}')

def write_pid():
    with open(PID_FILE, 'w') as f: f.write(str(os.getpid()))

def handle_signal(sig, frame):
    log('Daemon shutting down (signal received)')
    if os.path.exists(PID_FILE): os.remove(PID_FILE)
    sys.exit(0)

def main():
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)
    write_pid()
    log(f'Daemon started. PID={os.getpid()}')
    log(f'Pipeline: {PIPELINE_INTERVAL}s | Snapshot: {SNAPSHOT_INTERVAL}s | GitPush: {GITPUSH_INTERVAL}s')

    last_pipeline = 0
    last_snapshot = 0
    last_gitpush = 0

    while True:
        now = time.time()
        if now - last_pipeline >= PIPELINE_INTERVAL:
            log('--- Running firecrawl_pipeline ---')
            run_script(PIPELINE, 'PIPELINE')
            last_pipeline = now
        if now - last_snapshot >= SNAPSHOT_INTERVAL:
            log('--- Running ouroboros_snapshot ---')
            run_script(SNAPSHOT, 'SNAPSHOT')
            last_snapshot = now
        if now - last_gitpush >= GITPUSH_INTERVAL:
            log('--- Running git_autopush ---')
            if os.path.exists(GIT_PUSH):
                run_bash(GIT_PUSH, 'GITPUSH')
            last_gitpush = now
        time.sleep(60)

if __name__ == '__main__':
    main()
