## PlayerController.gd
## NOMADZ-0 — Cope (Sol's avatar), CharacterBody3D player controller.
## Branch: Cosmic-key
##
## Node type: CharacterBody3D
## Signals:
##   used(uridium_amount: float)       — emitted whenever Uridium is consumed
##   transformed(new_mode: TransformMode) — emitted on successful mode change
##   landed                             — emitted when hitting the ground after airborne
##   fell_off_world                     — emitted when falling past kill_z threshold
##
## Requires Director autoload (Director.gd).
## Requires an AnimationTree with an AnimationStateMachinePlayback parameter at "parameters/playback".
## Each TransformMode expects a distinct CollisionShape3D child; assign via @export.

class_name PlayerController
extends CharacterBody3D

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal used(uridium_amount: float)
signal transformed(new_mode: TransformMode)
signal landed
signal fell_off_world

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

## Movement finite-state machine states.
enum MoveState {
	IDLE,
	WALK,
	RUN,
	JUMP,
	FALL,
	HOVER,
	DEAD
}

## Player transform modes — each fundamentally changes physics and look.
enum TransformMode {
	PILOT,      ## Default on-foot humanoid
	SURFBOARD,  ## Fast glide, reduced gravity
	MECH,       ## Heavy, damage resistant
	SPACESHIP   ## Full 6-DOF, zero gravity
}

# ---------------------------------------------------------------------------
# Exported physics / gameplay tunables
# ---------------------------------------------------------------------------

@export_group("Movement")
@export var speed: float = 6.0
@export var run_multiplier: float = 1.8
@export var jump_velocity: float = 8.0
@export var gravity_scale: float = 1.0

@export_group("Uridium (ProtonCharge)")
@export var uridium_max: float = 100.0
@export var uridium_flip_force: float = 10.0
@export var uridium_cost_flip: float = 25.0

@export_group("Wall Run")
@export var wall_run_max_time: float = 1.2
@export var wall_run_gravity_scale: float = 0.25  ## Fraction of full gravity while wall-running

@export_group("Transform Mode Collision Shapes")
## Assign each CollisionShape3D child node in the Inspector.
@export var shape_pilot: CollisionShape3D
@export var shape_surfboard: CollisionShape3D
@export var shape_mech: CollisionShape3D
@export var shape_spaceship: CollisionShape3D

@export_group("Transform Mode Speeds")
@export var surfboard_speed: float = 18.0
@export var surfboard_gravity_scale: float = 0.4
@export var mech_speed: float = 3.5
@export var mech_gravity_scale: float = 1.6
@export var spaceship_speed: float = 22.0

@export_group("World Bounds")
@export var kill_z: float = -80.0         ## Y-position (fall) that triggers fell_off_world
@export var health_danger_threshold: float = 25.0  ## % HP below which tension spike fires

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Current movement FSM state.
var _move_state: MoveState = MoveState.IDLE

## Current transform/loadout mode.
var _transform_mode: TransformMode = TransformMode.PILOT

## Ordered list of modes for cycle navigation.
const _MODE_CYCLE: Array = [
	TransformMode.PILOT,
	TransformMode.SURFBOARD,
	TransformMode.MECH,
	TransformMode.SPACESHIP
]

# --- Uridium (ProtonCharge) ---
var uridium: float = 100.0

# --- Health ---
var health: float = 100.0
var max_health: float = 100.0

# --- Coyote / jump buffer ---
var _coyote_timer: float = 0.0          ## Counts DOWN from 0.15 after leaving ground
var _jump_buffer_timer: float = 0.0     ## Counts DOWN from 0.1 after jump pressed mid-air
const COYOTE_TIME: float = 0.15
const JUMP_BUFFER_TIME: float = 0.10

# --- Wall run ---
var _wall_run_timer: float = 0.0        ## Time left in current wall-run
var _is_wall_running: bool = false

# --- Hover (Surfboard HOVER sub-state) ---
var _hover_timer: float = 0.0
const HOVER_DURATION: float = 0.6

# --- Was on floor last frame (for landed signal) ---
var _was_on_floor: bool = false

# --- Danger tension signal throttle ---
var _last_tension_emit_time: float = 0.0
const TENSION_EMIT_INTERVAL: float = 5.0

# --- Node refs cached in _ready ---
var _animation_tree: AnimationTree
var _anim_state_machine: AnimationNodeStateMachinePlayback

