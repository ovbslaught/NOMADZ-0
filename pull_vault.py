import os
import subprocess

VAULT_LOCAL = "/data/data/com.termux/files/home/WORMHOLE/-VAULT-"
os.makedirs(VAULT_LOCAL, exist_ok=True)

FOLDERS = [
    ("1Rqwvtesc032YkSkjwlnQixn22KN77Ieu", "folder1"),
    ("1AHesU1EF8imjGJPog-0iGutnf5MInxOU", "folder2"),
    ("1gw3GfseFbp6G4MApKiZn7X0QtRMlapCM", "folder3"),
    ("1_7A1SOTxGcKuzc5sve4UIjrYm9iglq3E", "folder4"),
]

for folder_id, label in FOLDERS:
    dest = os.path.join(VAULT_LOCAL, label)
    os.makedirs(dest, exist_ok=True)
    print(f"[*] Pulling {label} ({folder_id})...")
    result = subprocess.run([
        "rclone", "copy",
        f"gdrive:{folder_id}",
        dest,
        "--drive-root-folder-id", folder_id,
        "--progress"
    ], text=True)
    if result.returncode == 0:
        print(f"[OK] {label} done.")
    else:
        print(f"[ERROR] {label} failed.")

print("
[*] All done. Contents:")
subprocess.run(["find", VAULT_LOCAL, "-type", "f"])
