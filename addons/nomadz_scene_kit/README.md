# NOMADZ Scene Kit

**Runtime-Switchable Environments for Godot 4.5/4.6**

## 🌌 Features

- **Two Environment Modes:**
  - **DEEP SPACE** - Dark void, stars, minimal ambient light
  - **OCEAN UNDERWATER** - Blue tint, volumetric fog, caustic lighting

- **Runtime Switching** - Toggle environments on-the-fly without reloading
- **Compatibility Renderer** - Optimized for GLES3 (mobile & low-spec hardware)
- **Auto-Toggle Mode** - Optional timer-based automatic switching

## 📦 Installation

1. Copy `addons/nomadz_scene_kit/` to your Godot project
2. Enable in **Project → Project Settings → Plugins**
3. Restart Godot editor

## 🚀 Usage

### Method 1: Add SceneSwitcher Node

```gdscript
# Add SceneSwitcher node to your scene
var switcher = SceneSwitcher.new()
add_child(switcher)

# Toggle between modes
switcher.toggle_mode()

# Or set specific mode
switcher.switch_mode(SceneSwitcher.Mode.OCEAN)
```

### Method 2: Configure via Inspector

1. Add **SceneSwitcher** node to your scene (under Node3D)
2. Set properties:
   - `start_mode`: SPACE or OCEAN
   - `auto_switch_time`: Seconds between auto-toggles (0 = disabled)

## 🎮 Example Scene Setup

```
Main
├── WorldEnvironment
├── DirectionalLight3D
├── Camera3D
└── SceneSwitcher  ← Add this!
```

## 🛠️ Technical Details

- **Engine**: Godot 4.5+ / 4.6+
- **Renderer**: Compatibility (GLES3)
- **Platform**: PC, Mobile, Web
- **License**: MIT

## 🌊 Environment Settings

### SPACE Mode
- Background: Sky/Stars
- Ambient: Dark blue (0.05, 0.05, 0.1)
- Light Energy: 0.8
- Fog: Disabled

### OCEAN Mode
- Background: Deep blue color
- Ambient: Cyan-blue (0.1, 0.3, 0.5)
- Light Energy: 0.5-0.6
- Volumetric Fog: Enabled (density 0.015)

## 📄 Files

- `plugin.cfg` - Plugin metadata
- `scene_kit.gd` - EditorPlugin implementation
- `scene_switcher.gd` - Runtime switcher node

---

**Created by VULTURE:INC | Part of the NOMADZ-0 ecosystem**
