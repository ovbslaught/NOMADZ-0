# Fritz & Bytez — Character Specs

## FRITZ — the living glitch, portal powers

Identity: chrome humanoid (reset Silver Surfer rig) corrupted blue.
Does not ride a board — he blinks.

- Material: fritz_glitch.gdshader (tint blue, band jitter, RGB split,
  scanlines, emission spikes with glitch_amount).
- Ability: raycast-aimed teleport up to 18m, 1.2s cooldown, safe-stop
  before walls. Entry + exit portal rings scale up and fade.
- Glitch amount idles at 0.15, cranks to 1.0 on blink and decays over
  0.25s — the teleport IS the glitch spike.
- Input action to add: blink (E).

Fritz is the traversal-identity answer to the board riders: they cover
ground continuously, he covers it in instants.

## BYTEZ — archivist, connector

Source: tall broad bearded man, black tactical vest over leather jacket,
pouches, knee pads, HUD shades. (reference: 1051568070_1790138346722127.jpg)

- Chassis: Mixamo-rigged male base mesh or stylized astronaut.
- Kit: dark tactical texture pass (flat black reads fine at game
  distance), emissive HUD plane on the shades.
- Ability: scan — pulse that highlights interactables, lore pickups and
  anomaly nodes through walls for a few seconds (his lore role as
  archivist made mechanical).
- Same abstract player, same retarget profile, no special controller.

## Build order

1. Fritz first — one shader + one script makes him fully playable and
   he demos the glitch aesthetic instantly.
2. Bytez second — chassis + texture, scan ability after.
3. Both ride the same swap system as cope/ironman/spider/dragon.
