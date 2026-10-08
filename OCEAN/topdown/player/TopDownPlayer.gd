class_name TopDownPlayer
extends CharacterBody2D

signal sword_swung(direction: Vector2, origin: Vector2)
signal arrow_shot(direction: Vector2, origin: Vector2)
signal spell_cast(spell_id: String, direction: Vector2, origin: Vector2)
signal item_used(item_id: String)

const WALK_SPEED := 160.0
const RUN_SPEED := 260.0
const ACCELERATION := 1500.0
const FRICTION := 1000.0
const SWORD_COOLDOWN := 0.35
const ARROW_COOLDOWN := 0.5
const SWORD_RANGE := 28.0
const SWORD_ARC := 90.0
const ROLL_SPEED := 400.0
const ROLL_DURATION := 0.3
const ROLL_COOLDOWN := 0.8
const INVINCIBILITY_TIME := 1.0

enum Dir { DOWN, LEFT, RIGHT, UP }
enum Weapon { SWORD, BOW, SPELL_FIRE, SPELL_ICE, SPELL_LIGHTNING }

@export var max_health := 8
@export var max_magic := 100

@onready var sprite := $AnimatedSprite2D
@onready var collision := $CollisionShape2D
@onready var sword_hitbox := $SwordHitbox
@onready var shoot_origin := $ShootOrigin
@onready var sword_timer := $SwordTimer
@onready var arrow_timer := $ArrowTimer
@onready var roll_timer := $RollTimer
@onready var roll_cd_timer := $RollCooldownTimer
@onready var invincibility_timer := $InvincibilityTimer
@onready var animation_player := $AnimationPlayer

var health: int = max_health
var magic: int = max_magic
var current_weapon: Weapon = Weapon.SWORD
var facing_dir: Dir = Dir.DOWN
var is_attacking := false
var is_rolling := false
var is_invincible := false
var has_bow := false
var has_spell_fire := false
var has_spell_ice := false
var has_spell_lightning := false
var keys: int = 0
var rupees: int = 0

var _frame_count := 0

func _ready() -> void:
	_validate_nodes()
	_setup_timers()
	health = max_health
	GameManager.current_health = max_health * 12
	GameManager.MAX_HEALTH = max_health * 12

func _validate_nodes() -> void:
	if not is_instance_valid(sprite):
		push_error("TopDownPlayer: AnimatedSprite2D missing")
	if not is_instance_valid(sword_hitbox):
		push_error("TopDownPlayer: SwordHitbox area missing")
	sword_hitbox.get_node("CollisionShape2D").disabled = true

func _setup_timers() -> void:
	_ensure_timer("SwordTimer", SWORD_COOLDOWN, true)
	_ensure_timer("ArrowTimer", ARROW_COOLDOWN, true)
	_ensure_timer("RollTimer", ROLL_DURATION, true)
	_ensure_timer("RollCooldownTimer", ROLL_COOLDOWN, true)
	_ensure_timer("InvincibilityTimer", INVINCIBILITY_TIME, true)
	if has_node("SwordTimer"):
		$SwordTimer.timeout.connect(func(): is_attacking = false)
	if has_node("RollTimer"):
		$RollTimer.timeout.connect(_on_roll_ended)
	if has_node("InvincibilityTimer"):
		$InvincibilityTimer.timeout.connect(func(): is_invincible = false)

func _ensure_timer(name: String, wait: float, one_shot: bool) -> void:
	if not has_node(name):
		var t := Timer.new()
		t.name = name
		t.wait_time = wait
		t.one_shot = one_shot
		add_child(t)

func _unhandled_input(event: InputEvent) -> void:
	if is_rolling or GameManager.is_paused or GameManager.is_cutscene:
		return
	if event.is_action_pressed("shoot"):
		_try_attack()
	if event.is_action_pressed("signal_pulse"):
		_cycle_weapon()
	if event.is_action_pressed("dash"):
		_try_roll()
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("jetpack"):
		_use_item()

