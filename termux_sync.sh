#!/data/data/com.termux/files/usr/bin/bash
# NOMADZ-0 Termux Android Sync Script
# Run this in Termux on Android to sync with GitHub and Google Drive

echo "[TERMUX_SYNC] NOMADZ-0 Android Sync Starting..."
echo "[TERMUX_SYNC] Date: $(date)"

# Install dependencies
echo "\n[DEPS] Checking dependencies..."
for pkg in git python rclone rsync; do
    if ! command -v $pkg &> /dev/null; then
        echo "  Installing $pkg..."
        pkg install $pkg -y
    else
        echo "  ✓ $pkg installed"
    fi
done

# Setup directories
TERMUX_HOME="$HOME"
NOMADZ_DIR="$TERMUX_HOME/NOMADZ-0"
SHARED_STORAGE="$HOME/storage/shared/NOMADZ-0"

echo "\n[DIRS] Setting up directories..."
mkdir -p "$SHARED_STORAGE"
mkdir -p "$TERMUX_HOME/.config"

# Setup storage access
if [ ! -d "$HOME/storage/shared" ]; then
    echo "  Requesting storage permissions..."
    termux-setup-storage
    sleep 2
fi

# Clone or pull from GitHub
echo "\n[GIT] Syncing with GitHub..."
if [ ! -d "$NOMADZ_DIR" ]; then
    echo "  Cloning NOMADZ-0 repository..."
    cd "$TERMUX_HOME"
    git clone https://github.com/ovbslaught/NOMADZ-0.git
    cd "$NOMADZ_DIR"
    git checkout Cosmic-key
else
    echo "  Pulling latest from Cosmic-key branch..."
    cd "$NOMADZ_DIR"
    git fetch origin
    git pull origin Cosmic-key --rebase
fi

# Sync to shared storage for other apps
echo "\n[RSYNC] Syncing to shared storage..."
rsync -av --delete "$NOMADZ_DIR/" "$SHARED_STORAGE/" \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='__pycache__'

echo "  ✓ Synced to: $SHARED_STORAGE"

# Google Drive sync setup (requires manual configuration)
echo "\n[DRIVE] Google Drive Sync"
if command -v rclone &> /dev/null; then
    if [ ! -f "$HOME/.config/rclone/rclone.conf" ]; then
        echo "  ⚠ rclone not configured for Google Drive"
        echo "  Run: rclone config"
        echo "  Then: rclone sync drive:NOMADZ-0 $NOMADZ_DIR"
    else
        echo "  Syncing with Google Drive..."
        rclone sync drive:NOMADZ-0 "$NOMADZ_DIR" --progress
        echo "  ✓ Drive sync complete"
    fi
fi

# Generate sync report
REPORT_FILE="$NOMADZ_DIR/logs/termux_sync_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$NOMADZ_DIR/logs"

cat > "$REPORT_FILE" << REPORTEOF
NOMADZ-0 Termux Sync Report
===========================
Date: $(date)
Device: $(uname -a)
Termux Version: $(termux-info | grep -i version | head -1)

Directories:
- Termux: $NOMADZ_DIR
- Shared: $SHARED_STORAGE

Git Status:
$(cd $NOMADZ_DIR && git status --short)

File Counts:
- GDScript: $(find $NOMADZ_DIR -name '*.gd' | wc -l)
- Python: $(find $NOMADZ_DIR -name '*.py' | wc -l)
- Total Files: $(find $NOMADZ_DIR -type f | wc -l)

Disk Usage:
$(du -sh $NOMADZ_DIR)
REPORTEOF

echo "\n[REPORT] Sync report: $REPORT_FILE"
cat "$REPORT_FILE"

echo "\n[TERMUX_SYNC] ✅ Sync Complete!"
echo "Locations:"
echo "  - Termux: $NOMADZ_DIR"
echo "  - Shared: $SHARED_STORAGE"
echo "  - Logs: $REPORT_FILE"
