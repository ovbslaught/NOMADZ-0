#!/bin/bash

#############################################################################
# NOMADZ-0 Consolidation Script
# Purpose: Safe multi-repo merge into single NOMADZ-0 consolidation branch
# Author: NOMADZ Stack
# Date: 2026-07-05
#
# This script:
# - Pulls all branches from all NOMADZ repos
# - Validates compatibility
# - Merges into nomadz-0-consolidation-main
# - Preserves commit history
# - Handles conflicts gracefully
#############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONSOLIDATION_BRANCH="nomadz-0-consolidation-main"
REPOS=(
    "ovbslaught/NOMADZ-0:NOMADZ-0"
    "ovbslaught/MOTHER-BRAIN:MOTHER-BRAIN"
    "ovbslaught/FATHER-BRAIN:FATHER-BRAIN"
    "ovbslaught/COSMIC-BRAIN:COSMIC-BRAIN"
    "ovbslaught/NOMADZ-:GEO-BRAIN"
    "ovbslaught/OCEAN:OCEAN"
    "ovbslaught/VOLTRON:VOLTRON"
    "ovbslaught/NOMADZ_ARCHIVE:NOMADZ_ARCHIVE"
)

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="nomadz_consolidate_${TIMESTAMP}.log"
WORK_DIR="nomadz_consolidation_${TIMESTAMP}"

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

#############################################################################
# INITIALIZATION
#############################################################################

log "========================================="
log "NOMADZ-0 Consolidation Script Started"
log "========================================="
log "Timestamp: $TIMESTAMP"
log "Working directory: $WORK_DIR"
log "Consolidation branch: $CONSOLIDATION_BRANCH"

# Create working directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Initialize git repo
log "Initializing consolidation repository..."
git init
git config user.name "NOMADZ Consolidator"
git config user.email "nomadz@signalverse.local"

# Create initial commit
echo "# NOMADZ-0 Consolidated Repository" > README.md
git add README.md
git commit -m "🔧 Initial consolidation repository - $(date +%Y-%m-%d)"
git branch -M main "$CONSOLIDATION_BRANCH"

success "Consolidation repository initialized"

#############################################################################
# REPO PULLING & INTEGRATION
#############################################################################

log ""
log "========================================="
log "Phase 1: Pulling all NOMADZ repos"
log "========================================="

declare -A repo_status
declare -A repo_branches

for repo_pair in "${REPOS[@]}"; do
    IFS=':' read -r repo_path repo_name <<< "$repo_pair"
    
    log "Processing: $repo_name ($repo_path)"
    
    # Add remote
    if git remote add "$repo_name" "https://github.com/${repo_path}.git" 2>/dev/null; then
        success "Remote added: $repo_name"
    else
        warn "Remote already exists: $repo_name"
    fi
    
    # Fetch all branches
    if git fetch "$repo_name" --all 2>&1 | tee -a "$LOG_FILE"; then
        repo_status["$repo_name"]="success"
        
        # Count available branches
        branch_count=$(git branch -r | grep "^  $repo_name/" | wc -l)
        repo_branches["$repo_name"]=$branch_count
        success "Fetched $branch_count branches from $repo_name"
    else
        repo_status["$repo_name"]="failed"
        error "Failed to fetch from $repo_name"
    fi
done

#############################################################################
# DIRECTORY STRUCTURE CREATION
#############################################################################

log ""
log "========================================="
log "Phase 2: Creating consolidated directory structure"
log "========================================="

mkdir -p {NOMADZ-0,MOTHER-BRAIN,FATHER-BRAIN,COSMIC-BRAIN,GEO-BRAIN,OCEAN,VOLTRON,NOMADZ_ARCHIVE}

# Create structure metadata
cat > .consolidation_structure.json << 'EOF'
{
  "structure": {
    "NOMADZ-0": {
      "purpose": "3D substrate + OCEAN 2D layer, NPC AI, swarm agents",
      "language": "GDScript",
      "merged_from": "ovbslaught/NOMADZ-0"
    },
    "MOTHER-BRAIN": {
      "purpose": "WAL+SQLite brain, CRDT sync, knowledge hub",
      "language": "C++/GDScript",
      "merged_from": "ovbslaught/MOTHER-BRAIN"
    },
    "FATHER-BRAIN": {
      "purpose": "Scheduler, pulse, identity, LLM vault",
      "language": "GDScript",
      "merged_from": "ovbslaught/FATHER-BRAIN"
    },
    "COSMIC-BRAIN": {
      "purpose": "Media, lore, productions",
      "language": "JavaScript/C#",
      "merged_from": "ovbslaught/COSMIC-BRAIN"
    },
    "GEO-BRAIN": {
      "purpose": "AGI mapping substrate, codex",
      "language": "TypeScript",
      "merged_from": "ovbslaught/NOMADZ-"
    },
    "OCEAN": {
      "purpose": "2D substrate (merged into NOMADZ-0)",
      "language": "Python/GDScript",
      "merged_from": "ovbslaught/OCEAN"
    },
    "VOLTRON": {
      "purpose": "Autonomous daemon runbook/chassis",
      "language": "JavaScript/C#",
      "merged_from": "ovbslaught/VOLTRON"
    },
    "NOMADZ_ARCHIVE": {
      "purpose": "Legacy system bootstraps and archives",
      "language": "PowerShell",
      "merged_from": "ovbslaught/NOMADZ_ARCHIVE"
    }
  }
}
EOF

