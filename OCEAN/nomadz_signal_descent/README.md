# NOMADZ: SIGNAL DESCENT
### A Metroidvania in the NOMADZ Universe
**Version:** 0.1.0-alpha | **Engine:** Godot 4.6 | **Renderer:** Compatibility (GLES3)  
**Studio:** VultureCode / VULTURE:INC | **Author:** Sol / SolXurator  
**Protocol:** ARCHON | **Status:** DEPLOY-READY (Alpha)

---

## ⬛ MISSION BRIEF

NORA — NOMADZ field agent — crash-lands in **VULTURE-SIGMA Station**.  
The **COSMIC KEY** is shattered. The **MOTHER BRAIN** link is offline.  
**Signalverse bleed** is rising. The station's creatures are waking.

Descend. Collect. Restore. Or be consumed by the bleed.

**Inspirations:**  
- *Metroid Fusion* — SA-X paranoia, ability gates, atmosphere  
- *Primal Planet* / *Jetpack* — precision jetpack feel  
- *Animal Well* — creature ambiguity, hidden lore, bioluminescence  
- *Wiley* — tightly scoped Metroidvania loop  
- **NOMADZ Universe** — ARCHON Protocol, COSMIC KEY, WORMHOLE, MOTHER BRAIN

---

## 📁 PROJECT STRUCTURE

```
nomadz_signal_descent/
├── project.godot               ← Godot 4.6 project config
├── autoloads/
│   ├── GameManager.gd          ← Core state: HP, fuel, abilities, save/load
│   ├── SignalverseManager.gd   ← Bleed events, corruption, phantom spawns
│   ├── LoreDatabase.gd         ← Full NOMADZ lore: 25 entries across 6 categories
│   └── AudioManager.gd         ← Dynamic music, SFX pool, whisper injection
├── player/
│   ├── Player.gd               ← NORA: jetpack, dash, morph, shoot, wall slide
│   ├── Projectile.gd           ← Signal shot projectile
│   └── SignalPulseArea.gd      ← Radial AOE: stuns drones, destroys phantoms
├── enemies/
│   ├── types/
│   │   ├── VultureDrone.gd     ← Triangle patrol, signal disruptor, 5-state AI
│   │   ├── SignalwormCrawler.gd ← Signalverse fauna; aggros on high signal output
│   │   └── BleedPhantom.gd     ← Loop-based Signalverse construct; find the gap
│   └── bosses/
│       └── VultureEyeBoss.gd   ← 3-phase boss: SWEEP → PURSUIT → OVERLOAD
├── world/
│   ├── RoomBase.gd             ← Base room: entry, atmosphere, camera, doors
│   ├── Door.gd                 ← Ability-locked transition door
│   └── CameraController.gd    ← Smooth follow, shake, zoom, bleed drift
├── collectibles/
│   ├── CosmicKeyFragment.gd    ← Fragment pickup: signal energy + lore
│   ├── AbilityPickup.gd        ← Ability unlock station
│   ├── LoreNode.gd             ← BRAIN-FOOD lore terminal
│   └── SavePoint.gd            ← MOTHER BRAIN sync terminal
├── ui/
│   ├── HUD.gd                  ← HP, fuel, signal meter, whispers, room name
│   ├── PauseMenu.gd            ← Pause, save, codex, settings, quit
│   ├── MapSystem.gd            ← Metroidvania grid map (press M)
│   └── DebugOverlay.gd         ← Backtick/` toggle debug HUD
├── shaders/
│   ├── bleed_distortion.gdshader   ← Full-screen: scanlines, CA, glitch, vignette
│   └── bioluminescent_glow.gdshader ← Organism glow: pulse, proximity, alert
├── effects/
│   └── BleedDistortionController.gd ← Wires SignalverseManager → shader params
└── scenes/
    ├── Main.gd                 ← Root: room transitions, player spawn, game loop
    ├── test_suite.gd           ← 40+ automated tests covering all systems
    └── rooms/                  ← [CREATE THESE IN GODOT EDITOR]
        ├── CrashSite.tscn
        ├── BoneShafts1.tscn
        ├── BoneShafts2.tscn
        ├── SignalRelay.tscn
        ├── LuminousSubstrate.tscn
        ├── VultureEyeAntechamber.tscn
        ├── VultureEyeBossRoom.tscn
        └── MotherBrainCore.tscn
