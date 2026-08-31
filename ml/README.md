# NOMADZ-0 ML-RL layer

## What's here
- `requirements.txt` / `train.py` — PPO training loop via `godot_rl_agents`,
  targeting `environments/2_5d_metroidvania/ai/AIController.gd`.

## What's still needed before `train.py` will actually run
1. Add the `GodotRLAgents` plugin to the Godot project (not included —
   `addons/godot_rl_agents/` from https://github.com/edbeeching/godot_rl_agents,
   drop into `addons/`, enable in Project Settings).
2. Instance `AIController.gd` as a child of `Player.tscn` (same pattern as
   `EchoShield`/`WormholeTether` — see MISSING_DEPENDENCIES.md).
3. Export a headless Linux build of the project for `--env_path`, or leave
   it unset and run the Godot editor directly for single-env debugging.

## Reward shaping (current AIController.gd)
Reads real, existing `GameManager` signals — no invented state:
- `+` on `cosmic_fragment_collected`
- `+` on `signal_meter_changed` (delta)
- `-` on `health_changed` (delta, i.e. damage taken)
- large `-` on `player_died`
- episode ends on `player_died` or `mother_brain_restored` broadcast