# Global gravity from project settings (cached once)
var _project_gravity: float = 9.8

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Cache project gravity; Godot 4 stores it under Physics > 3D > default_gravity.
	_project_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

	# Locate AnimationTree sibling or child — adjust path if your scene differs.
	_animation_tree = _find_animation_tree()
	if _animation_tree:
		_anim_state_machine = _animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

	# Ensure only the PILOT collision shape is enabled at startup.
	_apply_collision_shape(_transform_mode)

	# Connect to Director signals if available (graceful degradation).
	if Engine.has_singleton("Director"):
		var director = Engine.get_singleton("Director")
		if director.has_signal("player_damage_taken"):
			director.player_damage_taken.connect(_on_director_player_damage_taken)


func _find_animation_tree() -> AnimationTree:
	## Walk children first, then siblings. Returns null if not found.
	for child in get_children():
		if child is AnimationTree:
			return child
	if get_parent():
		for sibling in get_parent().get_children():
			if sibling is AnimationTree:
				return sibling
	return null


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _move_state == MoveState.DEAD:
		return

	# Jump buffer: record intent even before landing.
	if event.is_action_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER_TIME

	# Uridium Flip — double-jump-style surge consuming ProtonCharge.
	if event.is_action_pressed("uridium_flip"):
		_try_uridium_flip()

	# Transform cycling.
	if event.is_action_pressed("transform_next"):
		_cycle_transform(1)
	elif event.is_action_pressed("transform_prev"):
		_cycle_transform(-1)


# ---------------------------------------------------------------------------
# Per-frame logic (_process handles non-physics timers + UI signals)
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _move_state == MoveState.DEAD:
		return

	# Tick coyote and jump-buffer timers.
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	# Wall-run timer.
	if _is_wall_running:
		_wall_run_timer -= delta
		if _wall_run_timer <= 0.0:
			_end_wall_run()

	# Hover timer (Surfboard mode air-brake).
	if _move_state == MoveState.HOVER:
		_hover_timer -= delta
		if _hover_timer <= 0.0:
			_set_move_state(MoveState.FALL)

	# Fell off world.
	if global_position.y < kill_z:
		fell_off_world.emit()
		_set_move_state(MoveState.DEAD)

	# Danger tension spike (emit to Director when HP is critical).
	_check_danger_tension(delta)


# ---------------------------------------------------------------------------
# Physics
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _move_state == MoveState.DEAD:
		return

	match _transform_mode:
		TransformMode.SPACESHIP:
			_physics_spaceship(delta)
		_:
			_physics_grounded(delta)


