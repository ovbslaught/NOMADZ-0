import os
import subprocess
import json
import time

base_wormhole = os.path.expanduser("~/storage/shared/Wormhole")
if not os.path.exists(base_wormhole):
    base_wormhole = os.path.expanduser("~/WORMHOLE")

TARGET_DIR = os.path.join(base_wormhole, "MOTHER-BRAIN", "01_Knowledge_Graph", "External_Source")
MANIFEST_FILE = os.path.join(TARGET_DIR, "injection_manifest.json")

REPOS = {
    "MCP_Servers": "https://github.com/modelcontextprotocol/servers.git",
    "Awesome_MCP": "https://github.com/punkpeye/awesome-mcp-servers.git",
    "Public_APIs": "https://github.com/public-apis/public-apis.git",
    "Meta_Llama": "https://github.com/facebookresearch/llama.git",
    "Meta_React": "https://github.com/facebook/react.git",
    "X_Algorithm": "https://github.com/twitter/the-algorithm.git",
    "xAI_Grok": "https://github.com/xai-org/grok-1.git"
}

def run():
    print(f"[*] INJECTING KNOWLEDGE INTO: {TARGET_DIR}")
    os.makedirs(TARGET_DIR, exist_ok=True)
    log = []
    
    for name, url in REPOS.items():
        path = os.path.join(TARGET_DIR, name)
        if os.path.exists(path):
            print(f" [✓] Updating {name}...")
            try:
                subprocess.run(["git", "-C", path, "pull", "--ff-only"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                log.append({"repo": name, "status": "UPDATED"})
            except Exception:
                log.append({"repo": name, "status": "UPDATE_FAILED"})
        else:
            print(f" [⬇] Cloning {name} (Depth 1)...")
            try:
                subprocess.run(["git", "clone", "--depth", "1", url, path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                log.append({"repo": name, "status": "CLONED"})
            except Exception:
                log.append({"repo": name, "status": "CLONE_FAILED"})
    
    with open(MANIFEST_FILE, "w", encoding="utf-8") as f:
        json.dump(log, f, indent=2)
    print("[*] Knowledge Injection Complete.")

if __name__ == "__main__":
    run()
