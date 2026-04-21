# 🌌 NOMADZ-0

> **Godot 4 3D open-world simulation & AI agent sandbox**
> Procedural terrain, NPC cognition, colony mechanics, and ML training pipeline for the **Signalverse universe**.

[![GDScript](https://img.shields.io/badge/GDScript-Godot_4.5%2F4.6-blue?logo=godot-engine)](https://godotengine.org)
[![Branch](https://img.shields.io/badge/default_branch-Cosmic--key-purple)](https://github.com/ovbslaught/NOMADZ-0/tree/Cosmic-key)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![BRAIN-DUMP](https://img.shields.io/badge/%F0%9F%A7%A0_MASTER_LOG-Issue_%232-orange)](https://github.com/ovbslaught/NOMADZ-0/issues/2)

---

## 🎯 What Is This

NOMADZ-0 is the runtime core of the **VULTURE:INC / Signalverse** multimedia project by Sol Xurator.

It combines:
- **Godot 4 game engine** — GLES3 Compatibility Renderer (Android/PC/Web ready)
- **AI agent systems** — NPC cognition, colony mechanics, procedural narrative
- **MOTHER-BRAIN** — Persistent AI memory (WAL SQLite + Chroma vectors)
- **ML training pipeline** — Data flows from gameplay into model training loops
- **Signalverse lore** — Interconnected sci-fi universe (Signal/Sigma/Prime timelines)

---

## 🌎 Environments (Runtime Switchable)

| Environment | Vessel | Trigger |
|-------------|--------|--------|
| 🚀 Deep Space | 6DOF Spaceship | Default / F1 |
| 🌊 Ocean Underwater | Submarine (buoyancy) | F1 toggle |

Swap at runtime with **F1** — environment, physics, shaders all switch live.

---

## 🗂️ Repo Structure

```
NOMADZ-0/
  .github/workflows/
    Cosmic-key         ← CI + voltron-sync (GitHub -> Drive Wormhole)
    nomadz-feeder.yml  ← Unified content feeder (every 4hrs)
    godot-ci.yml       ← Godot build CI
    voltron-sync.yml   ← VCN-1.6 TRI-BRIDGE SYNC to Google Drive
  00_Core/MB/          ← MOTHER-BRAIN core interface
  ConnectionStatePlugin/
  addons/
    nomadz_scene_kit/  ← NOMADZ Scene Kit addon (Space/Ocean switcher)
  data/                ← Runtime config (JSON), session data
  docs/
  logs/
  scripts/
    autoload/
      RetroArchBridge.gd  ← ROM scanner + launcher
      ConnectionStatePlugin.gd
  .vault/              ← MOTHER-BRAIN vault interface
```

---

## 🧠 VULTURE:INC Ecosystem

| Repo | Role | Status |
|------|------|--------|
| **[NOMADZ-0](https://github.com/ovbslaught/NOMADZ-0)** | Main game engine + AI sandbox | 🟡 Active |
| **[MOTHER-BRAIN](https://github.com/ovbslaught/MOTHER-BRAIN)** | Persistent AI memory/knowledge graph | 🟡 Active |
| **[Cosmic-key](https://github.com/ovbslaught/Cosmic-key)** | Multi-stack boilerplate template | 🟢 Template |
| **[omega-space-indexer](https://github.com/ovbslaught/omega-space-indexer)** | COSMOLOGOS snapshot + indexer | 🟡 Active |
| **[NOMADZ-0-WIKI](https://github.com/ovbslaught/NOMADZ-0-WIKI)** | Signalverse lore wiki | 🟡 Active |
| **[NOMADZ_ARCHIVE](https://github.com/ovbslaught/NOMADZ_ARCHIVE)** | Legacy automation + daemons | 📦 Archive |

---

## 🚀 Quick Start (Godot 4.5/4.6)

```bash
git clone https://github.com/ovbslaught/NOMADZ-0.git
cd NOMADZ-0
git checkout Cosmic-key
```

1. Open in **Godot 4.5+** (Compatibility Renderer)
2. Enable plugin: **Project > Project Settings > Plugins > NOMADZ Scene Kit**
3. Add Input Map actions: `thrust_fwd`, `thrust_back`, `strafe_left`, `strafe_right`, `rise`, `sink`, `yaw_left`, `yaw_right`, `pitch_up`, `pitch_down`, `roll_left`, `roll_right`
4. Click **⚡ Build Main Scene** in the NOMADZ dock
5. Set `NomadzMainScene.tscn` as Main Scene
6. Run — press **F1** to toggle Space ↔ Ocean

---

## 🛠️ GitHub Secrets Required

For the Wormhole sync (GitHub → Google Drive) to work:

| Secret | Value |
|--------|-------|
| `GDRIVE_SERVICE_ACCOUNT_JSON` | Google Service Account JSON key |
| `GDRIVE_FOLDER_ID` | Target Google Drive folder ID |

Drive path: `ROOT/Wormhole/MOTHER-BRAIN/MOTHER-BRAIN-MASTER-RECORD`

---

## 💬 AI Thread Sources

All plans, scripts, and lore are being consolidated from:
- **Perplexity** (this session + prior sessions)
- **Google AI Studio / Gemini** (Tesla Vault, Geologos, Nomadz Showrunner threads)
- **Claude** (MOTHER-BRAIN architecture)
- **Grok** (Signalverse lore + VULTURE:INC branding)

All recovered content logged in: **[🧠 Issue #2 — MASTER BRAIN-DUMP](https://github.com/ovbslaught/NOMADZ-0/issues/2)**

---

## 🌌 Signalverse Lore

**The Factions:**
- **The Nomadz** — Interstellar militia protecting reality
- **Xurator & The Vultures** — Antagonists. Xurator (corrupted) rules the Shadow Realm
- **Classes:** Orange (Pilots), White (Paladins), Black (Stealth/Hunters)

**The Realms:**
- **Signalverse** — Chaos | **Gravity Elseworld** — Order | **The Worldline** — Wormhole railway

**The Tech:** The Cosmic Key — core artifact powering transit between realms

---

*VULTURE:INC | Sol Xurator (ovbslaught) | Last updated: Apr 21 2026*
*Automated by Comet/Perplexity browser agent*
