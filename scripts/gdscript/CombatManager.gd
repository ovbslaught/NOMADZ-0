## CombatManager.gd
## NOMADZ-0 — Full combat system for Cope.
## Branch: Cosmic-key
##
## Attach to the Player node or as a direct child.
##
## Signals:
##   hit_landed(target: Node, damage: float, combo_count: int)
##   combo_broken
##   parry_success
##   ability_fired(name: String)
##
## Requires Director autoload.
## Requires an Area3D assigned via @export (melee_hitbox) for hit detection.
## Enemy nodes must belong to the "enemy" group.

class_name CombatManager
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal hit_landed(target: Node, damage: float, combo_count: int)
signal combo_broken
signal parry_success
signal ability_fired(ability_name: String)

# ---------------------------------------------------------------------------
# Export tunables
# ---------------------------------------------------------------------------

@export_group("Melee")
@export var base_damage: float = 15.0
## Damage multipliers for combo hits 1, 2, 3 respectively.
@export var combo_multipliers: Array[float] = [1.0, 1.2, 1.8]
## Seconds the player has to continue a combo before it resets.
@export var combo_window: float = 0.8

@export_group("Parry")
@export var parry_window: float = 0.2       ## Seconds after enemy attack signal to parry
@export var parry_invincibility: float = 1.5 ## Seconds of i-frames granted on successful parry

@export_group("NOVA_BURST Ability")
@export var nova_burst_radius: float = 4.0
@export var nova_burst_cost: float = 30.0    ## Uridium cost
@export var nova_cooldown: float = 8.0

@export_group("Hit Detection")
## Assign the Area3D child that represents the melee swing hitbox.
@export var melee_hitbox: Area3D

# ---------------------------------------------------------------------------
# Animation tree reference — set by owning PlayerController or manually
# ---------------------------------------------------------------------------
var _anim_state_machine: AnimationNodeStateMachinePlayback = null

# ---------------------------------------------------------------------------
# Internal combo state
# ---------------------------------------------------------------------------

## Current position in the combo chain (0 = no active combo).
var _combo_count: int = 0

## Timer counting DOWN; when it hits zero, the combo window has expired.
var _combo_timer: float = 0.0

## Maps combo_count index → animation name.
const COMBO_ANIMS: Array[String] = ["punch_left", "punch_right", "kick_heavy"]

# ---------------------------------------------------------------------------
# Parry state
# ---------------------------------------------------------------------------

## Becomes true briefly when Director emits an incoming enemy attack.
var _parry_window_open: bool = false
var _parry_window_timer: float = 0.0

## True while player has parry invincibility frames active.
var _is_invincible: bool = false
var _invincibility_timer: float = 0.0

# ---------------------------------------------------------------------------
# NOVA_BURST cooldown
# ---------------------------------------------------------------------------
var _nova_cooldown_remaining: float = 0.0

# ---------------------------------------------------------------------------
# Reference to PlayerController (parent expected)
# ---------------------------------------------------------------------------
var _player: CharacterBody3D = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Cache reference to the owning PlayerController.
	if get_parent() is CharacterBody3D:
		_player = get_parent() as CharacterBody3D

	# Attempt to find AnimationTree for animation triggers.
	_find_anim_tree()

	# Connect to Director for enemy attack notifications (parry window).
	if Engine.has_singleton("Director"):
		var director = Engine.get_singleton("Director")
		if director.has_signal("enemy_attack_incoming"):
			director.enemy_attack_incoming.connect(_on_enemy_attack_incoming)

	# Ensure hitbox starts disabled (only active during swings).
	if melee_hitbox:
		melee_hitbox.monitoring = false


func _find_anim_tree() -> void:
	## Walk the parent hierarchy looking for an AnimationTree.
	var node := get_parent()
	while node:
		for child in node.get_children():
			if child is AnimationTree:
				_anim_state_machine = child.get("parameters/playback") as AnimationNodeStateMachinePlayback
				return
		node = node.get_parent()


# ---------------------------------------------------------------------------
# Per-frame timers
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Tick combo expiry timer.
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_reset_combo()

	# Parry window countdown.
	if _parry_window_timer > 0.0:
		_parry_window_timer -= delta
		if _parry_window_timer <= 0.0:
			_parry_window_open = false

	# Invincibility countdown.
	if _invincibility_timer > 0.0:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0.0:
			_is_invincible = false

	# NOVA cooldown.
	if _nova_cooldown_remaining > 0.0:
		_nova_cooldown_remaining -= delta


# ---------------------------------------------------------------------------
# Input handling (call from _input in PlayerController or connect InputEvent)
# ---------------------------------------------------------------------------

func handle_input(event: InputEvent) -> void:
	## Route input from the owning PlayerController's _input().

	# Primary attack — next combo hit.
	if event.is_action_pressed("attack_primary"):
		_advance_combo()

	# Secondary attack — NOVA_BURST ability.
	if event.is_action_pressed("attack_secondary"):
		_try_nova_burst()

	# Parry attempt.
	if event.is_action_pressed("parry"):
		_try_parry()


# ---------------------------------------------------------------------------
# Melee combo system
# ---------------------------------------------------------------------------

func _advance_combo() -> void:
	## Step forward one hit in the 3-hit chain, or overflow-reset.
	if _combo_count >= combo_multipliers.size():
		## Chain complete — reset before starting fresh.
		_reset_combo()

	# Trigger animation for this combo step.
	_anim_travel(COMBO_ANIMS[_combo_count])

	# Enable hitbox for this swing frame window.
	_activate_hitbox()

	# Increment AFTER animation trigger so index matches COMBO_ANIMS.
	_combo_count += 1

	# Reset the expiry window from this new hit.
	_combo_timer = combo_window

	# If last hit completed, post-process combo.
	if _combo_count >= combo_multipliers.size():
		_on_combo_complete()