func _physics_grounded(delta: float) -> void:
	## Standard ground/air physics used by PILOT, SURFBOARD, MECH.

	var on_floor := is_on_floor()

	# Landing detection: was airborne, now on floor.
	if on_floor and not _was_on_floor:
		_on_landed()
	_was_on_floor = on_floor

	# Coyote time: when just walked off an edge, start countdown.
	if _was_on_floor and not on_floor:
		_coyote_timer = COYOTE_TIME

	# --- Gravity application ---
	var effective_gravity := _project_gravity * _get_gravity_scale()
	if _is_wall_running:
		effective_gravity *= wall_run_gravity_scale

	if not on_floor:
		velocity.y -= effective_gravity * delta
		velocity.y = maxf(velocity.y, -50.0)  # terminal velocity cap

	# --- Jump ---
	var can_jump := on_floor or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_jump:
		_do_jump()

	# --- Horizontal movement ---
	var input_dir := _get_input_direction()
	var current_speed := _get_current_speed()

	# Rotate input to camera-relative direction (assumes Camera3D is a child of a pivot).
	var cam_basis := _get_camera_basis()
	var move_dir := (cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if move_dir.length_squared() > 0.0:
		velocity.x = move_dir.x * current_speed
		velocity.z = move_dir.z * current_speed
		_rotate_toward_movement(move_dir, delta)
	else:
		# Decelerate smoothly.
		velocity.x = move_toward(velocity.x, 0.0, current_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, current_speed * 8.0 * delta)

	# --- Wall-run check (air + moving into wall) ---
	if not on_floor and is_on_wall() and input_dir.length_squared() > 0.0:
		_try_start_wall_run()

	# --- FSM state update ---
	_update_move_state(on_floor, input_dir)

	move_and_slide()


func _physics_spaceship(delta: float) -> void:
	## Full 6-DOF flight: pitch, yaw, roll from input.
	var current_speed := spaceship_speed

	# Forward thrust from move_forward / move_back.
	var thrust := 0.0
	if Input.is_action_pressed("move_forward"):
		thrust = 1.0
	elif Input.is_action_pressed("move_back"):
		thrust = -0.5

	# Strafe with move_left / move_right.
	var strafe := 0.0
	if Input.is_action_pressed("move_right"):
		strafe = 1.0
	elif Input.is_action_pressed("move_left"):
		strafe = -1.0

	# Vertical (jump = ascend, crouch = descend if bound).
	var vertical := 0.0
	if Input.is_action_pressed("jump"):
		vertical = 1.0

	var local_move := Vector3(strafe, vertical, -thrust)
	velocity = global_transform.basis * (local_move * current_speed)
	move_and_slide()

	# Keep FSM at HOVER while in spaceship.
	if _move_state != MoveState.HOVER:
		_set_move_state(MoveState.HOVER)


# ---------------------------------------------------------------------------
# Jump / Uridium Flip
# ---------------------------------------------------------------------------

func _do_jump() -> void:
	velocity.y = jump_velocity
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_set_move_state(MoveState.JUMP)
	_anim_travel("jump")


func _try_uridium_flip() -> void:
	## Uridium Flip: a mid-air surge consuming ProtonCharge.
	## Can be used even while on the ground (upward burst).
	if uridium < uridium_cost_flip:
		# Not enough charge — play reject feedback (sound handled by Director signal).
		return

	uridium -= uridium_cost_flip
	used.emit(uridium_cost_flip)

	# Apply upward + forward force.
	var cam_basis := _get_camera_basis()
	var input_dir := _get_input_direction()
	var move_dir := (cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	velocity.y = uridium_flip_force
	if move_dir.length_squared() > 0.01:
		velocity.x = move_dir.x * _get_current_speed() * 1.5
		velocity.z = move_dir.z * _get_current_speed() * 1.5

	_set_move_state(MoveState.JUMP)
	_anim_travel("uridium_flip")


# ---------------------------------------------------------------------------
# Wall Run
# ---------------------------------------------------------------------------

func _try_start_wall_run() -> void:
	if _is_wall_running:
		return
	_is_wall_running = true
	_wall_run_timer = wall_run_max_time
	# Cancel downward velocity to "stick" to wall momentarily.
	velocity.y = maxf(velocity.y, 0.0)


func _end_wall_run() -> void:
	_is_wall_running = false
	_wall_run_timer = 0.0


# ---------------------------------------------------------------------------
# Transform Cycling
# ---------------------------------------------------------------------------

func _cycle_transform(direction: int) -> void:
	## direction: +1 = next, -1 = prev in _MODE_CYCLE.
	var current_idx := _MODE_CYCLE.find(_transform_mode)
	var next_idx := posmod(current_idx + direction, _MODE_CYCLE.size())
	var new_mode: TransformMode = _MODE_CYCLE[next_idx]
	_apply_transform(new_mode)


func _apply_transform(new_mode: TransformMode) -> void:
	var anim_names: Dictionary = {
		TransformMode.PILOT:     "transform_pilot",
		TransformMode.SURFBOARD: "transform_surf",
		TransformMode.MECH:      "transform_mech",
		TransformMode.SPACESHIP: "transform_ship",
	}
	_anim_travel(anim_names.get(new_mode, "transform_pilot"))

	_transform_mode = new_mode
	_apply_collision_shape(new_mode)

	# Reset wall run on any transform.
	_end_wall_run()

	transformed.emit(new_mode)


func _apply_collision_shape(mode: TransformMode) -> void:
	## Disable all shapes, then enable only the one matching the current mode.
	var shapes: Array[CollisionShape3D] = [shape_pilot, shape_surfboard, shape_mech, shape_spaceship]
	var active: CollisionShape3D = shapes[mode]  # enum ints match array indices

	for shape in shapes:
		if shape:
			shape.disabled = (shape != active)


# ---------------------------------------------------------------------------
# Movement FSM helpers
# ---------------------------------------------------------------------------

func _update_move_state(on_floor: bool, input_dir: Vector2) -> void:
	## Drive FSM and AnimationTree from physics state.
	match _move_state:
		MoveState.DEAD:
			return
		_:
			pass

	var moving := input_dir.length_squared() > 0.01
	var running := moving and Input.is_action_pressed("move_forward") and (
		velocity.length() > speed * run_multiplier * 0.8
	)

	if on_floor:
		if not moving:
			_set_move_state(MoveState.IDLE)
		elif running:
			_set_move_state(MoveState.RUN)
		else:
			_set_move_state(MoveState.WALK)
	else:
		if velocity.y > 0.5 and _move_state != MoveState.HOVER:
			_set_move_state(MoveState.JUMP)
		elif velocity.y <= 0.0 and _move_state != MoveState.HOVER:
			_set_move_state(MoveState.FALL)


func _set_move_state(new_state: MoveState) -> void:
	if _move_state == new_state:
		return
	_move_state = new_state

	# Mirror to AnimationTree.
	var anim_map: Dictionary = {
		MoveState.IDLE:  "idle",
		MoveState.WALK:  "walk",
		MoveState.RUN:   "run",
		MoveState.JUMP:  "jump",
		MoveState.FALL:  "fall",
		MoveState.HOVER: "hover",
		MoveState.DEAD:  "fall",  # fallback; game should trigger death cutscene
	}
	_anim_travel(anim_map.get(new_state, "idle"))


func _on_landed() -> void:
	if _move_state == MoveState.DEAD:
		return
	_end_wall_run()
	_set_move_state(MoveState.IDLE)
	_anim_travel("land")
	landed.emit()


# ---------------------------------------------------------------------------
# Speed / gravity helpers
# ---------------------------------------------------------------------------

func _get_current_speed() -> float:
	## Returns effective horizontal speed for the current mode and input state.
	var is_running := Input.is_action_pressed("move_forward") and _move_state == MoveState.RUN
	match _transform_mode:
		TransformMode.SURFBOARD:
			return surfboard_speed
		TransformMode.MECH:
			return mech_speed
		TransformMode.SPACESHIP:
			return spaceship_speed
		_:  # PILOT
			return speed * (run_multiplier if is_running else 1.0)


func _get_gravity_scale() -> float:
	match _transform_mode:
		TransformMode.SURFBOARD:
			return surfboard_gravity_scale
		TransformMode.MECH:
			return mech_gravity_scale
		TransformMode.SPACESHIP:
			return 0.0  # handled in _physics_spaceship
		_:
			return gravity_scale


# ---------------------------------------------------------------------------
# Input direction (raw 2D)
# ---------------------------------------------------------------------------

func _get_input_direction() -> Vector2:
	return Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)


# ---------------------------------------------------------------------------
# Camera basis helper
# ---------------------------------------------------------------------------

func _get_camera_basis() -> Basis:
	## Returns camera's horizontal basis for input projection.
	## Assumes Camera3D is accessible via get_viewport().get_camera_3d().
	var cam := get_viewport().get_camera_3d()
	if cam:
		var b := cam.global_transform.basis
		# Flatten to horizontal plane (remove pitch).
		b.y = Vector3.UP
		b.x = b.z.cross(Vector3.UP).normalized()
		b.z = Vector3.UP.cross(b.x).normalized()
		return b
	return Basis.IDENTITY


# ---------------------------------------------------------------------------
# Rotation toward movement direction
# ---------------------------------------------------------------------------

func _rotate_toward_movement(direction: Vector3, delta: float) -> void:
	## Smooth character facing toward movement direction.
	if _transform_mode == TransformMode.SPACESHIP:
		return  # Spaceship handles its own orientation.
	if direction.length_squared() < 0.01:
		return
	var target_angle := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)


