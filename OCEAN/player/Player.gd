## Player.gd
## CharacterBody2D — NOMADZ: Signal Descent
## NORA — NOMADZ field agent.
## Jetpack Joyride thrust mechanic + Metroid Fusion wall/morph + Animal Well coyote timing.
## VultureCode / Sol / NOMADZ Universe

class_name Player
extends CharacterBody2D

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal landed()
signal jumped()
signal dashed(direction: Vector2)
signal jetpack_activated()
signal jetpack_deactivated()
signal morphed()
signal unmorphed()
signal shot_fired(direction: Vector2, origin: Vector2)
signal signal_pulse_fired()
signal damaged(amount: int)
signal healed_player(amount: int)
signal interacted(interactable: Node)

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const DEBUG_MODE := true

## Movement
const WALK_SPEED      : float = 180.0
const MORPH_SPEED     : float = 90.0
const ACCELERATION    : float = 1200.0
const FRICTION        : float = 900.0
const AIR_FRICTION    : float = 300.0

## Jump
const JUMP_VELOCITY   : float = -380.0
const GRAVITY         : float = 980.0
const GRAVITY_FALL    : float = 1200.0   ## Faster fall (better game feel)
const MAX_FALL_SPEED  : float = 600.0
const COYOTE_TIME     : float = 0.12     ## Seconds after leaving ground that jump still works
const JUMP_BUFFER_TIME: float = 0.10     ## Input buffer window

## Jetpack
const JETPACK_THRUST  : float = 480.0    ## Upward force when jetpack fires
const JETPACK_HOVER   : float = -200.0   ## Gentle hover velocity when near ceiling
const FUEL_MAX        : float = 100.0
const FUEL_CONSUME    : float = 28.0     ## Per second while thrusting
const FUEL_REFILL     : float = 55.0     ## Per second on ground
const FUEL_LOW_THRESH : float = 15.0     ## Below this: warning flash
const JETPACK_BOOST_MULT: float = 1.5    ## With jetpack_boost ability

## Dash
const DASH_SPEED      : float = 520.0
const DASH_DURATION   : float = 0.18
const DASH_COOLDOWN   : float = 0.65
const DASH_GHOST_COUNT: int   = 4        ## Ghost images during dash

## Wall slide
const WALL_SLIDE_SPEED: float = 60.0
const WALL_JUMP_V     : Vector2 = Vector2(220.0, -320.0)

## Combat
const SHOOT_COOLDOWN  : float = 0.22
const SIGNAL_PULSE_CD : float = 1.8
const INVINCIBILITY   : float = 1.2     ## Seconds after taking damage

## Morph
const MORPH_CROUCH_SCALE: float = 0.55

# ─── EXPORTS ─────────────────────────────────────────────────────────────────
@export var light_energy    : float = 1.2
@export var light_color     : Color = Color(0.4, 0.8, 1.0, 1.0)

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var sprite          : AnimatedSprite2D  = $AnimatedSprite2D
@onready var collision       : CollisionShape2D  = $CollisionShape2D
@onready var morph_collision : CollisionShape2D  = $MorphCollision
@onready var coyote_timer    : Timer             = $CoyoteTimer
@onready var jump_buffer_timer: Timer            = $JumpBufferTimer
@onready var dash_timer      : Timer             = $DashTimer
@onready var dash_cd_timer   : Timer             = $DashCooldownTimer
@onready var shoot_timer     : Timer             = $ShootTimer
@onready var pulse_timer     : Timer             = $PulseTimer
@onready var invincibility_timer: Timer          = $InvincibilityTimer
@onready var player_light    : PointLight2D      = $PlayerLight
@onready var jetpack_particles: GPUParticles2D   = $JetpackParticles
@onready var dash_particles  : GPUParticles2D    = $DashParticles
@onready var shoot_origin    : Marker2D          = $ShootOrigin
@onready var anim_tree       : AnimationTree     = null  ## Optional — assign if using AnimationTree

