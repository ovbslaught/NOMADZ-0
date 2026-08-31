## GravityZone.gd
## Area2D — NOMADZ: Signal Descent
## GRAVITY ELSEWORLD: variable/inverted gravity zone triggered by bleed.
## Place in rooms with high Signalverse concentration.
## Player's double jump ability further exploits this zone.
## VultureCode / Sol / NOMADZ Universe

class_name GravityZone
extends Area2D

@export var gravity_multiplier : float = -0.5    ## Negative = anti-grav, 0 = float
@export var zone_color         : Color = Color(0.5, 0.2, 1.0, 0.3)
@export var flicker_rate       : float = 3.0      ## Visual instability

@onready var zone_rect  : ColorRect    = $ZoneRect
@onready var zone_light : PointLight2D = $ZoneLight

const DEBUG_MODE := false

var _players_inside : Array[Node2D] = []
var _time           : float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if is_instance_valid(zone_rect):
		zone_rect.color = zone_color

	if is_instance_valid(zone_light):
		zone_light.color  = Color(0.5, 0.2, 1.0)
		zone_light.energy = 0.6

func _process(delta: float) -> void:
	_time += delta

	## Apply modified gravity to players inside
	for player in _players_inside:
		if not is_instance_valid(player):
			continue
		## Override gravity by adding counter-force to velocity
		if player.has_method("get") and player.get("velocity") != null:
			var vel : Vector2 = player.velocity
			## Suppress downward pull, add upward
			var zone_effect := 980.0 * (1.0 - gravity_multiplier) * delta
			vel.y -= zone_effect
			player.set("velocity", vel)

	## Visual flicker tied to corruption
	var flicker := sin(_time * flicker_rate) * 0.15
	if is_instance_valid(zone_rect):
		var c := zone_color
		c.a = zone_color.a + flicker * SignalverseManager.corruption_level / 100.0
		zone_rect.color = c

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not body in _players_inside:
		_players_inside.append(body)
		SignalverseManager.force_bleed("visual_glitch")
		if DEBUG_MODE:
			print("[GravityZone] Player entered | mult: %.2f" % gravity_multiplier)

func _on_body_exited(body: Node2D) -> void:
	_players_inside.erase(body)
