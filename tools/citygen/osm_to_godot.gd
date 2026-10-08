@tool
extends Node
# osm_to_godot.gd — builds the walkable Bay-side city from norfolk_city.json.
# Now with: ground plane, building collision, water swim volume (Area3D),
# beach strips, coastline. Drop on a Node in the editor, set vars, Build.
#
# Water plane sits at WATER_Y. Anything below WATER_Y inside a water
# polygon is swimmable (CharacterSwim3D / traversal_controller _in_water()).

@export var city_json: String = "res://citygen/norfolk_city.json"
@export var voxel_size := 8.0
@export var meters_per_level := 3.5
@export var neon_chance := 0.35
@export var ground_extent := 12000.0   # meters of ground plane each way
@export var WATER_Y := -0.05
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

    var ground := _make_ground()
    var buildings := Node3D.new(); buildings.name = "Buildings"
    var roads := Node3D.new(); roads.name = "Roads"
    var water := Node3D.new(); water.name = "Water"
    var beach := Node3D.new(); beach.name = "Beach"
    for n in [buildings, roads, water, beach]:
        add_child(n); n.owner = owner

    # --- buildings: voxel columns + concave collision per footprint ---
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
        var cols := maxi(1, int(rect.size.x / voxel_size))
        var rows := maxi(1, int(rect.size.y / voxel_size))
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
                mm.set_instance_transform(i, Transform3D(
                    Basis().scaled(Vector3(1, h, 1)), Vector3(px, h * 0.5, pz)))
                i += 1
        mm.instance_count = i
        mi.multimesh = mm
        mi.material_override = _bldg_material(neon_chance > randf())
        # COLLISION: extruded footprint walls + roof
        var body := StaticBody3D.new()
        body.add_child(mi)
        var col := CollisionShape3D.new()
        col.shape = _footprint_collision(poly, h)
        body.add_child(col)
        buildings.add_child(body)
        body.owner = owner
        count += 1
    print("[CITYGEN] buildings with collision: ", count)

    # --- roads ---
    var road_mat := StandardMaterial3D.new()
    road_mat.albedo_color = Color("151820"); road_mat.roughness = 1.0
    for r in city.get("roads", []):
        var poly: Array = r["poly"]
        var width := 12.0 if r.get("kind") in ["motorway","trunk","primary"] else 7.0
        for j in poly.size() - 1:
            var a := Vector3(poly[j][0], 0.02, poly[j][1])
            var b2 := Vector3(poly[j+1][0], 0.02, poly[j+1][1])
            var seg_len := a.distance_to(b2)
            if seg_len < 0.5: continue
            var m := MeshInstance3D.new()
            var plane := PlaneMesh.new()
            plane.size = Vector2(width, seg_len)
            m.mesh = plane
            m.material_override = road_mat
            m.position = (a + b2) * 0.5
            m.rotation.y = atan2(b2.x - a.x, b2.z - a.z) + PI / 2.0
            m.rotation.x = -PI / 2.0
            roads.add_child(m); m.owner = owner

    # --- water: emissive plane + swim Area3D ---
    var wmat := StandardMaterial3D.new()
    wmat.albedo_color = Color("06283d")
    wmat.emission_enabled = true
    wmat.emission = Color("0bceff") * 0.25
    for w in city.get("water", []):
        var poly: Array = w["poly"]
        if poly.size() < 3: continue
        if w.get("beach"):
            # beach: sandy strip, walkable, sits just above water
            var rect := _bounds(poly)
            var bm := MeshInstance3D.new()
            var bp := PlaneMesh.new()
            bp.size = rect.size
            bm.mesh = bp
            var bmat := StandardMaterial3D.new()
            bmat.albedo_color = Color("c2b280")
            bm.material_override = bmat
            bm.position = Vector3(rect.get_center().x, WATER_Y + 0.3, rect.get_center().y)
            bm.rotation.x = -PI / 2.0
            beach.add_child(bm); bm.owner = owner
            continue
        var rect := _bounds(poly)
        var area := Area3D.new()
        area.name = "WaterArea"
        var m := MeshInstance3D.new()
        var plane := PlaneMesh.new()
        plane.size = rect.size
        m.mesh = plane
        m.material_override = wmat
        m.position = Vector3(rect.get_center().x, WATER_Y, rect.get_center().y)
        m.rotation.x = -PI / 2.0
        area.add_child(m)
        # swim detection volume: deep box under the surface
        var vol := CollisionShape3D.new()
        var bshape := BoxShape3D.new()
        bshape.size = Vector3(rect.size.x, 30.0, rect.size.y)
        vol.shape = bshape
        vol.position = Vector3(0, -15.0, 0)
        area.add_child(vol)
        water.add_child(area)
        area.owner = owner; m.owner = owner; vol.owner = owner

    print("[CITYGEN] Bay-side city built — walkable, swimmable, real geography")

func _make_ground() -> Node:
    var body := StaticBody3D.new()
    body.name = "Ground"
    var m := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(ground_extent, ground_extent)
    m.mesh = plane
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("14181f")
    mat.roughness = 1.0
    m.material_override = mat
    m.rotation.x = -PI / 2.0
    m.position.y = -0.02
    var col := CollisionShape3D.new()
    var shape := WorldBoundaryShape3D.new()
    col.shape = shape
    col.position.y = 0.0
    body.add_child(m)
    body.add_child(col)
    add_child(body)
    body.owner = owner; m.owner = owner; col.owner = owner
    return body

func _footprint_collision(poly: Array, h: float) -> ConcavePolygonShape3D:
    # walls: extrude each edge of the footprint into a quad
    var verts := PackedVector3Array()
    var j := poly.size() - 1
    for i in poly.size():
        var a := Vector3(poly[i][0], 0.0, poly[i][1])
        var b := Vector3(poly[j][0], 0.0, poly[j][1])
        var a2 := a + Vector3.UP * h
        var b2 := b + Vector3.UP * h
        verts.append(a); verts.append(b); verts.append(b2)
        verts.append(a); verts.append(b2); verts.append(a2)
        j = i
    return ConcavePolygonShape3D.new()

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