# ─── STATE ───────────────────────────────────────────────────────────────────
var fuel              : float = FUEL_MAX
var is_morphed        : bool  = false
var is_dashing        : bool  = false
var is_invincible     : bool  = false
var is_dead           : bool  = false
var is_on_wall_l      : bool  = false
var is_on_wall_r      : bool  = false
var was_on_floor      : bool  = false
var coyote_available  : bool  = false
var jump_buffered     : bool  = false
var jetpack_on        : bool  = false
var facing_right      : bool  = true
var dash_direction    : Vector2 = Vector2.RIGHT
var _frame_count      : int   = 0

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_validate_nodes()
	_setup_timers()
	_setup_light()
	_connect_signals()
	_log("Player NORA online — ARCHON Protocol active")

func _validate_nodes() -> void:
	## Graceful missing-node handling
	if not is_instance_valid(sprite):
		push_error("Player: AnimatedSprite2D missing")
	if not is_instance_valid(collision):
		push_error("Player: CollisionShape2D missing")
	if not is_instance_valid(player_light):
		push_warning("Player: PointLight2D missing — darkness will be absolute")

func _setup_timers() -> void:
	_ensure_timer("CoyoteTimer",      COYOTE_TIME,    true)
	_ensure_timer("JumpBufferTimer",  JUMP_BUFFER_TIME, true)
	_ensure_timer("DashTimer",        DASH_DURATION,  true)
	_ensure_timer("DashCooldownTimer",DASH_COOLDOWN,  true)
	_ensure_timer("ShootTimer",       SHOOT_COOLDOWN, true)
	_ensure_timer("PulseTimer",       SIGNAL_PULSE_CD, true)
	_ensure_timer("InvincibilityTimer", INVINCIBILITY, true)

func _ensure_timer(node_name: String, wait_time: float, one_shot: bool) -> void:
	if not has_node(node_name):
		var t := Timer.new()
		t.name = node_name
		t.wait_time = wait_time
		t.one_shot = one_shot
		add_child(t)

func _setup_light() -> void:
	if is_instance_valid(player_light):
		player_light.energy = light_energy
		player_light.color  = light_color

func _connect_signals() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.player_died.connect(_on_game_player_died)
	SignalverseManager.bleed_event_triggered.connect(_on_bleed_event)

	if has_node("CoyoteTimer"):
		$CoyoteTimer.timeout.connect(func(): coyote_available = false)
	if has_node("JumpBufferTimer"):
		$JumpBufferTimer.timeout.connect(func(): jump_buffered = false)
	if has_node("DashTimer"):
		$DashTimer.timeout.connect(_on_dash_ended)
	if has_node("InvincibilityTimer"):
		$InvincibilityTimer.timeout.connect(func(): is_invincible = false)

# ─── INPUT ────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if is_dead or GameManager.is_paused or GameManager.is_cutscene:
		return

	## Jump buffer
	if event.is_action_pressed("jump"):
		jump_buffered = true
		if has_node("JumpBufferTimer"):
			$JumpBufferTimer.start()

	## Dash
	if event.is_action_pressed("dash") and GameManager.has_ability("dash"):
		_try_dash()

	## Signal Pulse
	if event.is_action_pressed("signal_pulse") and GameManager.has_ability("signal_pulse"):
		_try_signal_pulse()

	## Morph toggle
	if event.is_action_pressed("morph") and GameManager.has_ability("morph_compress"):
		_toggle_morph()

	## Interact
	if event.is_action_pressed("interact"):
		_try_interact()

	## Shoot
	if event.is_action_pressed("shoot"):
		_try_shoot()

# ─── PHYSICS ─────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_frame_count += 1

	_handle_floor_state(delta)
	_handle_gravity(delta)
	_handle_movement(delta)
	_handle_jetpack(delta)
	_handle_wall_slide(delta)
	_handle_jump()
	_handle_double_jump()
	_update_facing()
	_tick_fuel(delta)

	move_and_slide()

	_update_animation()
	_update_light()

