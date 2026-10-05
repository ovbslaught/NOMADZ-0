extends CharacterBody3D

@export var max_health: float = 100.0
var health: float = 100.0

@onready var hurt_box: Area3D = $HurtBox
@onready var mesh_inst: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
    health = max_health
    if hurt_box:
        hurt_box.area_entered.connect(self._on_hurt_box_area_entered)

func _on_hurt_box_area_entered(area: Area3D) -> void:
    take_damage(25.0)

func take_damage(amount: float) -> void:
    health = max(0.0, health - amount)
    print("[DUMMY] Hit taken! HP remaining: ", health)
    
    if mesh_inst:
        var mat = mesh_inst.get_active_material(0)
        if mat is StandardMaterial3D:
            var orig_color = mat.albedo_color
            mat.albedo_color = Color(1.0, 0.2, 0.2, 1.0)
            var t = create_tween()
            t.tween_property(mat, "albedo_color", orig_color, 0.2)
            
    if health <= 0:
        health = max_health
        print("[DUMMY] Resetting dummy health to full.")
