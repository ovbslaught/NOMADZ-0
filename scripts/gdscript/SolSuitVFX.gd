# SolSuitVFX.gd - Visual effects for the Sol energy suit
extends Node3D

@export var suit_color: Color = Color(0.2, 0.8, 1.0)
@export var glow_intensity: float = 1.5
@export var particle_count: int = 64

@onready var particles: GPUParticles3D = $SolParticles
@onready var suit_mesh: MeshInstance3D = $SuitMesh
@onready var aura_light: OmniLight3D = $AuraLight

var active: bool = false

func _ready():
    _configure_suit()

func _configure_suit() -> void:
    if suit_mesh and suit_mesh.get_surface_override_material_count() > 0:
        var mat = suit_mesh.get_surface_override_material(0)
        if mat:
            mat.albedo_color = suit_color
            mat.emission = suit_color
            mat.emission_energy_multiplier = glow_intensity
    if aura_light:
        aura_light.light_color = suit_color
        aura_light.light_energy = glow_intensity

func activate_suit() -> void:
    active = true
    particles.emitting = true
    var tween = create_tween()
    tween.tween_property(aura_light, "light_energy", glow_intensity * 2.0, 0.5)

func deactivate_suit() -> void:
    active = false
    particles.emitting = false
    var tween = create_tween()
    tween.tween_property(aura_light, "light_energy", 0.0, 0.5)