# ─── FLOOR STATE ─────────────────────────────────────────────────────────────
func _handle_floor_state(delta: float) -> void:
	var on_floor_now := is_on_floor()

	if was_on_floor and not on_floor_now:
		## Just left the ground — start coyote window
		coyote_available = true
		if has_node("CoyoteTimer"):
			$CoyoteTimer.start()
	elif on_floor_now and not was_on_floor:
		## Just landed
		_on_landed()

	was_on_floor = on_floor_now
	is_on_wall_l = is_on_wall() and get_wall_normal().x > 0
	is_on_wall_r = is_on_wall() and get_wall_normal().x < 0

func _on_landed() -> void:
	landed.emit()
	AudioManager.play_sfx("land")
	if is_instance_valid(jetpack_particles):
		jetpack_particles.emitting = false
	jetpack_on = false
	AudioManager.stop_jetpack_sfx()

# ─── GRAVITY ─────────────────────────────────────────────────────────────────
func _handle_gravity(delta: float) -> void:
	if is_on_floor() or is_dashing:
		return

	if jetpack_on and fuel > 0:
		return  ## Jetpack handles vertical velocity directly

	## Wall slide — reduced gravity
	if (is_on_wall_l or is_on_wall_r) and velocity.y > 0:
		velocity.y = move_toward(velocity.y, WALL_SLIDE_SPEED, GRAVITY * delta)
		return

	## Fast-fall gravity
	var grav := GRAVITY_FALL if velocity.y > 0 else GRAVITY
	velocity.y = minf(velocity.y + grav * delta, MAX_FALL_SPEED)

# ─── MOVEMENT ─────────────────────────────────────────────────────────────────
func _handle_movement(delta: float) -> void:
	if is_dashing:
		return

	var direction := ProControllerManager.get_controller_input("move_right") - ProControllerManager.get_controller_input("move_left")
	var speed     := MORPH_SPEED if is_morphed else WALK_SPEED

	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, ACCELERATION * delta)
	else:
		var friction := FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

# ─── JUMP ─────────────────────────────────────────────────────────────────────
func _handle_jump() -> void:
	if not jump_buffered:
		return

	var can_jump := is_on_floor() or coyote_available

	if can_jump:
		velocity.y = JUMP_VELOCITY
		coyote_available = false
		jump_buffered    = false
		if has_node("JumpBufferTimer"):
			$JumpBufferTimer.stop()
		jumped.emit()
		AudioManager.play_sfx("jump")

func _handle_double_jump() -> void:
	## Double jump ability — consumes a jump token set by jump state
	## Handled by AbilitySystem if present; placeholder logic here
	pass

# ─── JETPACK ─────────────────────────────────────────────────────────────────
func _handle_jetpack(delta: float) -> void:
	if is_on_floor() or is_morphed or is_dashing:
		if jetpack_on:
			jetpack_on = false
			AudioManager.stop_jetpack_sfx()
			if is_instance_valid(jetpack_particles):
				jetpack_particles.emitting = false
		return

	var thrust_mult := JETPACK_BOOST_MULT if GameManager.has_ability("jetpack_boost") else 1.0

	if ProControllerManager.get_controller_input("jetpack") > 0.5 and fuel > 0 and not is_on_floor():
		if not jetpack_on:
			jetpack_on = true
			jetpack_activated.emit()
			AudioManager.start_jetpack_sfx()
			if is_instance_valid(jetpack_particles):
				jetpack_particles.emitting = true

		velocity.y -= JETPACK_THRUST * thrust_mult * delta
		velocity.y  = maxf(velocity.y, -MAX_FALL_SPEED)

		fuel = maxf(0.0, fuel - FUEL_CONSUME * delta)
		GameManager.update_fuel(fuel)

		if fuel <= 0:
			jetpack_on = false
			jetpack_deactivated.emit()
			AudioManager.stop_jetpack_sfx()
			if is_instance_valid(jetpack_particles):
				jetpack_particles.emitting = false
	else:
		if jetpack_on:
			jetpack_on = false
			jetpack_deactivated.emit()
			AudioManager.stop_jetpack_sfx()
			if is_instance_valid(jetpack_particles):
				jetpack_particles.emitting = false