# ---------------------------------------------------------------------------
# Director tension integration
# ---------------------------------------------------------------------------

func _check_danger_tension(delta: float) -> void:
	## Emit a tension spike to Director when health is critically low.
	## Throttled to avoid spam.
	if not Engine.has_singleton("Director"):
		return
	var hp_pct := (health / max_health) * 100.0
	if hp_pct <= health_danger_threshold:
		_last_tension_emit_time += delta
		if _last_tension_emit_time >= TENSION_EMIT_INTERVAL:
			_last_tension_emit_time = 0.0
			var director = Engine.get_singleton("Director")
			# Director.tension_changed expects a float delta; we push +0.05 each tick.
			if director.has_signal("tension_changed"):
				director.emit_signal("tension_changed", 0.05)


func _on_director_player_damage_taken() -> void:
	## React to damage events forwarded from Director (e.g. enemy hit VFX, rumble).
	## Actual health deduction happens in HealthComponent (not shown here).
	pass  # Hook point for camera shake, controller rumble, etc.


# ---------------------------------------------------------------------------
# Public API (callable from other nodes / signals)
# ---------------------------------------------------------------------------

func take_damage(amount: float) -> void:
	## Apply damage. Mech mode has 50% damage resistance.
	var resistance := 0.5 if _transform_mode == TransformMode.MECH else 1.0
	health -= amount * resistance
	health = maxf(health, 0.0)
	if health <= 0.0:
		_die()


func recharge_uridium(amount: float) -> void:
	uridium = minf(uridium + amount, uridium_max)


func _die() -> void:
	_set_move_state(MoveState.DEAD)
	velocity = Vector3.ZERO
	# Optionally emit to Director for narrative response.
	if Engine.has_singleton("Director"):
		var director = Engine.get_singleton("Director")
		if director.has_signal("player_died"):
			director.emit_signal("player_died")


# ---------------------------------------------------------------------------
# AnimationTree helper
# ---------------------------------------------------------------------------

func _anim_travel(anim_name: String) -> void:
	## Safely call travel() on the AnimationStateMachinePlayback.
	if _anim_state_machine:
		_anim_state_machine.travel(anim_name)
