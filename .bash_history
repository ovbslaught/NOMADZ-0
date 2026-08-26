print(f"SUCCESS: Patched {target_file}")
PY

python3 "${PROJECT_DIR}/.patch_main_asm.py"
#!/usr/bin/env bash
set -euo pipefail
trap 'rc=$?; printf "FATAL: command failed with exit %s
" "$rc" >&2' ERR INT TERM
command -v python3 >/dev/null 2>&1 || pkg install -y python >/dev/null 2>&1
command -v find >/dev/null 2>&1 || pkg install -y findutils >/dev/null 2>&1
TARGET_DIR="${HOME}/WORMHOLE"
VAULT_DIR="${TARGET_DIR}/-VAULT-"
PLAN_DIR="${HOME}/.termux_cleanup"
PLAN_FILE="${PLAN_DIR}/wormhole_relocation_plan.txt"
RUNNER="${PLAN_DIR}/wormhole_relocator.py"
mkdir -p "${TARGET_DIR}" "${VAULT_DIR}" "${PLAN_DIR}"
cat << 'EOF' > "${RUNNER}"
#!/usr/bin/env python3
from __future__ import annotations
import os
import signal
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple

STOP = False

def handle_signal(signum: int, _frame: object) -> None:
    global STOP
    STOP = True
    sys.stderr.write(f"FATAL: received signal {signum}
")
    raise SystemExit(130)

def safe_read_dir(path: Path) -> List[Path]:
    try:
        return sorted(list(path.iterdir()), key=lambda p: p.name.lower())
    except Exception as e:
        sys.stderr.write(f"FATAL: unable to read directory {path}: {e}
")
        raise SystemExit(1)

def main() -> int:
    try:
        signal.signal(signal.SIGINT, handle_signal)
        signal.signal(signal.SIGTERM, handle_signal)

        home = Path.home()
        wormhole = home / "WORMHOLE"
        vault = wormhole / "-VAULT-"
        plan_dir = home / ".termux_cleanup"
        plan_file = plan_dir / "wormhole_relocation_plan.txt"

        if not home.exists():
            sys.stderr.write(f"FATAL: home does not exist: {home}
")
            return 1

        wormhole.mkdir(parents=True, exist_ok=True)
        vault.mkdir(parents=True, exist_ok=True)
        plan_dir.mkdir(parents=True, exist_ok=True)

        protected_names: Set[str] = {
            "WORMHOLE",
            "-VAULT-",
            "storage",
            ".termux",
            ".ssh",
            ".gnupg",
            ".config",
            ".cache",
            ".local",
            ".shortcuts",
            ".termux_cleanup",
            ".gitconfig",
            ".bashrc",
            ".zshrc",
            ".profile",
            ".bash_profile",
            ".bash_history",
            ".zsh_history",
            ".python_history",
            ".vimrc",
            ".git-credentials",
            ".lesshst",
            ".wget-hsts",
            "__pycache__",
            "bin",
            "tmp",
            "usr",
            "downloads",
        }

        keep_names: Set[str] = {
            "-VAULT-",
            "WORMHOLE",
            "storage",
            "bin",
        }

        move_candidates: List[Tuple[str, str]] = []
        keep_candidates: List[str] = []
        review_candidates: List[str] = []

        for entry in safe_read_dir(home):
            if STOP:
                return 130

            name = entry.name

            if name in protected_names or name.startswith("."):
                keep_candidates.append(name)
                continue

            if entry.resolve() == wormhole.resolve():
                keep_candidates.append(name)
                continue

            destination = wormhole / name

            if name in keep_names:
                keep_candidates.append(name)
                continue

            if destination.exists():
                review_candidates.append(
                    f"{name} -> CONFLICT: destination already exists at {destination}"
                )
                continue

            move_candidates.append((name, str(destination)))

        lines: List[str] = []
        lines.append("WORMHOLE RELOCATION PLAN")
        lines.append(f"HOME={home}")
        lines.append(f"WORMHOLE={wormhole}")
        lines.append(f"VAULT={vault}")
        lines.append("")
        lines.append("CANONICAL POLICY")
        lines.append("- WORMHOLE is the canonical root for projects and durable content.")
        lines.append("- -VAULT- is reserved for keys, secrets, and protected materials only.")
        lines.append("- BRAIN-HOLE and BRAIN-FOOD are deprecated and should not be recreated.")
        lines.append("")

        lines.append("KEEP IN HOME")
        if keep_candidates:
            for item in sorted(set(keep_candidates), key=str.lower):
                lines.append(f"KEEP {item}")
        else:
            lines.append("KEEP <none>")
        lines.append("")

        lines.append("MOVE INTO WORMHOLE")
        if move_candidates:
            for src_name, dst in move_candidates:
                lines.append(f"MOVE {home / src_name} -> {dst}")
        else:
            lines.append("MOVE <none>")
        lines.append("")

        lines.append("REVIEW MANUALLY")
        if review_candidates:
            for item in review_candidates:
                lines.append(f"REVIEW {item}")
        else:
            lines.append("REVIEW <none>")
        lines.append("")
        lines.append("NOTE")
        lines.append("This plan is non-destructive. No files were moved by this script.")

        plan_file.write_text("
".join(lines) + "
", encoding="utf-8")
        print(f"PLAN_WRITTEN {plan_file}")
        return 0
    except Exception as e:
        sys.stderr.write(f"FATAL: {e}
")
        return 99

if __name__ == "__main__":
    raise SystemExit(main())
EOF

chmod +x "${RUNNER}"
python3 "${RUNNER}"
#!/usr/bin/env bash
set -euo pipefail
trap 'rc=$?; printf "FATAL: command failed with exit %s
" "$rc" >&2' ERR INT TERM
command -v python3 >/dev/null 2>&1 || pkg install -y python >/dev/null 2>&1
TARGET_DIR="${HOME}/WORMHOLE"
VAULT_DIR="${TARGET_DIR}/-VAULT-"
PLAN_DIR="${HOME}/.termux_cleanup"
RUNNER="${PLAN_DIR}/wormhole_relocator.py"
mkdir -p "${TARGET_DIR}" "${VAULT_DIR}" "${PLAN_DIR}"
cat << 'EOF' > "${RUNNER}"
#!/usr/bin/env python3
import signal
import sys
from pathlib import Path

STOP = False

def handle_signal(signum, _frame):
    global STOP
    STOP = True
    sys.stderr.write("FATAL: received signal %s
" % signum)
    raise SystemExit(130)

def safe_listdir(path):
    try:
        return sorted(path.iterdir(), key=lambda p: p.name.lower())
    except Exception as e:
        sys.stderr.write("FATAL: unable to read directory %s: %s
" % (path, e))
        raise SystemExit(1)

def main():
    try:
        signal.signal(signal.SIGINT, handle_signal)
        signal.signal(signal.SIGTERM, handle_signal)

        home = Path.home()
        wormhole = home / "WORMHOLE"
        vault = wormhole / "-VAULT-"
        plan_dir = home / ".termux_cleanup"
        plan_file = plan_dir / "wormhole_relocation_plan.txt"

        wormhole.mkdir(parents=True, exist_ok=True)
        vault.mkdir(parents=True, exist_ok=True)
        plan_dir.mkdir(parents=True, exist_ok=True)

        protected_names = {
            "WORMHOLE",
            "-VAULT-",
            "storage",
            ".termux",
            ".ssh",
            ".gnupg",
            ".config",
            ".cache",
            ".local",
            ".shortcuts",
            ".termux_cleanup",
            ".gitconfig",
            ".bashrc",
            ".zshrc",
            ".profile",
            ".bash_profile",
            ".bash_history",
            ".zsh_history",
            ".python_history",
            ".vimrc",
            ".git-credentials",
            ".lesshst",
            ".wget-hsts",
            "__pycache__",
            "bin",
            "tmp",
            "usr",
            "downloads",
        }

        move_candidates = []
        keep_candidates = []
        review_candidates = []

        for entry in safe_listdir(home):
            if STOP:
                return 130

            name = entry.name

            if name in protected_names or name.startswith("."):
                keep_candidates.append(name)
                continue

            try:
                if entry.resolve() == wormhole.resolve():
                    keep_candidates.append(name)
                    continue
            except Exception:
                pass

            destination = wormhole / name

            if destination.exists():
                review_candidates.append("%s -> CONFLICT: destination already exists at %s" % (name, destination))
                continue

            move_candidates.append((str(entry), str(destination)))

        lines = []
        lines.append("WORMHOLE RELOCATION PLAN")
        lines.append("HOME=%s" % home)
        lines.append("WORMHOLE=%s" % wormhole)
        lines.append("VAULT=%s" % vault)
        lines.append("")
        lines.append("CANONICAL POLICY")
        lines.append("- WORMHOLE is the canonical root for projects and durable content.")
        lines.append("- -VAULT- is reserved for keys, secrets, and protected materials only.")
        lines.append("- BRAIN-HOLE and BRAIN-FOOD are deprecated and must not be recreated.")
        lines.append("")
        lines.append("KEEP IN HOME")
        if keep_candidates:
            for item in sorted(set(keep_candidates), key=str.lower):
                lines.append("KEEP %s" % item)
        else:
            lines.append("KEEP <none>")
        lines.append("")
        lines.append("MOVE INTO WORMHOLE")
        if move_candidates:
            for src, dst in move_candidates:
                lines.append("MOVE %s -> %s" % (src, dst))
        else:
            lines.append("MOVE <none>")
        lines.append("")
        lines.append("REVIEW MANUALLY")
        if review_candidates:
            for item in review_candidates:
                lines.append("REVIEW %s" % item)
        else:
            lines.append("REVIEW <none>")
        lines.append("")
        lines.append("NOTE")
        lines.append("This plan is non-destructive. No files were moved by this script.")

        plan_file.write_text("
".join(lines) + "
", encoding="utf-8")
        sys.stdout.write("PLAN_WRITTEN %s
" % plan_file)
        return 0
    except Exception as e:
        sys.stderr.write("FATAL: %s
" % e)
        return 99

if __name__ == "__main__":
    raise SystemExit(main())
EOF

chmod +x "${RUNNER}"
python3 "${RUNNER}"
#!/usr/bin/env bash
set -euo pipefail
command -v python3 >/dev/null 2>&1 || pkg install -y python
mkdir -p "$HOME/.termux_cleanup" "$HOME/WORMHOLE" "$HOME/WORMHOLE/-VAULT-"
cat << 'EOF' > "$HOME/.termux_cleanup/wormhole_relocator.py"
#!/usr/bin/env python3
import os
from pathlib import Path

home = Path.home()
wormhole = home / "WORMHOLE"
plan_file = home / ".termux_cleanup" / "wormhole_relocation_plan.txt"

protected = {
    "WORMHOLE", "-VAULT-", "storage", "bin", "usr", "tmp", "downloads",
    ".termux", ".ssh", ".gnupg", ".config", ".cache", ".local", ".shortcuts",
    ".termux_cleanup", ".bashrc", ".profile", ".bash_history", ".zshrc",
    ".zsh_history", ".gitconfig", ".python_history", ".vimrc", "__pycache__"
}

keep = []
move = []
review = []

for entry in sorted(home.iterdir(), key=lambda p: p.name.lower()):
    name = entry.name
    if name.startswith(".") or name in protected:
        keep.append(name)
        continue
    dest = wormhole / name
    if dest.exists():
        review.append(f"{entry} -> {dest} (destination exists)")
    else:
        move.append(f"{entry} -> {dest}")

lines = []
lines.append("WORMHOLE RELOCATION PLAN")
lines.append(f"HOME={home}")
lines.append(f"WORMHOLE={wormhole}")
lines.append(f"VAULT={wormhole / '-VAULT-'}")
lines.append("")
lines.append("POLICY")
lines.append("WORMHOLE is canonical root.")
lines.append("-VAULT- is only for secrets.")
lines.append("BRAIN-HOLE and BRAIN-FOOD are deprecated.")
lines.append("")
lines.append("KEEP")
lines.extend(keep or ["<none>"])
lines.append("")
lines.append("MOVE")
lines.extend(move or ["<none>"])
lines.append("")
lines.append("REVIEW")
lines.extend(review or ["<none>"])
lines.append("")
lines.append("NOTE")
lines.append("No files were moved.")

plan_file.write_text("
".join(lines) + "
", encoding="utf-8")
print(plan_file)
EOF

chmod +x "$HOME/.termux_cleanup/wormhole_relocator.py"
python3 "$HOME/.termux_cleanup/wormhole_relocator.py"
#!/usr/bin/env bash
set -euo pipefail
trap 'rc=$?; printf "FATAL: command failed with exit %s
" "$rc" >&2' ERR INT TERM
command -v python3 >/dev/null 2>&1 || pkg install -y python >/dev/null 2>&1
HOME_ROOT="${HOME}"
WORMHOLE_ROOT="${HOME_ROOT}/WORMHOLE"
ZELDA_SOURCE="${HOME_ROOT}/ZELDA-123"
ZELDA_TARGET="${WORMHOLE_ROOT}/ZELDA-123"
PLAN_DIR="${WORMHOLE_ROOT}/SYSTEM"
PLAN_FILE="${PLAN_DIR}/HOME_CONTAINMENT_PLAN.txt"
MIGRATOR="${PLAN_DIR}/home_containment_plan.py"
mkdir -p "${WORMHOLE_ROOT}" "${PLAN_DIR}"
cat << 'EOF' > "${MIGRATOR}"
#!/usr/bin/env python3
import sys
from pathlib import Path

def main() -> int:
    try:
        home = Path.home()
        wormhole = home / "WORMHOLE"
        report = wormhole / "SYSTEM" / "HOME_CONTAINMENT_PLAN.txt"

        protected = {
            "WORMHOLE",
            "storage",
            ".termux",
            ".ssh",
            ".gnupg",
            ".config",
            ".cache",
            ".local",
            ".shortcuts",
            ".bashrc",
            ".profile",
            ".bash_profile",
            ".bash_history",
            ".zshrc",
            ".zsh_history",
            ".gitconfig",
            ".python_history",
            ".vimrc",
            ".lesshst",
            ".wget-hsts",
            "bin",
            "tmp",
            "usr",
            "__pycache__",
        }

        lines = [
            "CANONICAL CONTAINMENT POLICY",
            "WORMHOLE is the only project root.",
            "WORMHOLE/-VAULT- is reserved exclusively for keys and secrets.",
            "ZELDA-123 and every project belong directly under WORMHOLE.",
            "BRAIN-HOLE and BRAIN-FOOD are deprecated and must not be recreated.",
            "",
            "NO FILES WERE MOVED.",
            "",
            "HOME ENTRIES OUTSIDE WORMHOLE",
        ]

        for entry in sorted(home.iterdir(), key=lambda item: item.name.lower()):
            if entry.name in protected or entry.name.startswith("."):
                continue
            if entry.resolve() == wormhole.resolve():
                continue
            target = wormhole / entry.name
            status = "CONFLICT" if target.exists() else "MOVE"
            lines.append(f"{status}: {entry} -> {target}")

        report.write_text("
".join(lines) + "
", encoding="utf-8")
        print(report)
        return 0
    except Exception as error:
        sys.stderr.write(f"FATAL: {error}
")
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
EOF

chmod +x "${MIGRATOR}"
python3 "${MIGRATOR}"
