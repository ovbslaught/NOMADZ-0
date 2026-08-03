extends Area3D
class_name OceanMatrix

@export_group("Fluid Dynamics")
@export var fluid_density: float = 1024.0
@export var linear_drag: float = 4.0
@export var angular_drag: float = 2.0
@export var gravity_multiplier: float = 0.2 # Simulates buoyancy

func _ready() -> void:
    # Override standard physics for anything entering this volume
    gravity_space_override = Area3D.SPACE_OVERRIDE_COMBINE
    gravity_point_center = Vector3.DOWN
    gravity = 9.8 * gravity_multiplier
    
    linear_damp_space_override = Area3D.SPACE_OVERRIDE_COMBINE
    linear_damp = linear_drag
    
    angular_damp_space_override = Area3D.SPACE_OVERRIDE_COMBINE
    angular_damp = angular_drag
    
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    print("[OCEAN MATRIX] Hydrodynamic volume initialized. Density: ", fluid_density)

func _on_body_entered(body: Node3D) -> void:
    if body.has_method("get_class") and body is PlayerController:
        body.state = body.MovementState.SWIMMING
        print("[OCEAN MATRIX] Player submerged. Switching to hydro-propulsion.")
        
        # Notify the Director of the biome change
        if Engine.has_singleton("Director"):
            Engine.get_singleton("Director").report_event("biome_entered", {"biome_id": "OceanMatrix"})
            
        # Toggle underwater visuals (calls down to the HUD/FX layer)
        get_tree().call_group("HUD", "toggle_ocean_fx", true)

func _on_body_exited(body: Node3D) -> void:
    if body.has_method("get_class") and body is PlayerController:
        body.state = body.MovementState.WALKING
        print("[OCEAN MATRIX] Player breached surface.")
        get_tree().call_group("HUD", "toggle_ocean_fx", false)
