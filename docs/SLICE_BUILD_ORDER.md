# SLICE BUILD ORDER — REAL ASSETS ONLY. NO PLACEHOLDERS.

Every item is an existing file. Nothing gets modeled, nothing gets
written from scratch. Assembly and launch only.

## STEP 1 — World (one evening)
- fetch_norfolk_osm.py -> real Ocean View / Willoughby / Bay View data
- osm_to_godot.gd -> neon voxel city, collision, beach, swimmable Bay
- A kit props already owned: sci-fi droid + 27-obj space station assets
  + military post scattered on street corners for set dressing

## STEP 2 — Player, day one, real model
- Body: spider-_man_cosmic_invasion.glb (rigged, 3MB, drop-in)
  OR hero_silversurfer01_S01.fbx (rigged). Not a capsule. A hero.
- Controller: traversal_controller.gd (committed, handles everything)
- Retarget: SkeletonProfileHumanoid on import -> anim library drives him

## STEP 3 — Enemies, real models
- SciFiDroid.obj -> street drones, tween hover, DamageArea3D hitbox
- EnemyDrone.gd + EnemySpawner.gd + wave.gd -> the wave logic, written
- iron_man.obj / Ironman_Chassis.glb as a rival fight later

## STEP 4 — Combat, real weapons
- ProtonBlade.gd -> melee, already written
- ModularWeapon system (ModularWeapon_SpawnedObjects.tscn +
  FiringConfiguration_WeaponLocation) -> the blaster, already written
- CombatManager.gd -> damage pipeline, already written

## STEP 5 — The loop
- Hoverbike.tscn -> bridge run, already exists
- Collectable.gd + UpgradeInventory.gd -> uridium, already written
- VultureEyeBoss.gd + BossRoom -> boss fight, already written
- HealthPickup.gd + health.gd -> staying alive, already written

## STEP 6 — Skin pass (assets, not work)
- Alien fish in the Bay (animated, ready)
- alien_fish + game-ready-dolphin + submersible for the water
- FX: fritz_glitch.gdshader for portal FX, crt shader for the look
- Music: Cosmic Key Theme once it exists, until then nothing

## WHAT IS DELIBERATELY NOT IN THE SLICE
- No planets, no NMS layer, no GOAT port, no fleet, no board
- No character swap menu — ONE body, the hero
- No save system — SavePoint.gd exists, add it AFTER launch
- That's not a cut, that's the slice. Ship it, then expand.

LAUNCH BAR: boot, run down a real Ocean View street as a rigged hero,
blade the droids, ride the bike to the beach, swim, boss fight, done.
A build folder and an APK. That is the finish line.
