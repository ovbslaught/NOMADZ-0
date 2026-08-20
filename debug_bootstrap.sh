#!/bin/bash
set -e

LOG_FILE="$HOME/bootstrap_crash.log"
echo "--- SYSTEM BOOTSTRAP START: $(date) ---" > "$LOG_FILE"

log_step() {
    echo ">> $1" | tee -a "$LOG_FILE"
}

trap 'log_step "FATAL ERROR ON LINE $LINENO"; exit 1' ERR

log_step "STAGE 1: DPKG State Resolution"
dpkg --configure -a >> "$LOG_FILE" 2>&1 || true

log_step "STAGE 2: Storage Permissions Check"
if [ ! -d "$HOME/storage" ]; then
    log_step "Requesting storage permissions..."
    yes y | termux-setup-storage || true
    sleep 3
else
    log_step "Storage link verified."
fi

log_step "STAGE 3: Package Core Initialization"
pkg clean -y >> "$LOG_FILE" 2>&1
apt update -y >> "$LOG_FILE" 2>&1
apt upgrade -y -o Dpkg::Options::="--force-confnew" >> "$LOG_FILE" 2>&1
apt install -y rclone python sqlite git wget jq >> "$LOG_FILE" 2>&1

log_step "STAGE 4: WORMHOLE Architecture Provisioning"
mkdir -p ~/WORMHOLE/-VAULT-
mkdir -p ~/WORMHOLE/-SKILLS-
mkdir -p ~/WORMHOLE/FATHER-BRAIN/FATHER-LIFE
mkdir -p ~/WORMHOLE/OMEGA-BRAIN/schemas
mkdir -p ~/WORMHOLE/OMEGA-BRAIN/scripts
mkdir -p ~/WORMHOLE/OMEGA-BRAIN/db
mkdir -p ~/WORMHOLE/VULTURE-BRAIN
mkdir -p ~/WORMHOLE/COSMIC-BRAIN
mkdir -p ~/WORMHOLE/GEO-BRAIN
mkdir -p ~/WORMHOLE/BRAIN-HOLE/BRAIN-FOOD

log_step "STAGE 5: Rclone Authentication Validation"
if ! rclone listremotes | grep -q "^gdrive:$"; then
    log_step "HALT: rclone 'gdrive' missing due to Termux reinstall."
    log_step "ACTION: Execute 'rclone config' manually, create remote 'gdrive', authenticate, then re-run ~/debug_bootstrap.sh"
    exit 0
fi

log_step "STAGE 6: OOM-Safe Cloud Sync Pipeline"
rclone sync gdrive:WORMHOLE ~/WORMHOLE \
    --progress \
    --drive-acknowledge-abuse \
    --transfers 1 \
    --checkers 2 \
    --use-mmap=false \
    --buffer-size 16M \
    >> "$LOG_FILE" 2>&1

log_step "STAGE 7: SQLite DB WAL Enforcement"
if [ -f ~/WORMHOLE/OMEGA-BRAIN/db/omega_memory.db ]; then
    sqlite3 ~/WORMHOLE/OMEGA-BRAIN/db/omega_memory.db "PRAGMA journal_mode=WAL;" >> "$LOG_FILE" 2>&1
fi

log_step "BOOTSTRAP SEQUENCE COMPLETE."
