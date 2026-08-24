import os
import shutil
import json
import time
import re
import subprocess
from datetime import datetime

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    requests = None
    BeautifulSoup = None

base_wormhole = os.path.expanduser("~/storage/shared/Wormhole")
if not os.path.exists(base_wormhole):
    base_wormhole = os.path.expanduser("~/WORMHOLE")

MB_ROOT = os.path.join(base_wormhole, "MOTHER-BRAIN")
INBOX = os.path.join(MB_ROOT, "00_Inbox")
RESEARCH_DIR = os.path.join(MB_ROOT, "04_Research")
SECRETS_FILE = os.path.join(MB_ROOT, "Security", "secrets.json")
LOG_FILE = os.path.join(MB_ROOT, "99_System_Logs", "daemon.log")

PROTECTED_DIRS = {
    "MOTHER-BRAIN", "-VAULT-", "FATHER-BRAIN", "VULTURE-BRAIN", 
    "OMEGA-BRAIN", "COSMIC-BRAIN", "GEO-BRAIN", "NOMADZ-0", ".git"
}

for d in [INBOX, RESEARCH_DIR, os.path.join(MB_ROOT, "Security"), os.path.join(MB_ROOT, "99_System_Logs")]:
    os.makedirs(d, exist_ok=True)

def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry = f"[{ts}] {msg}"
    print(entry)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(entry + "\n")
    except Exception:
        pass

def scan_creds(path):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
    except Exception:
        return

    patterns = {
        "OPENAI": r"sk-[a-zA-Z0-9]{48}",
        "GITHUB": r"ghp_[a-zA-Z0-9]{36}",
        "FIRECRAWL": r"fc-[a-zA-Z0-9]{32}"
    }
    found = {}
    for k, p in patterns.items():
        m = re.search(p, content)
        if m:
            found[k] = m.group(0)

    if found:
        secrets = {}
        if os.path.exists(SECRETS_FILE):
            try:
                with open(SECRETS_FILE, "r", encoding="utf-8") as f:
                    secrets = json.load(f)
            except Exception:
                secrets = {}
        secrets.update(found)
        with open(SECRETS_FILE, "w", encoding="utf-8") as f:
            json.dump(secrets, f, indent=2)
        log(f"SECURITY: Extracted {list(found.keys())} from {os.path.basename(path)}")
        if "key" in os.path.basename(path).lower():
            try:
                os.remove(path)
            except Exception:
                pass

def do_research(path):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            q = f.read().strip()
    except Exception:
        return

    if not q.startswith("RESEARCH:"):
        return

    query = q.replace("RESEARCH:", "").strip()
    log(f"RESEARCH: Starting job '{query}'...")
    out = f"# Report: {query}\n\n"

    if "http" in query and requests and BeautifulSoup:
        try:
            r = requests.get(query, timeout=10)
            s = BeautifulSoup(r.content, "html.parser")
            out += f"## {s.title.string if s.title else 'No Title'}\n\n"
            for p in s.find_all("p")[:15]:
                out += p.get_text() + "\n\n"
        except Exception as e:
            out += f"Error: {e}\n"

    fname = f"Report_{int(time.time())}.md"
    with open(os.path.join(RESEARCH_DIR, fname), "w", encoding="utf-8") as f:
        f.write(out)
    log(f"RESEARCH: Finished {fname}")
    try:
        os.remove(path)
    except Exception:
        pass

def git_sync():
    if not os.path.exists(os.path.join(MB_ROOT, ".git")):
        return
    try:
        subprocess.run(["git", "-C", MB_ROOT, "add", "."], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        status = subprocess.run(["git", "-C", MB_ROOT, "status", "--porcelain"], capture_output=True, text=True)
        if status.stdout.strip():
            msg = f"Auto-Sync {datetime.now().strftime('%Y-%m-%d %H:%M')}"
            subprocess.run(["git", "-C", MB_ROOT, "commit", "-m", msg], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["git", "-C", MB_ROOT, "push"], stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
            log("GIT: Synced.")
    except Exception:
        pass

def run():
    print(f"[*] DAEMON ONLINE WATCHING: {base_wormhole}")
    while True:
        if os.path.exists(base_wormhole):
            for item in os.listdir(base_wormhole):
                if item in PROTECTED_DIRS:
                    continue
                src = os.path.join(base_wormhole, item)
                if os.path.isfile(src):
                    dst = os.path.join(INBOX, item)
                    try:
                        shutil.move(src, dst)
                        log(f"INGEST: {item}")
                        scan_creds(dst)
                        do_research(dst)
                    except Exception as e:
                        log(f"INGEST_ERROR: {item} - {e}")

        if int(time.time()) % 60 < 5:
            git_sync()
        time.sleep(5)

if __name__ == "__main__":
    run()
