## VultureEyeBoss.gd
## StaticBody2D Boss — NOMADZ: Signal Descent
## VULTURE-EYE: synthetic-organic hybrid, central security node of VULTURE-SIGMA.
## Fused with Signalverse matter. Sees on both physical and signal layers.
## 3 phases: SWEEP → PURSUIT → OVERLOAD
## VultureCode / Sol / NOMADZ Universe

class_name VultureEyeBoss
extends Node2D

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal phase_changed(phase: int)
signal boss_defeated()
signal boss_damaged(remaining_health: int)
signal boss_intro_complete()

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const DEBUG_MODE := true

const MAX_HEALTH   : int   = 300
const PHASE_2_HP   : int   = 200
const PHASE_3_HP   : int   = 100
const SWEEP_SPEED  : float = 80.0     ## Tracking eye beam sweep speed (degrees/sec)
const BEAM_DAMAGE  : int   = 8        ## Per second in beam
const PROJECTILE_DAMAGE: int = 20
const PROJECTILE_SPEED : float = 200.0
const PROJECTILE_COUNT : int   = 6    ## Phase 2: radial burst count
const PHASE_3_BURST_INT: float = 1.2  ## Seconds between phase 3 bursts
const VULNERABLE_WINDOW: float = 3.0  ## Seconds the core is exposed per cycle
const CORE_CYCLE       : float = 8.0  ## Full open/close cycle

## Lore drops
const LORE_ON_DEFEAT   : String = "cr_005"
const FRAGMENT_ON_DEFEAT: String = "frag_vulture_eye"

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var body_sprite     : AnimatedSprite2D = $BodySprite
@onready var eye_sprite      : AnimatedSprite2D = $EyeSprite
@onready var core_area       : Area2D           = $CoreHitbox
@onready var damage_area     : Area2D           = $DamageArea
@onready var beam_cast       : RayCast2D        = $BeamCast
@onready var beam_line       : Line2D           = $BeamLine
@onready var eye_light       : PointLight2D     = $EyeLight
@onready var ambient_light   : PointLight2D     = $AmbientLight
@onready var shoot_origin    : Marker2D         = $ShootOrigin
@onready var projectile_scene: PackedScene      = null  ## Set in scene inspector
@onready var phase_timer     : Timer            = $PhaseTimer
@onready var burst_timer     : Timer            = $BurstTimer
@onready var shockwave       : GPUParticles2D   = $ShockwaveParticles

# ─── STATE ────────────────────────────────────────────────────────────────────
enum Phase { INTRO, SWEEP, PURSUIT, OVERLOAD, DEFEATED }
var phase          : Phase  = Phase.INTRO
var health         : int    = MAX_HEALTH
var core_open      : bool   = false
var core_timer     : float  = 0.0
var beam_active    : bool   = false
var beam_angle     : float  = 0.0      ## Degrees
var beam_dir       : float  = 1.0      ## Sweep direction
var target_player  : Node2D = null
var _frame_count   : int    = 0
var _phase3_burst_elapsed: float = 0.0

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("boss")
	_setup_nodes()
	_connect_signals()
	_start_intro()
	_log("VultureEyeBoss initialized")

func _setup_nodes() -> void:
	_ensure_timer("PhaseTimer", CORE_CYCLE, false)
	_ensure_timer("BurstTimer", PHASE_3_BURST_INT, false)

	if is_instance_valid(eye_light):
		eye_light.color  = Color(1.0, 0.2, 0.0, 1.0)
		eye_light.energy = 2.0

	if is_instance_valid(beam_line):
		beam_line.default_color = Color(1.0, 0.1, 0.0, 0.85)
		beam_line.width         = 4.0
		beam_line.visible       = false

	## Disable core hitbox until open
	if is_instance_valid(core_area):
		core_area.monitoring = false

func _ensure_timer(node_name: String, wait_time: float, one_shot: bool) -> void:
	if not has_node(node_name):
		var t := Timer.new()
		t.name = node_name
		t.wait_time = wait_time
		t.one_shot  = one_shot
		add_child(t)

func _connect_signals() -> void:
	if has_node("PhaseTimer"):
		$PhaseTimer.timeout.connect(_on_phase_timer)
	if has_node("BurstTimer"):
		$BurstTimer.timeout.connect(_on_burst_timer)
	if has_node("CoreHitbox"):
		core_area.body_entered.connect(_on_core_hit_body_entered)
	if has_node("DamageArea"):
		damage_area.body_entered.connect(_on_damage_body_entered)

