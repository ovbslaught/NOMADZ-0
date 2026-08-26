/data/data/com.termux/files/home/audit_integrity.sh
cd ~/NOMADZ-0
# 1. Create the workflow directory
mkdir -p .github/workflows
# 2. Paste the workflow file
cat > .github/workflows/build.yml << 'EOF'
name: Build NOMADZ-0 (Windows + Android)

on:
  push:
    branches: [ main ]
    tags:
      - 'v*'
  pull_request:
    branches: [ main ]

jobs:
  build:
    name: Export Godot 4.5
    runs-on: ubuntu-latest
    container:
      image: barichello/godot-ci:4.5

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          lfs: true

      - name: Setup Godot export templates
        run: |
          mkdir -v -p ~/.local/share/godot/export_templates/
          mv /root/.local/share/godot/export_templates/4.5.stable ~/.local/share/godot/export_templates/4.5.stable

      - name: Setup Android SDK
        run: |
          echo "y" | sdkmanager --install "build-tools;34.0.0" "platforms;android-34" "platform-tools"

      - name: Create build output dirs
        run: |
          mkdir -p build/windows
          mkdir -p build/android

      - name: Export Windows Desktop
        run: |
          godot --headless --export-release "Windows Desktop" build/windows/NOMADZ-0.exe

      - name: Export Android (Debug APK)
        run: |
          godot --headless --export-debug "Android" build/android/NOMADZ-0-debug.apk

      - name: Upload Windows artifact
        uses: actions/upload-artifact@v4
        with:
          name: NOMADZ-0-Windows
          path: build/windows/
          retention-days: 30

      - name: Upload Android artifact
        uses: actions/upload-artifact@v4
        with:
          name: NOMADZ-0-Android
          path: build/android/
          retention-days: 30

      - name: Create GitHub Release
        if: startsWith(github.ref, 'refs/tags/v')
        uses: softprops/action-gh-release@v2
        with:
          files: |
            build/windows/NOMADZ-0.exe
            build/android/NOMADZ-0-debug.apk
          generate_release_notes: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
EOF

# 3. Commit and push
git add .github/workflows/build.yml export_presets.cfg RENDERER_WARNING.md
git commit -m "🚀 LAUNCH UNBLOCK: CI/CD + export presets for Windows & Android"
git push origin main
git pull --rebase origin main
ls -la .github/workflows/
python3 - << 'PYEOF'
import os

os.makedirs(".github/workflows", exist_ok=True)
os.makedirs("build/windows", exist_ok=True)
os.makedirs("build/android", exist_ok=True)

with open(".github/workflows/build.yml", "w") as f:
    f.write(open(".github/workflows/build.yml").read() if os.path.exists(".github/workflows/build.yml") else "")
    
print("Check: .github/workflows/build.yml exists:", os.path.exists(".github/workflows/build.yml"))
print("Check: export_presets.cfg exists:", os.path.exists("export_presets.cfg"))
PYEOF

ls -la && ls -la .github/ 2>/dev/null || echo "NO .github DIR"
cd ~/NOMADZ-0 && pwd && git status
pkg update
pkg install cc65 make python git
cd
pkg update
pkg install cc65 make python git
ca65 --version
ld65 --version
make clean && make
cd ~/ZELDA-123
pwd
ls
ls -l Makefile
sed -n '1,120p' Makefile
make clean
make
cd ~/ZELDA-123
mkdir -p src/engine
cat > src/engine/ppu.asm << 'EOF'
.p816
.smart

.export PPU_PushScroll
.export PPU_FlushQueues

.segment "CODE"

.proc PPU_PushScroll
    rts
.endproc

.proc PPU_FlushQueues
    rts
.endproc
EOF

make clean
make
.include "engine/ppu.asm"
grep -n '.include "engine/' src/main.asm
sed -i '/.include "engine/input.asm"/a .include "engine/ppu.asm"' src/main.asm
grep -n '.include "engine/' src/main.asm
make clean
make
grep -n 'engine/' src/main.asm
sed -i '/engine/input.asm/a .include "engine/ppu.asm"' src/main.asm
grep -n 'engine/' src/main.asm
make clean
make
cd ~/ZELDA-123
nl -ba src/main.asm | sed -n '1,160p'
.import PPU_PushScroll
.import PPU_FlushQueues
cd ~/ZELDA-123
sed -i '/.import PPU_QueueScroll/a .import PPU_PushScroll
.import PPU_FlushQueues' src/main.asm
nl -ba src/main.asm | sed -n '10,20p'
make clean
make
d ~/ZELDA-123 && python3 - <<'PY'
from pathlib import Path

