## PlayerShaderController.gd
## Node — NOMADZ: Signal Descent
## Bridges Player state (fuel, signal, damage, jetpack) to player_glow.gdshader.
## Attach as child of Player. Auto-finds AnimatedSprite2D material.
## VultureCode / Sol / NOMADZ Universe

class_name PlayerShaderController
extends Node

@onready var _sprite : AnimatedSprite2D = null
var _mat             : ShaderMaterial   = null
var _damage_flash    : float            = 0.0
var _player          : Node             = null

func _ready() -> void:
	_player = get_parent()
	_sprite = _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	if not is_instance_valid(_sprite):
		push_warning("PlayerShaderController: AnimatedSprite2D not found")
		return

	if _sprite.material is ShaderMaterial:
		_mat = _sprite.material as ShaderMaterial
	else:
		push_warning("PlayerShaderController: No ShaderMaterial on sprite — assign player_glow.gdshader")
		return

	_connect_signals()

func _connect_signals() -> void:
	GameManager.fuel_changed.connect(_on_fuel_changed)
	GameManager.signal_meter_changed.connect(_on_signal_changed)
	if _player.has_signal("damaged"):
		_player.damaged.connect(_on_damaged)
	if _player.has_signal("jetpack_activated"):
		_player.jetpack_activated.connect(_on_jetpack_on)
	if _player.has_signal("jetpack_deactivated"):
		_player.jetpack_deactivated.connect(_on_jetpack_off)
	SignalverseManager.corruption_level_changed.connect(_on_corruption_changed)

func _process(delta: float) -> void:
	if _mat == null:
		return
	## Decay damage flash
	_damage_flash = maxf(0.0, _damage_flash - delta * 3.5)
	_mat.set_shader_parameter("damage_flash", _damage_flash)

func _on_fuel_changed(current: float, maximum: float) -> void:
	if _mat:
		_mat.set_shader_parameter("fuel_level", current / maximum)

func _on_signal_changed(value: float) -> void:
	if _mat:
		_mat.set_shader_parameter("signal_level", value / GameManager.MAX_SIGNAL)

func _on_damaged(_amount: int) -> void:
	_damage_flash = 1.0

func _on_jetpack_on() -> void:
	if _mat:
		_mat.set_shader_parameter("jetpack_active", 1.0)

func _on_jetpack_off() -> void:
	if _mat:
		_mat.set_shader_parameter("jetpack_active", 0.0)

func _on_corruption_changed(level: float) -> void:
	if _mat:
		_mat.set_shader_parameter("corruption", level / 100.0)