func _tick_fuel(delta: float) -> void:
	if is_on_floor() and not jetpack_on:
		fuel = minf(FUEL_MAX, fuel + FUEL_REFILL * delta)
		GameManager.update_fuel(fuel)

# ─── WALL SLIDE ───────────────────────────────────────────────────────────────
func _handle_wall_slide(_delta: float) -> void:
	if not (is_on_wall_l or is_on_wall_r):
		return
	if is_on_floor() or is_morphed:
		return

	## Wall jump on jump input
	if jump_buffered:
		var dir := 1.0 if is_on_wall_l else -1.0
		velocity = Vector2(WALL_JUMP_V.x * dir, WALL_JUMP_V.y)
		jump_buffered = false
		jumped.emit()
		AudioManager.play_sfx("jump")

# ─── DASH ─────────────────────────────────────────────────────────────────────
func _try_dash() -> void:
	if is_dashing:
		return
	if not $DashCooldownTimer.is_stopped():
		return

	var dir := Vector2(ProControllerManager.get_controller_input("move_right") - ProControllerManager.get_controller_input("move_left"), ProControllerManager.get_controller_input("morph") - ProControllerManager.get_controller_input("jump"))
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT if facing_right else Vector2.LEFT

	dash_direction = dir.normalized()
	is_dashing     = true
	velocity        = dash_direction * DASH_SPEED
	is_invincible   = true

	$DashTimer.start()
	$DashCooldownTimer.start()
	AudioManager.play_sfx("dash")
	dashed.emit(dash_direction)
	if is_instance_valid(dash_particles):
		dash_particles.emitting = true
	_log("Dash: %s" % str(dash_direction))

func _on_dash_ended() -> void:
	is_dashing   = false
	velocity.x   = velocity.x * 0.3  ## Preserve some momentum
	is_invincible = false
	if is_instance_valid(dash_particles):
		dash_particles.emitting = false

# ─── SIGNAL PULSE ─────────────────────────────────────────────────────────────
func _try_signal_pulse() -> void:
	if not $PulseTimer.is_stopped():
		return
	$PulseTimer.start()
	signal_pulse_fired.emit()
	AudioManager.play_sfx("signal_pulse")
	_log("Signal Pulse fired")
	## Pulse effect is handled by the PulseArea node in the scene

# ─── SHOOT ────────────────────────────────────────────────────────────────────
func _try_shoot() -> void:
	if not $ShootTimer.is_stopped():
		return
	$ShootTimer.start()

	var dir := Vector2.RIGHT if facing_right else Vector2.LEFT
	if is_instance_valid(shoot_origin):
		shot_fired.emit(dir, shoot_origin.global_position)
	else:
		shot_fired.emit(dir, global_position)

	AudioManager.play_sfx("shoot")

# ─── MORPH ────────────────────────────────────────────────────────────────────
func _toggle_morph() -> void:
	if is_morphed:
		_unmorph()
	else:
		_morph()

func _morph() -> void:
	if not is_on_floor():
		return  ## Can only morph on ground
	is_morphed = true
	if is_instance_valid(collision):
		collision.disabled = true
	if is_instance_valid(morph_collision):
		morph_collision.disabled = false
	if is_instance_valid(sprite):
		sprite.scale.y = MORPH_CROUCH_SCALE
	morphed.emit()
	AudioManager.play_sfx("morph_enter")
	_log("Morphed")

func _unmorph() -> void:
	is_morphed = false
	if is_instance_valid(collision):
		collision.disabled = false
	if is_instance_valid(morph_collision):
		morph_collision.disabled = true
	if is_instance_valid(sprite):
		sprite.scale.y = 1.0
	unmorphed.emit()
	AudioManager.play_sfx("morph_exit")
	_log("Unmorphed")