main = Path("src/main.asm")
ppu  = Path("src/engine/ppu.asm")
text = main.read_text()

if ".import PPU_PushScroll" not in text:
    text = text.replace(
        ".import PPU_QueueScroll
",
        ".import PPU_QueueScroll
.import PPU_PushScroll
.import PPU_FlushQueues
",
        1
    )

main.write_text(text)

ppu.parent.mkdir(parents=True, exist_ok=True)
ppu.write_text(
""".p816
.smart

.export PPU_QueueScroll
.export PPU_PushScroll
.export PPU_FlushQueues

.segment "CODE"

.proc PPU_QueueScroll
    rts
.endproc

.proc PPU_PushScroll
    rts
.endproc

.proc PPU_FlushQueues
    rts
.endproc
"""
)
print("patched src/main.asm and src/engine/ppu.asm")
PY

nl -ba src/main.asm | sed -n '10,22p'
printf '
--- src/engine/ppu.asm ---
'
sed -n '1,80p' src/engine/ppu.asm
make clean && make
cd ~/ZELDA-123 && python3 - <<'PY'
from pathlib import Path
p = Path("src/main.asm")
s = p.read_text()

# remove stale imports if present; local stubs won't need them
s = s.replace(".import PPU_PushScroll
", "")
s = s.replace(".import PPU_FlushQueues
", "")

# inject local stubs once, right before IRQHandler
marker = ".proc IRQHandler
"
stub = """.proc PPU_PushScroll
    rts
.endproc

.proc PPU_FlushQueues
    rts
.endproc

"""
if ".proc PPU_PushScroll" not in s:
    s = s.replace(marker, stub + marker, 1)

p.write_text(s)
print("patched src/main.asm with local PPU stubs")
PY

make clean && make
cd ~/ZELDA-123 && pkg install -y python >/dev/null 2>&1 || true && python3 - <<'PY'
from pathlib import Path
import sys

p = Path("src/main.asm")
if not p.exists():
    print("FATAL: src/main.asm not found", file=sys.stderr)
    sys.exit(1)

s = p.read_text()

for needle in [
    '.import PPU_PushScroll
',
    '.import PPU_FlushQueues
',
]:
    s = s.replace(needle, '')

stub = """.proc PPU_PushScroll
    rts
.endproc

.proc PPU_FlushQueues
    rts
.endproc

"""

marker = ".proc IRQHandler
"
if ".proc PPU_PushScroll" not in s:
    if marker not in s:
        print("FATAL: could not find IRQHandler insertion point", file=sys.stderr)
        sys.exit(2)
    s = s.replace(marker, stub + marker, 1)

p.write_text(s)
print("PATCHED src/main.asm")
PY

make clean && make
cd ~/ZELDA-123 && pkg install -y python >/dev/null 2>&1 || true && python3 - <<'PY'
from pathlib import Path
import sys

p = Path("src/main.asm")
if not p.exists():
    print("FATAL: src/main.asm not found", file=sys.stderr)
    raise SystemExit(1)

s = p.read_text()

s = s.replace(".import PPU_PushScroll
", "")
s = s.replace(".import PPU_FlushQueues
", "")

stub = (
    ".proc PPU_PushScroll
"
    "    rts
"
    ".endproc
"
    "
"
    ".proc PPU_FlushQueues
"
    "    rts
"
    ".endproc
"
    "
"
)

marker = ".proc IRQHandler
"
if ".proc PPU_PushScroll" not in s:
    if marker not in s:
        print("FATAL: could not find IRQHandler insertion point", file=sys.stderr)
        raise SystemExit(2)
    s = s.replace(marker, stub + marker, 1)

p.write_text(s)
print("PATCHED src/main.asm")
PY

make clean && make
#!/usr/bin/env bash
set -euo pipefail
trap 'rc=$?; printf "ERROR: command failed with exit %s
" "$rc" >&2' ERR
command -v python3 >/dev/null 2>&1 || pkg install -y python >/dev/null 2>&1
PROJECT_DIR="${HOME}/ZELDA-123"
MAIN_ASM="${PROJECT_DIR}/src/main.asm"
mkdir -p "${PROJECT_DIR}/src"
cat << 'PY' | python3
from pathlib import Path
import sys

project_dir = Path.home() / "ZELDA-123"
main_asm = project_dir / "src" / "main.asm"

if not main_asm.exists():
    print(f"FATAL: missing {main_asm}", file=sys.stderr)
    raise SystemExit(1)

text = main_asm.read_text(encoding="utf-8")

text = text.replace(".import PPU_PushScroll
", "")
text = text.replace(".import PPU_FlushQueues
", "")

stub = (
    ".proc PPU_PushScroll
"
    "    rts
"
    ".endproc
"
    "
"
    ".proc PPU_FlushQueues
"
    "    rts
"
    ".endproc
"
    "
"
)

marker = ".proc IRQHandler
"
if ".proc PPU_PushScroll" not in text:
    if marker not in text:
        print("FATAL: could not find IRQHandler insertion point in src/main.asm", file=sys.stderr)
        raise SystemExit(2)
    text = text.replace(marker, stub + marker, 1)

main_asm.write_text(text, encoding="utf-8")
print("PATCHED", main_asm)
PY

#!/usr/bin/env bash
set -euo pipefail
trap 'rc=$?; printf "ERROR: command failed with exit %s
" "$rc" >&2' ERR
command -v python3 >/dev/null 2>&1 || pkg install -y python >/dev/null 2>&1
PROJECT_DIR="${HOME}/ZELDA-123"
MAIN_ASM="${PROJECT_DIR}/src/main.asm"
mkdir -p "${PROJECT_DIR}/src"
cat << 'PY' | python3
from pathlib import Path
import sys

project_dir = Path.home() / "ZELDA-123"
main_asm = project_dir / "src" / "main.asm"

if not main_asm.exists():
    print(f"FATAL: missing {main_asm}", file=sys.stderr)
    raise SystemExit(1)

text = main_asm.read_text(encoding="utf-8")

text = text.replace(".import PPU_PushScroll
", "")
text = text.replace(".import PPU_FlushQueues
", "")

stub = (
    ".proc PPU_PushScroll
"
    "    rts
"
    ".endproc
"
    "
"
    ".proc PPU_FlushQueues
"
    "    rts
"
    ".endproc
"
    "
"
)

marker = ".proc IRQHandler
"
if ".proc PPU_PushScroll" not in text:
    if marker not in text:
        print("FATAL: could not find IRQHandler insertion point in src/main.asm", file=sys.stderr)
        raise SystemExit(2)
    text = text.replace(marker, stub + marker, 1)

main_asm.write_text(text, encoding="utf-8")
print("PATCHED", main_asm)
PY

#!/usr/bin/env bash
set -euo pipefail
trap 'rc=$?; printf "ERROR: command failed with exit %s
" "$rc" >&2' ERR
command -v python3 >/dev/null 2>&1 || pkg install -y python >/dev/null 2>&1
command -v make >/dev/null 2>&1 || pkg install -y make >/dev/null 2>&1
command -v ca65 >/dev/null 2>&1 || pkg install -y cc65 >/dev/null 2>&1
PROJECT_DIR="${HOME}/ZELDA-123"
TARGET_FILE="${PROJECT_DIR}/src/main.asm"
if [ ! -f "${TARGET_FILE}" ]; then   printf "ERROR: missing %s
" "${TARGET_FILE}" >&2;   exit 1; fi
cat << 'PY' > "${PROJECT_DIR}/.patch_main_asm.py"
from __future__ import annotations
import sys
from pathlib import Path

target_file = Path.home() / "ZELDA-123" / "src" / "main.asm"
if not target_file.exists():
    sys.stderr.write(f"ERROR: Target file {target_file} does not exist.
")
    raise SystemExit(1)

content = target_file.read_text(encoding="utf-8")

content = content.replace(r'''.import PPU_PushScroll
''', '')
content = content.replace(r'''.import PPU_FlushQueues
''', '')

stub_block = r'''.proc PPU_PushScroll
    rts
.endproc

.proc PPU_FlushQueues
    rts
.endproc

'''

marker = r'''.proc IRQHandler
'''

if r'''.proc PPU_PushScroll
''' not in content:
    if marker not in content:
        sys.stderr.write("ERROR: could not find IRQHandler insertion point in src/main.asm
")
        raise SystemExit(2)
    content = content.replace(marker, stub_block + marker, 1)

target_file.write_text(content, encoding="utf-8")
print(f"SUCCESS: Patched {target_file}")
PY

python3 "${PROJECT_DIR}/.patch_main_asm.py"
