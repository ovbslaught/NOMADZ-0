extends WorldEnvironment

## Swaps the sky material at runtime and points the sun light the same way the swapped
## material does, so shadows keep agreeing with the sun drawn in the sky.
##
##   1 / 2  - sky presets
##
## The scene already carries preset 1 in the saved Environment, so opening the scene in
## the editor shows the finished picture without running anything. This script only adds
## the runtime switch.

@export var presets: Array[ShaderMaterial] = []
@export var sun_path: NodePath


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index := -1
	match event.keycode:
		KEY_1: index = 0
		KEY_2: index = 1
	if index < 0 or index >= presets.size():
		return
	_apply_preset(presets[index])


func _apply_preset(material: ShaderMaterial) -> void:
	environment.sky.sky_material = material

	var sun := get_node_or_null(sun_path) as DirectionalLight3D
	if sun == null:
		return

	# Where the material puts the sun. With sun_follows_light ON the material reads the
	# light instead, so there is nothing to sync and the light is left alone.
	if material.get_shader_parameter("sun_follows_light"):
		return
	var raw: Variant = material.get_shader_parameter("sun_direction_manual")
	if typeof(raw) != TYPE_VECTOR3:
		return
	var toward_sun: Vector3 = raw
	if toward_sun.length() < 0.001:
		return

	# A light shines along its own -Z, so its +Z has to point at the sun.
	sun.look_at_from_position(sun.global_position, sun.global_position - toward_sun, Vector3.UP)
