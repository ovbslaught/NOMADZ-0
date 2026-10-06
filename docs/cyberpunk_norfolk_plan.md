# Cyberpunk Norfolk — Real Geography, Voxel Skin, Launch Plan

Wizardom/Warlock methodology confirmed: the scripts already exist in the
Drive audit. This is assembly, not authorship.

## The pipeline (two files, one evening)

1. fetch_norfolk_osm.py (Termux or PC): pulls real Norfolk, VA from
   OpenStreetMap via Overpass — actual building footprints, street grid,
   the Elizabeth River, naval station zones. No API key. Output:
   norfolk_city.json (~30-90s).
2. osm_to_godot.gd (editor tool): voxelizes the footprints into
   MultiMesh box columns (8m voxels, chunky by design), lays roads as
   ribbons, water as emissive teal planes. Cyberpunk comes free: 35% of
   buildings get neon emission from an 8-color retro palette.
   Pixelated 32-bit look = low-res voxel + flat shading + CRT shader
   (already in shaders/crt).

## Why this works on the S23

MultiMesh = one draw call per building. Hundreds of buildings, still
mobile-cheap. Voxel skin over real footprints reads as "Norfolk" at
street level: the Waterside/Granby grid, the Berkley Bridge approach,
the river cutting it in half.

## Cherry-pick map (from the Drive audit — already written, already working)

- ProtonBlade.gd .............. the sword. Done.
- blaster ..................... top_down_shooter.gd / ShmupEnemy.gd logic, re-skinned 3D
- dash_state_script.gd ........ dashes (already a state machine — graft)
- wallrun_state_script.gd ...... wallrun exists. Graft onto city facades.
- CharacterSwim3D.gd + WaterArea3D.gd + OceanSurfaceMesh.gd .... the harbor is swimmable day one
- Hoverbike.tscn .............. hoverbike exists. Norfolk streets = bike lanes
- AllTerrainVehicle.gd ........ vehicle base, reskin as hover car
- CombatManager.gd ............ damage pipeline exists
- UpgradeInventory.gd + Collectable.gd + CollectableManager.gd .... uridium economy exists
- health.gd / HealthBar3D.gd / HealthPickup.gd .... vitals exist
- two_joysticks.gd ............ mobile touch controls exist
- wave.gd + EnemySpawner.gd + EnemyDrone.gd .... enemy waves exist
- VultureEyeBoss.gd + BossRoom.gd + BossTransitionTrigger.gd .... a boss fight exists
- QuestMemory.gd + dialogue_message.gd ... story hooks exist
- SavePoint.gd + test_save_and_load.gd ... saving exists
- zelda_engine.gd ............. the whole top-down/Metroidvania template exists
- limbo_state.tscn / noe.tscn / maincity.tscn ... scene foundations exist

That is a full Mega Man / Metroid-style action game's worth of systems
sitting on Drive, already scripted.

## The game

NOMADZ operative in cyberpunk Norfolk: blade + blaster, dash/wallrun/
swim traversal, hoverbike across the Berkley Bridge, drones as street
enemies, VultureEyeBoss on a carrier deck, uridium economy in the
Waterside ruins. Real streets, neon skin.

## Launch order

1. Run fetch_norfolk_osm.py tonight. JSON lands in minutes.
2. Build the city in Godot editor, screenshot, commit ritual.
3. Graft traversal_controller.gd + dash_state_script + wallrun onto Player.tscn.
4. ProtonBlade + blaster + drone waves on the Granby strip.
5. Hoverbike loop across the bridge. Swim in the river. Boss on the deck.
6. Ship the vertical slice. Everything past that is more Norfolk.