# ─── INTRO ────────────────────────────────────────────────────────────────────
func _start_intro() -> void:
	AudioManager.play_sfx("boss_roar")
	if is_instance_valid(body_sprite):
		body_sprite.play("wake")

	## Shake, then lock in player reference
	_screen_shake(0.8)
	await get_tree().create_timer(3.0).timeout

	target_player = _find_player()
	if target_player == null:
		push_warning("VultureEyeBoss: no player found in group 'player'")

	boss_intro_complete.emit()
	AudioManager.play_music("boss")
	_enter_phase(Phase.SWEEP)

# ─── PHASE MACHINE ────────────────────────────────────────────────────────────
func _enter_phase(new_phase: Phase) -> void:
	phase = new_phase
	phase_changed.emit(int(new_phase))
	_log("Phase → %s" % Phase.keys()[new_phase])

	match new_phase:
		Phase.SWEEP:
			beam_active = true
			beam_dir    = 1.0
			$PhaseTimer.start(CORE_CYCLE)
			_open_core()

		Phase.PURSUIT:
			beam_active = false
			_close_core()
			_fire_radial_burst(PROJECTILE_COUNT)
			$PhaseTimer.start(CORE_CYCLE)

		Phase.OVERLOAD:
			beam_active = true
			_close_core()
			$BurstTimer.start()
			## Override to faster sweeping
			_log("Phase 3: OVERLOAD — all systems hot")
			_screen_shake(1.5)
			AudioManager.play_sfx("boss_roar")

		Phase.DEFEATED:
			_on_defeated()

func _on_phase_timer() -> void:
	match phase:
		Phase.SWEEP:
			_close_core()
			await get_tree().create_timer(0.8).timeout
			_open_core()
			$PhaseTimer.start(CORE_CYCLE)
		Phase.PURSUIT:
			_open_core()
			await get_tree().create_timer(VULNERABLE_WINDOW).timeout
			_close_core()
			_fire_radial_burst(PROJECTILE_COUNT + 2)
			$PhaseTimer.start(CORE_CYCLE)

func _on_burst_timer() -> void:
	## Phase 3 persistent burst
	if phase == Phase.OVERLOAD:
		_fire_radial_burst(8)
		_open_core()
		await get_tree().create_timer(1.5).timeout
		_close_core()

# ─── CORE OPEN / CLOSE ────────────────────────────────────────────────────────
func _open_core() -> void:
	core_open = true
	if is_instance_valid(core_area):
		core_area.monitoring = true
	if is_instance_valid(eye_sprite):
		eye_sprite.play("open")
	if is_instance_valid(eye_light):
		var tween := create_tween()
		tween.tween_property(eye_light, "energy", 3.0, 0.4)
	_log("Core OPEN — vulnerable window")

func _close_core() -> void:
	core_open = false
	if is_instance_valid(core_area):
		core_area.monitoring = false
	if is_instance_valid(eye_sprite):
		eye_sprite.play("close")
	if is_instance_valid(eye_light):
		var tween := create_tween()
		tween.tween_property(eye_light, "energy", 0.8, 0.3)
	_log("Core CLOSED")

# ─── PROCESS ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if phase == Phase.INTRO or phase == Phase.DEFEATED:
		return
	_frame_count += 1

	_tick_beam(delta)
	_update_visuals(delta)

func _tick_beam(delta: float) -> void:
	if not beam_active:
		if is_instance_valid(beam_line):
			beam_line.visible = false
		return

	match phase:
		Phase.SWEEP:
			## Slow sweep back and forth
			beam_angle += SWEEP_SPEED * beam_dir * delta
			if absf(beam_angle) > 60.0:
				beam_dir *= -1.0
			_cast_beam(deg_to_rad(beam_angle))

		Phase.OVERLOAD:
			## Phase 3: aim at player
			if is_instance_valid(target_player):
				var dir := (target_player.global_position - global_position).normalized()
				var target_angle := dir.angle()
				beam_angle = lerp_angle(beam_angle, target_angle, delta * 2.5)
				_cast_beam(beam_angle)

