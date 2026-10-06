# Scene Set: Deep Space to Shallow Ocean — Traversal & Toys

## The four scenes

1. DEEP SPACE / LOW ORBIT
   - need_some_space.glb + city kit (cloud-city-overleague, spiral-city-alpha).
   - Zero-G flight corridors between station debris; sun as a directional
     light with real scale. Shipwreck: the crashed spaceship set piece sits
     half-embedded in an asteroid — first traversal arena. Fly, boost, dash.

2. CITY (ground level)
   - cyberpunk-city.zip (231MB — strip interior meshes in Blender, keep
     facades) or imaginary-city for a lighter build. Ground combat, parkour
     blocks, hover bike lanes.

3. DEEP OCEAN
   - mikolaj-teeming-atlantis-ruins + sunken-monument + alien_fish ambient.
   - SWIM mode: 3D movement, gentle sink, sprint = burst, dash = dolphin
     thrust. Submersible parked near the ruins as the set-piece vehicle.

4. SHALLOW / SURFACE
   - eroded_sand_edge reality scan as shoreline. Transition zone: swim up
     through the surface boundary and SWIM hands off to GROUND automatically.
   - Splash + camera clear on waterline cross. The mode transition IS the
     scene change.

## Movement rules (traversal_controller.gd)

- GROUND: walk 5 / run 8.5, jump, double jump (refund on landing).
- DASH: 22 m/s burst, 0.18s, up to 2 chained (ground dash refunds air dash).
- FLY: 14 / boost 26, sprint-in-air engages, banking roll + pitch follow.
- SWIM: 4 / burst 7, jump/crouch for vertical, sink when idle.
- Everything lerped at 4-12/delta — cyberpunk smooth, no snapping.

## Hover bikes

Attachment system, same slot as the board: swap the board scene for a
hover_bike.tscn, widen BoardPivot, feet-off controls (bike leans with
roll input). The controller does not change — mounts are attachments.
Mount action (E): snap player to bike node, GROUND becomes FLY with
bike-specific speeds. Dismount (E again) with a 0.5s cooldown so you
don't remount instantly.

## Proton blade

Light melee on the same input layer: Q swings, CombatManager handles
damage, trail = ribbon mesh or a quick shader streak on the blade
mesh's emission. Combo window: pressing Q within 0.3s of the last swing
chains to swing 2, then 3, then back to 1. Hitbox = Area3D on the blade
bone, enabled only during the active frames of the swing.

## Uridium flip

The currency loop: uridium crystals (emissive octahedrons) scattered
through all four scenes. Collecting triggers the flip animation —
quick 360 spin + scale pop + chime — and feeds the upgrade economy
(dash count, boost speed, blade combo tier). One pickup type, one
economy, four scenes.

## Build order

1. traversal_controller on a graybox of all four zones in one scene,
   waterline at y=0. Prove swim->surface->run->jump->dash->fly->dive
   in a single uninterrupted chain. That chain IS the game feel.
2. Mode transitions tuned until they feel seamless, then art passes
   per zone from the kits above.
3. Hover bike as board-attachment variant.
4. Blade + CombatManager integration.
5. Uridium economy last — it needs the loops to exist first.