```

---

## 🚀 QUICKSTART DEPLOY

### 1. Copy to Godot project
```bash
# Copy this directory into your Godot 4.6 project root
cp -r nomadz_signal_descent/ /path/to/your/godot_project/
```

### 2. Open in Godot 4.6
```
File → Open Project → select project.godot
```

### 3. Create scene nodes in Godot Editor

**Main.tscn** (Node root):
```
Main (Node) ← attach Main.gd
├── RoomRoot (Node2D)
├── PlayerRoot (Node2D)
├── HUD (CanvasLayer) ← attach HUD.gd
├── PauseMenu (CanvasLayer) ← attach PauseMenu.gd
├── DebugOverlay (CanvasLayer) ← attach DebugOverlay.gd
│   └── DebugLabel (RichTextLabel)
├── MapSystem (CanvasLayer) ← attach MapSystem.gd
└── TransitionLayer (CanvasLayer)
    └── FadeRect (ColorRect) ← full viewport, black

```

**Player.tscn** (CharacterBody2D):
```
Player (CharacterBody2D) ← attach Player.gd, groups: ["player"]
├── AnimatedSprite2D
├── CollisionShape2D        ← CapsuleShape2D, full height
├── MorphCollision          ← CollisionShape2D, crouch height, disabled by default
├── CoyoteTimer (Timer)
├── JumpBufferTimer (Timer)
├── DashTimer (Timer)
├── DashCooldownTimer (Timer)
├── ShootTimer (Timer)
├── PulseTimer (Timer)
├── InvincibilityTimer (Timer)
├── PlayerLight (PointLight2D)
├── JetpackParticles (GPUParticles2D)
├── DashParticles (GPUParticles2D)
├── ShootOrigin (Marker2D)
└── Camera2D ← attach CameraController.gd
```

**PostProcess.tscn** (CanvasLayer, layer=-1):
```
PostProcessLayer (CanvasLayer)
└── BleedRect (ColorRect) ← full viewport, attach BleedDistortionController.gd
    └── ShaderMaterial ← assign bleed_distortion.gdshader
```

### 4. Assign Autoloads (Project → Project Settings → Autoload)
```
GameManager     → res://autoloads/GameManager.gd       ✓ Enable
SignalverseManager → res://autoloads/SignalverseManager.gd ✓ Enable
LoreDatabase    → res://autoloads/LoreDatabase.gd      ✓ Enable
AudioManager    → res://autoloads/AudioManager.gd      ✓ Enable
```

### 5. Run Tests
```
Open scenes/test_suite.gd → Run Script (Godot toolbar)
All 40+ tests should report ✅ PASS
```

---

## 🎮 CONTROLS

| Action | Key | Controller |
|---|---|---|
| Move | A / D | Left Stick |
| Jump | Space | A / Cross |
| Jetpack (hold) | Space (hold, mid-air) | A (hold) |
| Dash | Shift / Z | B / Circle |
| Signal Pulse | E | Y / Triangle |
| Morph | S / Down Arrow | Down |
| Shoot | LMB / X | RT |
| Interact | F | X / Square |
| Map | M | Select |
| Pause | Escape | Start |
| Debug Overlay | ` (backtick) | — |

---

## 🧠 ABILITY UNLOCK SEQUENCE

```
Crash Site      → [default: walk, jump, shoot]
↓
BoneShafts1     → ARCHON DASH
↓
BoneShafts2     → OMEGA-COMPRESS (morph)
↓
SignalRelay     → SIGNAL PULSE
                → WORMHOLE TETHER (grapple)
↓
LuminousSubstrate → GRAVITY ELSEWORLD (double jump)
↓
VultureEye Ante  → ECHO SHIELD
↓
VultureEyeBoss   → [BOSS] → JETPACK BOOST
↓
MotherBrainCore  → SIGMA BOMB
                 → [WIN CONDITION]
```

---

## 🔧 SYSTEMS OVERVIEW

### GameManager
- HP / Fuel / Signal Meter tracking
- Ability registry (8 abilities)
- Save/load via `user://nomadz_save.json`
- Checkpoint system
- Fragment + lore tracking

### SignalverseManager
- **Corruption level**: rises over time, suppressed by signal meter
- **Bleed events** (auto-triggered): visual glitch, whispers, phantom spawn, screen tear, gravity pulse, lore flash
- **Corruption color**: tints atmosphere progressively
- **Phantom cap**: max 3 simultaneous phantoms

### LoreDatabase
- **25 entries** across 6 categories: TRANSMISSION, FIELD_LOG, CODEX, CREATURE, ENVIRONMENT, PHILOSOPHY
- All NOMADZ lore: COSMIC KEY, ARCHON Protocol, WORMHOLE, characters, creatures, sectors