func _physics_process(delta: float) -> void:
	if is_rolling:
		move_and_slide()
		return
	_frame_count += 1
	_handle_movement(delta)
	_update_facing()
	move_and_slide()
	_update_animation()

func _handle_movement(delta: float) -> void:
	var input_dir := Vector2(ProControllerManager.get_controller_input("move_right") - ProControllerManager.get_controller_input("move_left"), ProControllerManager.get_controller_input("move_back") - ProControllerManager.get_controller_input("move_forward"))
	var speed := RUN_SPEED if ProControllerManager.get_controller_input("sprint") > 0.5 else WALK_SPEED
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * speed, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

func _update_facing() -> void:
	var input_dir := Vector2(ProControllerManager.get_controller_input("move_right") - ProControllerManager.get_controller_input("move_left"), ProControllerManager.get_controller_input("move_back") - ProControllerManager.get_controller_input("move_forward"))
	if input_dir == Vector2.ZERO:
		return
	if absf(input_dir.x) > absf(input_dir.y):
		facing_dir = Dir.RIGHT if input_dir.x > 0 else Dir.LEFT
	else:
		facing_dir = Dir.DOWN if input_dir.y > 0 else Dir.UP

func _try_attack() -> void:
	if is_attacking:
		return
	match current_weapon:
		Weapon.SWORD:
			if not $SwordTimer.is_stopped():
				return
			_swing_sword()
		Weapon.BOW:
			if not has_bow or not $ArrowTimer.is_stopped():
				return
			_shoot_arrow()
		Weapon.SPELL_FIRE, Weapon.SPELL_ICE, Weapon.SPELL_LIGHTNING:
			_cast_spell()

func _swing_sword() -> void:
	is_attacking = true
	$SwordTimer.start()
	var dir_vec := _dir_to_vec()
	sword_hitbox.global_position = shoot_origin.global_position + dir_vec * 16
	_update_sword_rotation(dir_vec)
	sword_hitbox.get_node("CollisionShape2D").disabled = false
	sword_swung.emit(dir_vec, shoot_origin.global_position)
	AudioManager.play_sfx("melee")
	var tween := create_tween()
	tween.tween_callback(func(): sword_hitbox.get_node("CollisionShape2D").disabled = true).set_delay(0.15)

func _update_sword_rotation(dir: Vector2) -> void:
	var angle := rad_to_deg(dir.angle())
	if facing_dir == Dir.DOWN:
		sword_hitbox.rotation_degrees = 0
	elif facing_dir == Dir.UP:
		sword_hitbox.rotation_degrees = 180
	elif facing_dir == Dir.RIGHT:
		sword_hitbox.rotation_degrees = 90
	elif facing_dir == Dir.LEFT:
		sword_hitbox.rotation_degrees = -90

func _shoot_arrow() -> void:
	is_attacking = true
	$ArrowTimer.start()
	var dir_vec := _dir_to_vec()
	arrow_shot.emit(dir_vec, shoot_origin.global_position)
	AudioManager.play_sfx("shoot")
	await get_tree().create_timer(0.1).timeout
	is_attacking = false

func _cast_spell() -> void:
	var spell_id := ""
	match current_weapon:
		Weapon.SPELL_FIRE:
			if not has_spell_fire or magic < 15: return
			spell_id = "fire"
			magic -= 15
		Weapon.SPELL_ICE:
			if not has_spell_ice or magic < 20: return
			spell_id = "ice"
			magic -= 20
		Weapon.SPELL_LIGHTNING:
			if not has_spell_lightning or magic < 30: return
			spell_id = "lightning"
			magic -= 30
	if spell_id.is_empty():
		return
	is_attacking = true
	var dir_vec := _dir_to_vec()
	spell_cast.emit(spell_id, dir_vec, shoot_origin.global_position)
	AudioManager.play_sfx("signal_pulse")
	await get_tree().create_timer(0.2).timeout
	is_attacking = false

