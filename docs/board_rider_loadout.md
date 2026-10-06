# Board Rider Loadout — Iron Man / Tantalus Pilot on Silver Surfer's Board

Flight is a loadout, not a body. Any swapped body can equip the board and fly.

## 1. Extract the board (one time, in Blender)

1. Import the Silver Surfer FBX.
2. Select the board faces, press P -> Selection to separate it as its own object.
3. Delete the Surfer body, keep the board, apply transforms.
4. Export as res://characters/attachments/silver_board.glb.
5. Wrap in a scene: Node3D > MeshInstance3D (board), origin centered at the deck.

## 2. Wire it into the abstract player

- Add a BoardPivot (Node3D) under MeshHolder at feet height (~ -0.05 y for a
  standard 1.8m character; tune per body).
- Attach board_flight_controller.gd logic (see tools/godot/board_flight_controller.gd).
- Input actions to add: flight_toggle (F), boost (Shift), board_toggle (B),
  crouch (Ctrl or C).

## 3. Per-body surf stance

Humanoid profile conformity means the shared anim set still plays, but a
surfer stance is a per-body AnimationPlayer override — record a simple
stance pose on the retargeted skeleton (knees bent, feet apart) and play it
whenever flying && board_equipped. For Iron Man, a repulsor-hover pose
(feet down, slight lean) works with no new anims at all — just keep the
idle and let the banking from the controller sell it.

## 4. Feel checklist

- Board visible only when equipped or flying.
- Vertical control on jump/crouch, boost on sprint key.
- Banking roll +-0.5 rad max into turns; pitch follows vertical velocity.
- Lerp everything at 5-6/delta — snappy but never instant.
- Landing: flight_toggle off, gravity resumes, land anim triggers on
  is_on_floor() transition.

## 5. Extending

Same loadout pattern covers: Cooper's jetpack (replace board scene,
keep controller), cyber-dude hover boots (board scaled flat and wide,
tinted), dragon riding its own wings (skip board, flying=true only).
One controller, many attachments.
