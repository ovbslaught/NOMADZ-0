extends Node3D
func _ready():
    print("SIV: Loading your city/models...")
    spawn_10_civs_near_city()
func spawn_10_civs_near_city():
    for i in 10:
        var civ = CharacterBody3D.new()
        civ.position = Vector3(i*10,0,0)  # Near your half-city
        $City.get_children()[i%get_child_count()].reparent(civ)  # Grab your models!
        add_child(civ)
        print("Civ ",i," rigged + spawned")