func _cycle_weapon() -> void:
	var weapons := [Weapon.SWORD]
	if has_bow: weapons.append(Weapon.BOW)
	if has_spell_fire: weapons.append(Weapon.SPELL_FIRE)
	if has_spell_ice: weapons.append(Weapon.SPELL_ICE)
	if has_spell_lightning: weapons.append(Weapon.SPELL_LIGHTNING)
	var idx := weapons.find(current_weapon)
	current_weapon = weapons[(idx + 1) % weapons.size()]

func _try_roll() -> void:
	if is_rolling or not $RollCooldownTimer.is_stopped():
		return
	is_rolling = true
	var dir := Vector2(ProControllerManager.get_controller_input("move_right") - ProControllerManager.get_controller_input("move_left"), ProControllerManager.get_controller_input("move_back") - ProControllerManager.get_controller_input("move_forward"))
	if dir == Vector2.ZERO:
		dir = _dir_to_vec()
	velocity = dir * ROLL_SPEED
	$RollTimer.start()
	$RollCooldownTimer.start()
	is_invincible = true
	AudioManager.play_sfx("dash")

func _on_roll_ended() -> void:
	is_rolling = false
	is_invincible = false

func _try_interact() -> void:
	var interactables := get_tree().get_nodes_in_group("interactable")
	for node in interactables:
		if not node is Node2D: continue
		if global_position.distance_to((node as Node2D).global_position) < 48.0:
			if node.has_method("on_interact"):
				node.on_interact(self)
			break

func _use_item() -> void:
	item_used.emit("")

func _dir_to_vec() -> Vector2:
	match facing_dir:
		Dir.DOWN: return Vector2(0, 1)
		Dir.UP: return Vector2(0, -1)
		Dir.RIGHT: return Vector2(1, 0)
		Dir.LEFT: return Vector2(-1, 0)
	return Vector2(0, 1)

func _update_animation() -> void:
	if not is_instance_valid(sprite):
		return
	var anim := "idle_"
	match facing_dir:
		Dir.DOWN: anim += "down"
		Dir.UP: anim += "up"
		Dir.RIGHT: anim += "right"
		Dir.LEFT: anim += "left"
	if is_attacking:
		anim = "sword_" + anim.split("_")[1]
	elif absf(velocity.length()) > 10:
		anim = "walk_" + anim.split("_")[1]
	sprite.play(anim)

func take_damage(amount: int, source: String = "unknown") -> void:
	if is_invincible: return
	is_invincible = true
	$InvincibilityTimer.start()
	health = max(0, health - amount)
	GameManager.current_health = health * 12
	GameManager.health_changed.emit(GameManager.current_health, GameManager.MAX_HEALTH)
	var tween := create_tween()
	for i in 4:
		tween.tween_property(sprite, "modulate:a", 0.2, 0.08)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.08)
	if health <= 0:
		GameManager.player_died.emit()

func heal(amount: int) -> void:
	health = min(max_health, health + amount)
	GameManager.current_health = health * 12
	GameManager.health_changed.emit(GameManager.current_health, GameManager.MAX_HEALTH)

func add_magic(amount: int) -> void:
	magic = min(max_magic, magic + amount)

func equip_bow() -> void: has_bow = true
func equip_spell_fire() -> void: has_spell_fire = true
func equip_spell_ice() -> void: has_spell_ice = true
func equip_spell_lightning() -> void: has_spell_lightning = true
func add_key() -> void: keys += 1
func add_rupees(amount: int) -> void: rupees += amount

func get_debug_snapshot() -> Dictionary:
	return {
		"pos": str(global_position),
		"hp": "%d/%d" % [health, max_health],
		"magic": "%d/%d" % [magic, max_magic],
		"weapon": ["SWORD","BOW","FIRE","ICE","LIGHTNING"][current_weapon],
		"facing": ["DOWN","LEFT","RIGHT","UP"][facing_dir],
		"rupees": rupees,
		"keys": keys,
	}
