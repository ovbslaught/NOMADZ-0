# NOMADZ Master Assembly — ToK/NMS/Metroid Stack

Goal: closest thing to Tears of the Kingdom + No Man's Sky + Metroid
that can actually ship from what we own. Verdict: we are ~80% of a
vertical slice already. This maps every layer to the closest prebuilt.

## Layer 1 — Zelda/TotK movement (climb, glide, physics-mashup)

Closest prebuilt: **GOAT (Godot Open Adventure Template)** —
https://github.com/miskatonicstudio/goat — open-world adventure
template with items, dialogue, inventory, quests, save.

Already on Drive (no download needed):
- climbing/wallrun: wallrun_state_script.gd (4 copies — pick newest)
- gliding: traversal_controller.gd FLY mode is your paraglider already
- dash_state_script.gd — dash state machine
- two_joysticks.gd — mobile controls
- zelda_engine.gd — top-down/Metroid template
- limb IK / wigglebone addon — already in project (TotK-style attachments)

Gaps to fill: stamina wheel (30 lines), climb surface detect (raycast
normal check — graft to wallrun), paraglider cloth shader.

## Layer 2 — No Man's Sky (space, procedural planets, seamless land)

Closest prebuilt: **godot-procedural-space-generation** —
https://github.com/thetornadotitan/godot-procedural-space-generation —
space + procedural generation.
Planet LOD: **procedural-planet---chunked-lod** — ALREADY ON DRIVE.
Also already on Drive: PersistentWorldGenerator.gd,
SpaceInfiniteGeneration_PersistentWorldGenerator.gd, planet_db.gd,
planet_body.gd, HeightMapShape3D.py, chunk_mesh.py, terrain_3d addon,
DeepSpaceArena.tscn, spacecraft/, ship.gd.

Gaps to fill: planet->surface seamless transition (load zone — the
SceneSwitcher exists in limbo_state.tscn patterns), star map UI
(Minimap.gd reskin).

## Layer 3 — Metroid (gated exploration, power-ups, backtracking)

Closest prebuilt: **top-down-dungeon-sci-fi** asset pack (already on
Drive) + zelda_engine.gd + our own gate logic:
- gates: locked areas need ability X = a boolean + a door that checks
  it. SavePoint + QuestMemory handle the persistence.
- power-ups = UpgradeInventory.gd + Collectable.gd, already written.
- backtracking map = minimaps/ + GisNavHud.gd.

## Layer 4 — Voxel Norfolk city hub

fetch_norfolk_osm.py + osm_to_godot.gd (already committed). Norfolk
is the hub city; planets are the NMS layer; dungeons are Metroid.

## Assembly order (what to actually do)

1. Fork/download GOAT; strip its world, keep its systems (dialogue,
   quest, item, save skeletons). Port to Godot 4 if it lags a version.
2. Graft our traversal_controller.gd as the player. GOAT content +
   our movement + drive's wallrun/dash/climb.
3. procedural-planet---chunked-lod for one planet. One planet is
   enough for a slice. PersistentWorldGenerator streams the terrain.
4. Metroid gates in the planet's cave systems: dash gate, swim gate,
   blade gate, blink (Fritz) gate. Four abilities, four locks.
5. Norfolk hub, ship to orbit, land on planet. That's the loop:
   city -> space -> planet -> caves -> power-up -> return to city.

That is TotK movement + NMS scope + Metroid structure, assembled from
owned assets plus two free templates. Nothing here needs invented —
only wired.