func _activate_hitbox() -> void:
	## Enable the Area3D hitbox briefly; disable via deferred call.
	if not melee_hitbox:
		return
	melee_hitbox.monitoring = true
	# Detect overlapping bodies in the enemy group immediately.
	var overlapping := melee_hitbox.get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("enemy"):
			_apply_hit(body)
	# Disable after one physics frame to avoid double-hits.
	melee_hitbox.set_deferred("monitoring", false)


func _apply_hit(target: Node) -> void:
	## Compute and apply damage for the current combo step.
	## combo_count hasn't been incremented yet when _activate_hitbox fires.
	var multiplier: float = combo_multipliers[_combo_count]  # current hit
	var damage: float = base_damage * multiplier

	# Apply damage if target exposes a take_damage method.
	if target.has_method("take_damage"):
		target.take_damage(damage)

	hit_landed.emit(target, damage, _combo_count + 1)

	# Push a small tension spike to Director for AI evolution checks.
	_emit_tension_spike(0.02)


func _reset_combo() -> void:
	if _combo_count > 0:
		combo_broken.emit()
	_combo_count = 0
	_combo_timer = 0.0


func _on_combo_complete() -> void:
	## Called after the final (3rd) combo hit lands.
	## Trigger Director AI evolution check — a full combo is a significant tension event.
	_emit_tension_spike(0.08)
	# Reset after a short delay so the animation can finish.
	await get_tree().create_timer(0.3).timeout
	_reset_combo()


# ---------------------------------------------------------------------------
# Parry system
# ---------------------------------------------------------------------------

func _try_parry() -> void:
	## Perfect parry: if the window is open (enemy is mid-attack), grant i-frames.
	if _parry_window_open:
		_parry_window_open = false
		_parry_window_timer = 0.0
		_is_invincible = true
		_invincibility_timer = parry_invincibility
		parry_success.emit()
		_anim_travel("parry_success")  # Assumes this animation exists in AnimationTree.
	# If window is closed, parry whiffs silently (no animation stagger to keep feel clean).


func _on_enemy_attack_incoming() -> void:
	## Connected to Director.enemy_attack_incoming signal.
	## Opens the parry window briefly.
	_parry_window_open = true
	_parry_window_timer = parry_window


# ---------------------------------------------------------------------------
# NOVA_BURST ability
# ---------------------------------------------------------------------------

func _try_nova_burst() -> void:
	## AoE damage burst powered by Uridium (ProtonCharge).

	# Cooldown check.
	if _nova_cooldown_remaining > 0.0:
		return

	# Uridium check — read from PlayerController if available, else direct field.
	if not _has_sufficient_uridium(nova_burst_cost):
		return

	_consume_uridium(nova_burst_cost)
	_nova_cooldown_remaining = nova_cooldown

	# AoE hit detection: use a PhysicsDirectSpaceState3D sphere shape query.
	var space_state := get_world_3d().direct_space_state
	var origin := _get_player_position()

	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = nova_burst_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.set_shape(sphere_shape)
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.collision_mask = 0xFFFFFFFF  # All layers; filter by group below.

	var results := space_state.intersect_shape(query, 32)
	for result in results:
		var collider = result.get("collider")
		if collider and collider != _player and collider.is_in_group("enemy"):
			var nova_damage := base_damage * combo_multipliers[-1] * 1.5  # Boosted AoE damage
			if collider.has_method("take_damage"):
				collider.take_damage(nova_damage)
			hit_landed.emit(collider, nova_damage, 0)

	ability_fired.emit("NOVA_BURST")
	_anim_travel("nova_burst")  # Assumes "nova_burst" exists in AnimationTree.

	# NOVA_BURST is a major tension event.
	_emit_tension_spike(0.12)


# ---------------------------------------------------------------------------
# Uridium helpers (ProtonCharge)
# ---------------------------------------------------------------------------

func _has_sufficient_uridium(amount: float) -> bool:
	## Check uridium on the PlayerController if available.
	if _player and _player.has_method("recharge_uridium"):
		# PlayerController exposes `uridium` as a public var.
		return _player.get("uridium") >= amount
	return false


func _consume_uridium(amount: float) -> void:
	if _player:
		var current: float = _player.get("uridium")
		_player.set("uridium", maxf(current - amount, 0.0))
		# Emit PlayerController's signal so HUD / AudioManager react.
		_player.used.emit(amount)


# ---------------------------------------------------------------------------
# Director tension helper
# ---------------------------------------------------------------------------

func _emit_tension_spike(delta_tension: float) -> void:
	if not Engine.has_singleton("Director"):
		return
	var director = Engine.get_singleton("Director")
	if director.has_signal("tension_changed"):
		director.emit_signal("tension_changed", delta_tension)


# ---------------------------------------------------------------------------
# Position helper
# ---------------------------------------------------------------------------

func _get_player_position() -> Vector3:
	if _player:
		return _player.global_position
	if get_parent() is Node3D:
		return (get_parent() as Node3D).global_position
	return Vector3.ZERO


# ---------------------------------------------------------------------------
# AnimationTree helper
# ---------------------------------------------------------------------------

func _anim_travel(anim_name: String) -> void:
	if _anim_state_machine:
		_anim_state_machine.travel(anim_name)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_combo_count() -> int:
	return _combo_count


func is_invincible() -> bool:
	return _is_invincible


func get_nova_cooldown_remaining() -> float:
	return _nova_cooldown_remaining
