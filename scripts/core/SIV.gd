# SIV.gd - Attach to root of city.tscn. F5 = civs spawn on your models
extends Node3D
@tool

func _ready():
    print("SIV: NOMADZ-0 city loaded from /storage/emulated/0/DROIDHOLE/NOMADZ-0")
    print("Scene children: ", get_children().size())
    
    # Hook your half-ass city models (scans scene)
    var models = []
    for child in get_children():
        if child.has_method("get_class") and ("MeshInstance3D" in child.get_class() or ".glb" in str(child)):
            models.append(child)
            print("Found model: ", child.name)
    
    # Spawn civs ON your models
    for i in range(min(10, models.size())):
        var civ = CharacterBody3D.new()
        var model = models[i].duplicate()
        civ.add_child(model)
        civ.position = Vector3(i*5, 0, 0)  # Line near city center
        add_child(civ)
        print("Civ ", i, " spawned with model: ", model.name)
    
    # Your existing scripts auto-run (hooks)
    print("SIV rolling - universe building...")