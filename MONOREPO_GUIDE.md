# NOMADZ-0 Unified Monorepo Guide

## Overview

NOMADZ-0 is now a **unified monorepo** containing all game engine, infrastructure, and asset code in one repository.

## Structure

```
NOMADZ-0/
├── OCEAN/                    # Main Godot 4 game
│   ├── project.godot
│   ├── GameModeManager.tscn  # Main scene selector
│   ├── OCEAN/                # 2D game layer
│   └── autoloads/            # Singleton managers
│
├── MOTHER-BRAIN/             # Knowledge & automation
│   ├── scripts/              # Python orchestration
│   ├── .github/workflows/    # GitHub Actions
│   ├── MOTHER-BRAIN/         # Knowledge vault
│   └── wormhole-sync/        # Aggregated data
│
├── Cosmic-key/               # Models, worlds, lore
│   ├── COSMIC_KEY_*.cs       # World management
│   ├── WORLD_LINE_*.cs       # Timeline tools
│   ├── scenes/               # Asset scenes
│   └── assets/               # 3D models, textures
│
├── NOMADZ-0-WIKI/            # Documentation
│   └── *.md                  # Lore & guides
│
├── remotely-save/            # Sync utilities
│   └── src/                  # Sync implementations
│
├── scripts/                  # Root utilities
│   ├── consolidate-monorepo.sh
│   ├── run_nomadz.sh
│   └── sync-all.sh
│
└── README.md                 # This repo's main guide
```

## Quick Commands

### Launch Game
```bash
godot --path OCEAN
```

### Setup Infrastructure
```bash
cd MOTHER-BRAIN
python setup.py
```

### Sync All Sub-Projects
```bash
bash scripts/consolidate-monorepo.sh
```

### Check Git Status
```bash
git status
git log --oneline --all --graph
```

## Workflows

### Adding New Features

1. Create feature branch
   ```bash
   git checkout -b feature/my-feature
   ```

2. Work in the relevant sub-project (OCEAN, MOTHER-BRAIN, Cosmic-key, etc.)

3. Commit with clear messages
   ```bash
   git add .
   git commit -m "feat(ocean): add new player ability"
   ```

4. Push and create PR
   ```bash
   git push -u origin feature/my-feature
   ```

### Syncing with Google Drive

1. Add GitHub Secrets to MOTHER-BRAIN:
   - `GDRIVE_SERVICE_ACCOUNT` (service account JSON)
   - `GDRIVE_ROOT_FOLDER_ID` (your Drive folder ID)

2. Trigger sync manually or on schedule:
   - Manual: Actions → MOTHER-BRAIN gdrive-sync → Run workflow
   - Scheduled: Runs every 6 hours

3. Models/assets sync to `wormhole-sync/`

## Sub-Project Details

### OCEAN (Game)
- **Language:** GDScript
- **Engine:** Godot 4.6
- **Entry:** `GameModeManager.tscn`
- **Modes:** Zelda-like, Metroidvania, SHMUP

### MOTHER-BRAIN (Infrastructure)
- **Language:** Python
- **Purpose:** Knowledge base, automation, sync
- **Key Scripts:** data_sync.py, orchestration_agent.py
- **Deployment:** Docker Compose

### Cosmic-key (Assets & Tools)
- **Languages:** C#, GDScript
- **Purpose:** World data, character lore, dashboards
- **Key Files:** COSMIC_KEY_*.cs, WORLD_LINE_*.cs

## File Size & Performance

**Total Monorepo Size:** ~675 MB (after consolidation)

**Large Files:**
- Cosmic-key: ~100 MB (World Maker tools, images)
- OCEAN: ~200 MB (Godot project assets)
- MOTHER-BRAIN: ~300 MB (knowledge vault, workflows)

**Recommendation:** Use Git LFS for files > 50 MB if repo grows:
```bash
git lfs install
git lfs track "*.zip" "*.blend" "*.glb"
```

## Troubleshooting

### "Permission Denied" on push
```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
git push --set-upstream origin branch-name
```

### Merge conflicts in sub-projects
```bash
git status  # See conflicts
# Edit conflicted files
git add .
git commit -m "resolve: merge conflicts"
```

### Godot project not loading
```bash
cd OCEAN
godot --path . --editor
```

## Contributing

1. Follow branch naming: `feature/`, `bugfix/`, `chore/`
2. Write clear commit messages
3. Test changes locally before pushing
4. Create PR with description
5. Request review from maintainers

## Resources

- **Main README:** `README.md`
- **Game Dev:** `OCEAN/README.md`
- **Infrastructure:** `MOTHER-BRAIN/README.md`
- **Lore:** `NOMADZ-0-WIKI/`
- **Consolidation Script:** `scripts/consolidate-monorepo.sh`

---

**Status:** Unified Monorepo ✅
**Last Updated:** 2026-07-01