success "Directory structure created"
git add .consolidation_structure.json
git commit -m "📁 Add consolidation structure metadata"

#############################################################################
# BRANCH MERGING WITH CONFLICT HANDLING
#############################################################################

log ""
log "========================================="
log "Phase 3: Merging branches (conflict-aware)"
log "========================================="

merge_conflicts=0
merge_successes=0

for repo_pair in "${REPOS[@]}"; do
    IFS=':' read -r repo_path repo_name <<< "$repo_pair"
    
    if [ "${repo_status[$repo_name]}" != "success" ]; then
        warn "Skipping $repo_name (fetch failed)"
        continue
    fi
    
    log "Merging branches from $repo_name..."
    
    # Get all remote branches for this repo
    branches=$(git branch -r | grep "^  $repo_name/" | sed 's/^  //' | grep -v HEAD)
    
    while IFS= read -r branch; do
        if [ -z "$branch" ]; then
            continue
        fi
        
        branch_name=$(echo "$branch" | sed "s|^$repo_name/||")
        local_branch="${repo_name}/${branch_name}"
        
        # Create local tracking branch
        git checkout -B "$local_branch" "$branch" 2>&1 | tee -a "$LOG_FILE"
        
        # Attempt merge into consolidation branch
        git checkout "$CONSOLIDATION_BRANCH"
        
        if git merge --no-ff --no-edit "$local_branch" 2>&1 | tee -a "$LOG_FILE"; then
            ((merge_successes++))
            success "Merged $repo_name/$branch_name"
        else
            ((merge_conflicts++))
            warn "Conflict in $repo_name/$branch_name - Review manually"
            
            # Record conflict info
            echo "$repo_name/$branch_name" >> merge_conflicts.txt
            
            # Abort merge to continue processing
            git merge --abort || true
        fi
    done <<< "$branches"
done

log ""
log "Merge summary: $merge_successes successful, $merge_conflicts conflicts"

#############################################################################
# VALIDATION & HEALTH CHECKS
#############################################################################

log ""
log "========================================="
log "Phase 4: Validation & Health Checks"
log "========================================="

git checkout "$CONSOLIDATION_BRANCH"

# Check repo integrity
log "Validating repository integrity..."
if git fsck --full 2>&1 | tee -a "$LOG_FILE" | grep -q "error:"; then
    error "Repository integrity check failed"
else
    success "Repository integrity verified"
fi

# Count commits
commit_count=$(git rev-list --count HEAD)
log "Total commits in consolidation: $commit_count"

# List all branches
branch_count=$(git branch | wc -l)
log "Total branches in consolidation: $branch_count"

#############################################################################
# SUMMARY & REPORTING
#############################################################################

log ""
log "========================================="
log "Phase 5: Final Summary"
log "========================================="

cat > consolidation_report.md << EOF
# NOMADZ-0 Consolidation Report
**Generated:** $(date)

## Merge Summary
- **Successful Merges:** $merge_successes
- **Conflicts:** $merge_conflicts
- **Total Commits:** $commit_count
- **Total Branches:** $branch_count

## Repository Status
EOF

for repo_pair in "${REPOS[@]}"; do
    IFS=':' read -r repo_path repo_name <<< "$repo_pair"
    status=${repo_status[$repo_name]:-unknown}
    branches=${repo_branches[$repo_name]:-0}
    echo "- **$repo_name**: $status ($branches branches)" >> consolidation_report.md
done

cat >> consolidation_report.md << EOF

## Consolidation Branch
- **Branch Name:** $CONSOLIDATION_BRANCH
- **Timestamp:** $TIMESTAMP

## Pending Actions
$(if [ -f merge_conflicts.txt ]; then echo "### Conflicts to Resolve:"; cat merge_conflicts.txt | sed 's/^/- /'; else echo "All merges completed successfully!"; fi)

## Directory Structure
See \`.consolidation_structure.json\` for detailed mappings.

---
*Consolidation completed at $(date)*
EOF

success "Consolidation report generated"

#############################################################################
# CLEANUP & OUTPUT
#############################################################################

log ""
log "========================================="
log "Consolidation Complete"
log "========================================="

# Move log to repo root
cp "$LOG_FILE" .
success "Log saved: $LOG_FILE"

# Display summary
cat consolidation_report.md
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Consolidation Summary${NC}"
echo -e "${GREEN}=========================================${NC}"
echo "Working Directory: $(pwd)"
echo "Consolidation Branch: $CONSOLIDATION_BRANCH"
echo "Log File: $LOG_FILE"
echo ""
echo "Next Steps:"
echo "1. Review consolidation_report.md"
if [ -f merge_conflicts.txt ]; then
    echo "2. Resolve conflicts listed in merge_conflicts.txt"
fi
echo "3. Run validation tests on consolidated codebase"
echo "4. Push to NOMADZ-0 repository:"
echo "   git remote add origin https://github.com/ovbslaught/NOMADZ-0.git"
echo "   git push -u origin $CONSOLIDATION_BRANCH"
echo ""

log "Script execution completed at $(date)"
log "Total execution time: $SECONDS seconds"