func _cast_beam(angle: float) -> void:
	if not is_instance_valid(beam_cast) or not is_instance_valid(beam_line):
		return

	var dir := Vector2.from_angle(angle)
	beam_cast.target_position = dir * 600.0
	beam_cast.force_raycast_update()

	var end_pos : Vector2
	if beam_cast.is_colliding():
		end_pos = beam_cast.get_collision_point() - global_position
		## Damage player if beam hits
		var collider := beam_cast.get_collider()
		if collider is Node2D and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(int(BEAM_DAMAGE * get_process_delta_time()), "VultureEyeBeam")
	else:
		end_pos = beam_cast.target_position

	beam_line.visible         = true
	beam_line.points          = [Vector2.ZERO, end_pos]

# ─── PROJECTILES ──────────────────────────────────────────────────────────────
func _fire_radial_burst(count: int) -> void:
	if projectile_scene == null:
		_log("No projectile scene assigned — burst skipped")
		return
	if not is_instance_valid(shoot_origin):
		return

	var angle_step := TAU / float(count)
	for i in count:
		var angle := i * angle_step
		var proj  := projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = shoot_origin.global_position
		if proj.has_method("fire"):
			proj.fire(Vector2.from_angle(angle), PROJECTILE_SPEED, PROJECTILE_DAMAGE)
	_log("Radial burst: %d projectiles" % count)

# ─── DAMAGE ───────────────────────────────────────────────────────────────────
func _on_core_hit_body_entered(body: Node2D) -> void:
	## Core hit by player projectile or signal pulse
	if not core_open:
		return
	if body.is_in_group("player_projectile"):
		var dmg : int = body.get("damage") if body.get("damage") != null else 10
		take_damage(dmg)
	elif body.is_in_group("signal_pulse"):
		take_damage(25)

## External damage call (from projectile hit_enemy group)
func take_damage(amount: int) -> void:
	if phase == Phase.DEFEATED:
		return
	if not core_open:
		_log("Core closed — damage blocked")
		return

	health -= amount
	health = max(0, health)
	boss_damaged.emit(health)
	AudioManager.play_sfx("hit_enemy")
	_flash_eye()
	_log("Boss HP: %d/%d" % [health, MAX_HEALTH])

	_check_phase_transition()

func _check_phase_transition() -> void:
	if health <= 0:
		_enter_phase(Phase.DEFEATED)
	elif health <= PHASE_3_HP and phase != Phase.OVERLOAD:
		_enter_phase(Phase.OVERLOAD)
	elif health <= PHASE_2_HP and phase == Phase.SWEEP:
		_enter_phase(Phase.PURSUIT)

func _on_damage_body_entered(body: Node2D) -> void:
	## Body contact damage
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(PROJECTILE_DAMAGE, "VultureEyeContact")

# ─── DEFEATED ─────────────────────────────────────────────────────────────────
func _on_defeated() -> void:
	beam_active = false
	core_open   = false
	if is_instance_valid(beam_line):
		beam_line.visible = false
	if is_instance_valid(core_area):
		core_area.monitoring = false

	_screen_shake(2.5)
	AudioManager.play_sfx("boss_roar")

	if is_instance_valid(shockwave):
		shockwave.emitting = true

	GameManager.collect_fragment(FRAGMENT_ON_DEFEAT)
	GameManager.collect_lore(LORE_ON_DEFEAT)
	boss_defeated.emit()

	if is_instance_valid(body_sprite):
		body_sprite.play("death")

	await get_tree().create_timer(4.0).timeout
	AudioManager.play_music("surface", 2.0)
	_log("VULTURE-EYE defeated — sector unlocked")

# ─── HELPERS ──────────────────────────────────────────────────────────────────
func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D

func _screen_shake(intensity: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var tween := create_tween()
	var steps := 12
	for i in steps:
		var offset := Vector2(
			randf_range(-intensity * 8, intensity * 8),
			randf_range(-intensity * 8, intensity * 8)
		)
		tween.tween_property(cam, "offset", offset, 0.04)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.1)

func _flash_eye() -> void:
	if not is_instance_valid(eye_sprite):
		return
	var tween := create_tween()
	tween.tween_property(eye_sprite, "modulate", Color.WHITE * 3.0, 0.06)
	tween.tween_property(eye_sprite, "modulate", Color.WHITE, 0.12)

func _update_visuals(_delta: float) -> void:
	if not is_instance_valid(eye_light):
		return
	var flicker := sin(Time.get_ticks_msec() * 0.008) * 0.2
	eye_light.energy += flicker * (2.0 if phase == Phase.OVERLOAD else 1.0)

func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[VultureEyeBoss | F%d] %s" % [_frame_count, msg])
