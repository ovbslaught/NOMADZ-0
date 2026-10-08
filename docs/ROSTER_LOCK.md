# ROSTER LOCK — FINAL — NO SUBSTITUTIONS

Brett's decree, 2026-10-08. This list is the cast. Nothing else gets
imported into the slice. Nothing else gets discussed.

## THE CAST (all files exist, all in PLAYER-1)

1. PLAYER — a rigged game-ready spaceman (Sol/Spiff). mercenary-astronaut
   or the stylized astronaut — whichever is rigged and game-ready in the
   folder. ONE body for the whole slice. Controller:
   traversal_controller.gd (committed). Board mount:
   board_flight_controller.gd (committed).

2. BOARD — extracted from the Silver Surfer model. Blender: import,
   select board faces, P -> Selection, export silver_board.glb.
   One-time, ten minutes. This is the Surfer-board flight, period.

3. FRITZ — the blue Surfer + fritz_glitch.gdshader (committed).
   Ability: fritz_blink.gd (committed). No new modeling. Shader on,
   blink wired, done.

4. ENEMY — SciFiDroid. EnemyDrone.gd + wave.gd logic (on Drive).

5. WEAPONS — ProtonBlade.gd (blade) + ModularWeapon system (blaster).
   Both written. CombatManager.gd (on Drive).

6. WORLD — fetch_norfolk_osm.py + osm_to_godot.gd (committed).
   Ocean View / Willoughby / Bay View bbox. Neon voxel city, collision,
   beach, swimmable Bay.

7. VEHICLE — Hoverbike.tscn (on Drive).

8. ECONOMY — Collectable.gd + UpgradeInventory.gd (on Drive).
   Uridium pickups.

9. BOSS — VultureEyeBoss.gd + BossRoom (on Drive).

10. AMBIENT — alien_fish_animated.glb in the Bay (on Drive).

## NON-NEGOTIABLES

- NO new assets. NO new models. NO templates. NO GOAT. NO planets.
- NO character swap menu. The spaceman is the player, the blue Surfer
  is Fritz. Two characters, period.
- Clean project folder. Six imports max. Nothing from the old pile.
- LAUNCH BAR: APK that boots, spaceman runs a real Norfolk street,
  board flight to the beach, swim in the Bay, blade the droids,
  bike to the boss, fight, collect uridium. Export. Done.

## EXECUTION SEQUENCE (evenings, no decisions left)

E1: Blender — extract board. Termux/browser — fetch Norfolk JSON.
     Clean Godot project. City builds. Screenshot.
E2: Spaceman imports, traversal controller on him, walk the street.
E3: Board mount + flight. Swim in the Bay. Alien fish in the water.
E4: Droids spawn + ProtonBlade + blaster + CombatManager. Fight.
E5: Hoverbike, uridium, VultureEyeBoss. Full loop runs.
E6: Fritz: blue Surfer + glitch shader + blink. Export APK.

Each evening ends with a running editor and a screenshot. No step
depends on anything that doesn't already exist.

THIS DOC CLOSES THE DISCUSSION. The roster is locked. Execute.