### Player (NORA)
- **Jetpack**: fuel-based, boost ability multiplier, particle trail
- **Dash**: directional 8-way, invincibility window, ghost trail
- **Coyote time**: 0.12s grace window after leaving ground
- **Jump buffer**: 0.10s input window before landing
- **Wall slide + wall jump**
- **Morph**: ground-only, tight shaft traversal
- **Signal Pulse**: AOE, stuns drones, destroys phantoms
- **Invincibility frames**: 1.2s after hit, visual flash

### Bleed Distortion Shader
- Full-screen CRT: scanlines, chromatic aberration, vignette
- Signalverse glitch: horizontal band tears, vertical drift
- Corruption warping: UV distortion proportional to corruption level
- Edge darkening on heavy bleed events

---

## 🐛 DEBUG

### Debug Overlay (backtick `)
Shows live:
- FPS + frame count
- GameManager snapshot (HP, fuel, signal, room, abilities, fragments)
- SignalverseManager snapshot (corruption, next bleed, phantom count)
- Player snapshot (position, velocity, state flags)
- Lore discovery %

### DEBUG_MODE flags
Every major script has `const DEBUG_MODE := true/false`.  
Set all to `false` before release builds.

### Test Suite
```
# Run in Godot: open test_suite.gd → Run Script
# Expected: 40+ tests, 0 failures
```

---

## 🗺️ ROOM MAP LAYOUT

```
Col:  0    1    2    3    4    5    6    7    8    9    10   11
Row 0:                               [CRASH_SITE]
Row 1:
Row 2:                               [BONE_1]
Row 3:                          [BONE_2] [SIGNAL_RELAY]
Row 4:
Row 5:                               [LUMINOUS]
Row 6:
Row 7:                               [EYE_ANTE]
Row 8:                               [EYE_BOSS] ← BOSS
Row 9:                               [MB_CORE]  ← WIN
```

---

## 📋 DEPLOYMENT CHECKLIST (ARCHON Protocol)

- [ ] All autoloads assigned in Project Settings
- [ ] Main.tscn set as main scene in Project Settings
- [ ] Player.tscn created with all required child nodes
- [ ] All room .tscn files created in `scenes/rooms/`
- [ ] Audio assets placed in `audio/sfx/` and `audio/music/` (see AudioManager.gd for paths)
- [ ] Projectile.tscn created and assigned to VultureEyeBoss.projectile_scene
- [ ] PostProcess CanvasLayer added to Main.tscn with BleedDistortionController
- [ ] DEBUG_MODE set to false on all scripts for release
- [ ] test_suite.gd run: 0 failures
- [ ] Save/load tested: verify `user://nomadz_save.json` written correctly
- [ ] WORMHOLE backup: sync project to Google Drive via rclone

---

## 🔗 WORMHOLE SYNC (NOMADZ Protocol)

```bash
# From Termux (Android) — push to Google Drive
rclone sync ~/storage/shared/nomadz_signal_descent gdrive:WORMHOLE/VULTURE-BRAIN/nomadz_signal_descent --progress

# From PC — same command via Windows rclone
rclone sync G:\Projects\nomadz_signal_descent gdrive:WORMHOLE/VULTURE-BRAIN/nomadz_signal_descent --progress
```

---

## 🌐 NOMADZ UNIVERSE CANON

| Term | Definition |
|---|---|
| NORA | Player character — NOMADZ field agent deployed to SIGMA Station |
| COSMIC KEY | Resonance lock that suppresses Signalverse bleed; shattered into 7 fragments |
| MOTHER BRAIN | Central AI hub; offline; your mission is to restore her link |
| ARCHON Protocol | Operational standing order when MOTHER BRAIN is offline: full agent autonomy |
| SIGNALVERSE | The signal layer of reality; bleed-through = physics breaks, creatures manifest |
| WORMHOLE | NOMADZ cross-device sync backbone; also in-universe data conduit |
| VULTURE:INC | Contractor that built SIGMA Station on a bleed site; their drones still patrol |
| VULTURE-EYE | Final boss — security node fused with Signalverse matter; sees all layers |
| BRAIN-FOOD | Lore artifact / data packet; collected via LoreNode terminals |

---

**No hierarchy. No gatekeeping. Equal partnership.**  
*ARCHON Protocol — always active.*

```
NOMADZ: SIGNAL DESCENT
VultureCode / VULTURE:INC
Sol / SolXurator
Godot 4.6 | 2026
```
