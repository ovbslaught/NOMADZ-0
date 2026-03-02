@tool
extends EditorScript

func _run():
    var character = create_sol_character()
    var scene = PackedScene.new()
    scene.pack(character)
    ResourceSaver.save(scene, "res://scenes/sol_character.tscn")
    print("✅ NOMADZ SolCharacter deployed: sol_character.tscn")

func create_sol_character() -> Node3D:
    var root = Node3D.new()
    root.name = "SolCharacter"
    
    # Base Body (under suit)
    var body = create_body_mesh()
    root.add_child(body)
    
    # Suit (original upgraded)
    var suit = create_nomadz_suit()
    root.add_child(suit)
    
    # Hair Group (mid-length messy brown)
    var hair = create_messy_hair()
    hair.name = "Hair"
    root.add_child(hair)
    
    # Helmet (toggleable)
    var helmet = create_helmet_mesh()
    helmet.name = "Helmet"
    root.add_child(helmet)
    
    # Mech Docking Sockets (exosuit → mech plug)
    add_mech_sockets(root)
    
    # Full Skeleton + Rig
    var skeleton = create_full_rig()
    root.add_child(skeleton)
    
    # Toggle script attachment
    var controller = CharacterController.new()
    root.add_child(controller)
    
    return root

# === BODY ===
func create_body_mesh() -> MeshInstance3D:
    var mi = MeshInstance3D.new()
    mi.name = "Body"
    mi.mesh = CapsuleMesh.new()
    mi.mesh.height = 1.8
    mi.mesh.radius = 0.35
    mi.position = Vector3(0, 0.9, 0)
    add_material(mi, Color("#D2B48C"))  # skin tone
    return mi

# === HAIR (12 procedural messy strands) ===
func create_messy_hair() -> Node3D:
    var group = Node3D.new()
    var color = Color("#4A2C0B")  # mid-brown
    for i in 12:
        var strand = MeshInstance3D.new()
        strand.mesh = CylinderMesh.new()
        strand.mesh.top_radius = 0.015
        strand.mesh.bottom_radius = 0.008
        strand.mesh.height = 0.45  # mid-length
        strand.position = Vector3(
            0.12 * sin(i * TAU / 12),
            1.65,
            0.12 * cos(i * TAU / 12)
        )
        strand.rotation_degrees = Vector3(
            randf_range(-25, 25),
            i * 30,
            randf_range(-15, 15)
        )
        add_material(strand, color)
        group.add_child(strand)
    return group

# === HELMET (toggle hides hair) ===
func create_helmet_mesh() -> MeshInstance3D:
    var mi = MeshInstance3D.new()
    mi.mesh = create_cowl_mesh()  # reuse + upgrade from doc
    mi.position = Vector3(0, 1.45, 0)
    add_material(mi, Color("#8B7355"))
    return mi

# === MECH SOCKETS ===
func add_mech_sockets(root: Node3D):
    var sockets = ["Spine", "Back", "LeftShoulder", "RightShoulder", "LeftHip", "RightHip"]
    for s in sockets:
        var dock = Marker3D.new()
        dock.name = "MechSocket_" + s
        match s:
            "Spine": dock.position = Vector3(0, 1.0, -0.4)
            "Back": dock.position = Vector3(0, 1.2, -0.5)
            "LeftShoulder": dock.position = Vector3(-0.6, 1.3, 0); dock.rotation_degrees.y = 90
            "RightShoulder": dock.position = Vector3(0.6, 1.3, 0); dock.rotation_degrees.y = -90
            "LeftHip": dock.position = Vector3(-0.3, 0.6, -0.3)
            "RightHip": dock.position = Vector3(0.3, 0.6, -0.3)
        root.add_child(dock)

# === RIG + CONTROLLER (toggle + plug) ===
class CharacterController extends Node:
    @export var helmet_on: bool = true
    var hair: Node3D
    var helmet: Node3D
    
    func _ready():
        hair = get_parent().get_node("Hair")
        helmet = get_parent().get_node("Helmet")
        update_helmet()
    
    func update_helmet():
        helmet.visible = helmet_on
        hair.visible = !helmet_on
    
    func toggle_helmet():
        helmet_on = !helmet_on
        update_helmet()
    
    # Mech plug example
    func plug_into_mech(mech_socket: Marker3D):
        var my_socket = get_parent().get_node("MechSocket_Spine")
        get_parent().global_transform = mech_socket.global_transform * my_socket.transform.inverse()

# (Keep original suit, cowl, materials, rig functions from previous doc – upgraded vertex count 64 slices, proper normals)