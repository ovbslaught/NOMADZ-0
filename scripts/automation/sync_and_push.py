#!/usr/bin/env python3
import os
import subprocess
import json
from datetime import datetime

print("[SYNC_AND_PUSH] Starting comprehensive sync...")

# Get current directory structure
workspace_root = "/workspaces/NOMADZ-0"
os.chdir(workspace_root)

print("[SYNC_AND_PUSH] Current directory:", os.getcwd())

# 1. Add all new files to git
print("\n[GIT] Adding new files...")
subprocess.run(["git", "add", "scripts/gdscript/CivAgentAI.gd"])
subprocess.run(["git", "add", "scripts/gdscript/RetroArcadeManager.gd"])

# 2. Create commit message with timestamp
timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
commit_msg = f"""Add RetroArch arcade integration + CivAgentAI - {timestamp}

- Created RetroArcadeManager.gd for in-game arcade cabinets
- Integrated libretro cores (NES, SNES, Genesis, MAME, etc.)
- Built CivAgentAI.gd with arcade learning systems
- AI agents can learn from playing retro games
- Supports multiple art styles: pixel, voxel, cel-shaded
- Ready for procedural planet generation integration
"""

print(f"\n[GIT] Committing with message: {commit_msg[:100]}...")
result = subprocess.run(["git", "commit", "-m", commit_msg], capture_output=True, text=True)
print(result.stdout)

# 3. Push to GitHub Cosmic-key branch
print("\n[GIT] Pushing to GitHub Cosmic-key branch...")
subprocess.run(["git", "push", "origin", "Cosmic-key"])

# 4. Generate folder structure report
print("\n[STRUCTURE] Generating folder structure report...")
structure = {}
for root, dirs, files in os.walk("."):
    if ".git" in root or "node_modules" in root:
        continue
    rel_path = os.path.relpath(root, ".")
    structure[rel_path] = {
        "dirs": dirs[:],
        "files": [f for f in files if not f.startswith(".")]
    }

structure_file = "logs/folder_structure_" + datetime.now().strftime("%Y%m%d_%H%M%S") + ".json"
os.makedirs("logs", exist_ok=True)
with open(structure_file, "w") as f:
    json.dump(structure, f, indent=2)

print(f"[STRUCTURE] Saved to {structure_file}")

# 5. Count files by type
print("\n[STATS] File statistics:")
file_counts = {}
for root, dirs, files in os.walk("."):
    if ".git" in root:
        continue
    for file in files:
        ext = os.path.splitext(file)[1] or "no_extension"
        file_counts[ext] = file_counts.get(ext, 0) + 1

for ext in sorted(file_counts.keys(), key=lambda x: file_counts[x], reverse=True)[:15]:
    print(f"  {ext}: {file_counts[ext]}")

print("\n[SYNC_AND_PUSH] Complete! Structure ready for Drive sync.")
print("[SYNC_AND_PUSH] Next: Use rclone or Drive API to sync to Google Drive")
