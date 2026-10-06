@tool
extends Node
# osm_to_godot.gd — drop in a Godot editor scene, set city_json path, press Build.
# Reads norfolk_city.json, extrudes voxel buildings, lays roads and water.
# Retro 32-bit look: flat-shaded boxes + neon palette. Runs in editor.
#
# Usage: EditorScene > add this script to a Node, set export vars,
# call build_city() from a toolbar button or _ready() once.

@export var city_json: String = "res://citygen/norfolk_city.json"
@export var voxel_size := 8.0            # meters per voxel column — chunky
@export var meters_per_level := 3.5     # building floor height
@export var neon_chance := 0.35         # fraction of buildings that glow
@export var build_on_ready := false

const PALETTE := [
    Color("0d1b2a"), Color("1b263b"), Color("2c3e50"), Color("415a77"),
    Color("0bceff"), Color("00ff9f"), Color("ff2a6d"), Color("ffd300"),
]

func _ready() -> void:
    if build_on_ready and Engine.is_editor_hint():
        build_city()

func build_city() -> void:
    for c in get_children():
        c.queue_free()
    var f := FileAccess.open(city_json, FileAccess.READ)
    if not f:
        push_error("city json not found: " + city_json)
        return
    var city: Dictionary = JSON.parse_string(f.get_as_text())

    var buildings := Node3D.new(); buildings.name = "Buildings"
    var roads := Node3D.new(); roads.name = "Roads"
    var water := Node3D.new(); water.name = "Water"
    add_child(buildings); add_child(roads); add_child(water)
    buildings.owner = owner; roads.owner = owner; water.owner = owner

    # --- buildings: voxel extrusion ---
    var box := BoxMesh.new()
    box.size = Vector3(voxel_size, 1, voxel_size)
    var count := 0
    for b in city.get("buildings", []):
        var poly: Array = b["poly"]
        if poly.size() < 3:
            continue
        var rect := _bounds(poly)
        var levels := int(b.get("levels", "2"))
        var h := maxf(levels, 1) * meters_per_level
        var cols := maxi(1, int((rect.size.x) / voxel_size))
        var rows := maxi(1, int((rect.size.y) / voxel_size))
        var mi := MultiMeshInstance3D.new()
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = box
        mm.instance_count = cols * rows
        var i := 0
        for cx in cols:
            for cz in rows:
                var px := rect.position.x + (cx + 0.5) * voxel_size
                var pz := rect.position.y + (cz + 0.5) * voxel_size
                if not _point_in_poly(Vector2(px, pz), poly):
                    continue
                var t := Transform3D(Basis().scaled(Vector3(1, h, 1)),
                                     Vector3(px, h * 0.5, pz))
                mm.set_instance_transform(i, t)
                i += 1
        mm.instance_count = i
        mi.multimesh = mm
        mi.material_override = _bldg_material(neon_chance > randf())
        buildings.add_child(mi)
        mi.owner = owner
        count += 1
    print("[CITYGEN] buildings: ", count)

    # --- roads: ribbon strips along the polyline ---
    var road_mat := StandardMaterial3D.new()
    road_mat.albedo_color = Color("151820"); road_mat.roughness = 1.0
    for r in city.get("roads", []):
        var poly: Array = r["poly"]
        var width := 12.0 if r.get("kind") in ["motorway","trunk","primary"] else 7.0
        for j in poly.size() - 1:
            var a := Vector3(poly[j][0], 0.02, poly[j][1])
            var b2 := Vector3(poly[j+1][0], 0.02, poly[j+1][1])
            var len := a.distance_to(b2)
            if len < 0.5: continue
            var m := MeshInstance3D.new()
            var plane := PlaneMesh.new()
            plane.size = Vector2(width, len)
            m.mesh = plane
            m.material_override = road_mat
            m.position = (a + b2) * 0.5
            m.rotation.y = atan2(b2.x - a.x, b2.z - a.z) + PI / 2.0
            m.rotation.x = -PI / 2.0
            roads.add_child(m); m.owner = owner

    # --- water: the harbor/Elizabeth River, emissive teal plane ---
    var wmat := StandardMaterial3D.new()
    wmat.albedo_color = Color("06283d")
    wmat.emission_enabled = true
    wmat.emission = Color("0bceff") * 0.25
    for w in city.get("water", []):
        var poly: Array = w["poly"]
        if poly.size() < 3: continue
        var rect := _bounds(poly)
        var m := MeshInstance3D.new()
        var plane := PlaneMesh.new()
        plane.size = rect.size
        m.mesh = plane
        m.material_override = wmat
        m.position = Vector3(rect.get_center().x, -0.05, rect.get_center().y)
        m.rotation.x = -PI / 2.0
        water.add_child(m); m.owner = owner
    print("[CITYGEN] city built — real Norfolk geometry, voxel skin")

func _bldg_material(neon: bool) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.roughness = 1.0
    mat.albedo_color = PALETTE[randi() % 4]
    if neon:
        mat.emission_enabled = true
        mat.emission = PALETTE[4 + randi() % 4] * 0.8
    return mat

func _bounds(poly: Array) -> Rect2:
    var minp := Vector2(poly[0][0], poly[0][1])
    var maxp := minp
    for p in poly:
        minp = minp.min(Vector2(p[0], p[1]))
        maxp = maxp.max(Vector2(p[0], p[1]))
    return Rect2(minp, maxp - minp)

func _point_in_poly(pt: Vector2, poly: Array) -> bool:
    var inside := false
    var j := poly.size() - 1
    for i in poly.size():
        var a := Vector2(poly[i][0], poly[i][1])
        var b := Vector2(poly[j][0], poly[j][1])
        if ((a.y > pt.y) != (b.y > pt.y)) and \
           (pt.x < (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x):
            inside = not inside
        j = i
    return inside
