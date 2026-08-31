# Missing Dependencies

`project.godot` did not exist anywhere in the source files — it's newly
generated (see root).

## Resolved this pass — NOMADZ Player + abilities now have real scenes
- `Player.tscn` — CharacterBody2D wired to every node `Player.gd` needs,
  with `EchoShield`, `WormholeTether`, and `PlayerShaderController`
  nested as documented ("attach as child of Player"). Timer nodes are
  intentionally omitted — `Player.gd`/`EchoShield.gd`/`WormholeTether.gd`
  all self-create their own Timers with correct wait_time/one_shot via
  `_ensure_timer()`, so this is relying on that, not a gap.
- `SigmaBomb.tscn`, `Projectile.tscn`, `SignalPulseArea.tscn` — standalone
  spawned-entity scenes, each with the CollisionShape2D the script needs
  but never creates itself.
- `pickups/*.tscn` — all 5 (AbilityPickup, CosmicKeyFragment, HealthPickup,
  LoreNode, SavePoint).
- `player_glow.gdshader` + `bleed_distortion.gdshader` — written fresh.
  `PlayerShaderController.gd` and `BleedDistortionController.gd` called
  `set_shader_parameter()` on shaders that never existed anywhere in the
  source; these declare every uniform both controllers set.
- `BleedDistortionController.tscn` — drop-in full-screen ColorRect +
  shader material, ready to add to a HUD scene.
- `Main.gd` `PLAYER_SCENE` constant repointed to the real `Player.tscn`
  path (was `res://player/Player.tscn`, which never existed).
- Sprite art is still placeholder-only (empty `SpriteFrames` animation
  tracks, no textures) — see `_art/placeholder.png`.

## Still missing — stubbed so the project parses, not implemented
`core/_stubs/`: `ControlSettings.gd`, `EraClock.gd`, `UpgradeInventory.gd`,
`QuestMemory.gd` — referenced by `save_service.gd` / `fps_controller.gd`,
real source never provided.

## Still missing — no scene files
- `Main.gd` `ROOM_REGISTRY` → 8 room scenes under `res://scenes/rooms/`,
  none exist. Also `res://scenes/Transition.tscn`.
- **3d_camera_experiments**: `orbital_camera.gd`/`player.gd` pair and
  `CameraTemplate.gd` — scripts only, zero `.tscn`. (Out of scope for
  this pass — say the word if you want these too.)

## Still missing — referenced assets/scenes that don't exist
- `2d_platformer/level_1.tscn` → `res://nodes/player.tscn`, 2 fonts, 2
  sprites, 2 icons, 1 audio file, plus autoload sound players
  `/root/CoinSfx`, `/root/JumpSfx`, `/root/DetSfx`
- **3d_fps_ocean_kit**: `MuzzleFlash.tscn`, `ImpactEffect.tscn`, audio
  under `res://Sounds/`, and the resource script classes `WeaponConfig`/
  `PlayerFeelConfig`/`CrosshairConfig`/`MeleeConfig` (only the `.tres`
  data instances exist, not the class scripts). `CameraScript.gd` needs
  a `PlayerCharacter` class + sibling `HUD` node, neither exists.
  `camera_3d.tscn` still points at a stale `res://OCEAN-MAIN/...` path.
- **3d_camera_experiments**: `follow_cam_3d.gd` expects a `follow_target`
  with an optional `strafe_toggled` signal / `guarding` property.

## Still missing — Input Map actions
Only `ProControllerManager.gd` self-registers its own action set on
`_ready()`. Everything else (`Left/Right/Up/Down`, `MouseRotateView`,
`RightStick*`, `Zoom*`, `walk_*`, `toggle_flashlight`, `lookup/down/
left/right`, `move_left/move_right`) still needs manual Input Map entries.

## Godot version
Godot 4.x syntax throughout. `project.godot` sets `config/features` to
`"4.3"` as a default — adjust if you're on a different 4.x minor.