# ─── INTERACT ─────────────────────────────────────────────────────────────────
func _try_interact() -> void:
	var interactables := get_tree().get_nodes_in_group("interactable")
	for node in interactables:
		if not node is Node2D:
			continue
		var dist : float = global_position.distance_to((node as Node2D).global_position)
		if dist < 48.0:
			interacted.emit(node)
			if node.has_method("on_interact"):
				node.on_interact(self)
			break

# ─── FACING ───────────────────────────────────────────────────────────────────
func _update_facing() -> void:
	var dir := ProControllerManager.get_controller_input("move_right") - ProControllerManager.get_controller_input("move_left")
	if dir > 0:
		facing_right = true
		if is_instance_valid(sprite):
			sprite.flip_h = false
		if is_instance_valid(shoot_origin):
			shoot_origin.position.x = absf(shoot_origin.position.x)
	elif dir < 0:
		facing_right = false
		if is_instance_valid(sprite):
			sprite.flip_h = true
		if is_instance_valid(shoot_origin):
			shoot_origin.position.x = -absf(shoot_origin.position.x)

# ─── ANIMATION ────────────────────────────────────────────────────────────────
func _update_animation() -> void:
	if not is_instance_valid(sprite):
		return

	if is_dashing:
		sprite.play("dash")
	elif is_morphed:
		sprite.play("morph_roll" if absf(velocity.x) > 10 else "morph_idle")
	elif not is_on_floor():
		if jetpack_on:
			sprite.play("jetpack")
		elif (is_on_wall_l or is_on_wall_r) and velocity.y > 0:
			sprite.play("wall_slide")
		elif velocity.y < 0:
			sprite.play("jump_rise")
		else:
			sprite.play("jump_fall")
	elif absf(velocity.x) > 10:
		sprite.play("run")
	else:
		sprite.play("idle")

# ─── LIGHT ────────────────────────────────────────────────────────────────────
func _update_light() -> void:
	if not is_instance_valid(player_light):
		return
	## Light pulses with corruption — higher corruption = flickery light
	var corruption := SignalverseManager.corruption_level / 100.0
	var flicker := sin(Time.get_ticks_msec() * 0.01) * corruption * 0.2
	player_light.energy = light_energy + flicker

# ─── DAMAGE ───────────────────────────────────────────────────────────────────
func take_damage(amount: int, source: String = "unknown") -> void:
	if is_invincible or is_dead:
		return
	if amount <= 0:
		return

	is_invincible = true
	$InvincibilityTimer.start()

	GameManager.take_damage(amount, source)
	damaged.emit(amount)
	_flash_damage()
	_log("Damage: -%d from %s" % [amount, source])

func _flash_damage() -> void:
	if not is_instance_valid(sprite):
		return
	var tween := create_tween()
	for i in 4:
		tween.tween_property(sprite, "modulate:a", 0.2, 0.1)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.1)

func _on_health_changed(_current: int, _maximum: int) -> void:
	pass  ## HUD handles this signal directly

func _on_game_player_died() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	if is_instance_valid(sprite):
		sprite.play("death")
	_log("NORA: signal lost")

# ─── BLEED EVENTS ─────────────────────────────────────────────────────────────
func _on_bleed_event(event_type: String, payload: Dictionary) -> void:
	match event_type:
		"gravity_pulse":
			## Brief upward impulse — disorienting
			velocity.y -= 180.0
		"mother_brain_restored":
			_log("MOTHER BRAIN signal received — mission complete")

# ─── DEBUG ────────────────────────────────────────────────────────────────────
func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[Player | F%d] %s" % [_frame_count, msg])

func get_debug_snapshot() -> Dictionary:
	return {
		"position"   : str(global_position),
		"velocity"   : str(velocity),
		"fuel"       : "%.1f" % fuel,
		"morphed"    : is_morphed,
		"dashing"    : is_dashing,
		"jetpack_on" : jetpack_on,
		"invincible" : is_invincible,
		"facing"     : "right" if facing_right else "left",
	}
