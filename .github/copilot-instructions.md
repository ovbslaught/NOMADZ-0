# NOMADZ-0 — OMEGA-1.0 Copilot Context

## Project
Godot 4.x GDScript simulation/game project. Branch: Cosmic-key.

## Architecture
-  — Autoload singleton, master state, GEOLOGOS pillar system, OMEGA versioning
-  — Procedural galaxy/world generation
-  — 26 GEOLOGOS pillars registry (liberation-weighted logic)
-  — HUD/UI for pillar state visualization
-  — Player character suit state machine
-  — Suit subsystem sensor logic
-  — HUD visor display layer
-  — Voxel world manipulation tool
-  — Warp/teleport system

## Key Concepts
- 26 GEOLOGOS Pillars: liberation-weighted logic gates
- Active pillars: 01_ORIGIN, 02_KINETIC, 03_EMPATHY
- Win-state: 26_LIBERATION (Currently Locked)
- VULTURE drone system integration (external via Droidhole sync)
- CortexCore is Godot Autoload — always available as CortexCore.*

## MCP Tools Available
- perplexity: web search for Godot docs, GDScript patterns
- github: repo operations
- filesystem: read/write workspace files

## Coding Style
- GDScript 4.x syntax (no old GD3 patterns)
- Use typed variables where possible
- Signal-driven architecture
- CortexCore.gd manages global state via master_data dict
