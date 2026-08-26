@tool
class_name RopeData extends Resource

enum ColShapeType {
    TRIMESH = 0,
    SINGLE_CONVEX = 1,
    SIMPLIFIED_CONVEX = 2,
}

## Points representing the whole path of the rope. 
## Individual meshes between each of the point will be generated.
@export var points: PackedVector3Array:
    set(value):
        points = value
        emit_changed()

## Material used for all of the meshes.
@export var material: Material:
    set(value):
        material = value
        emit_changed()

## The render layer(s) instance(s) will be drawn on.
@export_flags_3d_render var visibility_layers: int = 1:
    set(value):
        visibility_layers = value
        emit_changed()
    
## Instead of creating multiple meshes that can be culled separately, one mesh will be created. 
## Useful if mesh is small enough to fit inside the camera frustum.
@export var single_mesh: bool = true:
    set(value):
        single_mesh = value
        emit_changed()

@export_group("Sag", "sag_")

## How much the rope will sag between the hooks.
@export var sag_offset: Vector3 = Vector3(0.0, -0.1, 0.0):
    set(value):
        sag_offset = value
        emit_changed()

## Keeps the [member sag_offset] in the node's local space
@export var sag_keep_local_space: bool = false:
    set(value):
        sag_keep_local_space = value
        emit_changed()

@export_group("Cylinder extrusion", "ext_")

## Radius of the extruded cylinder ring.
@export var ext_radius: float = 0.5:
    set(value):
        ext_radius = value
        emit_changed()

## Number of edges around the cylinder circumference.
@export var ext_u_segments: int = 16:
    set(value):
        ext_u_segments = value
        emit_changed()

## Number of rings along the cylinder mesh.
@export var ext_v_segments: int = 8:
    set(value):
        ext_v_segments = value
        emit_changed()

@export_subgroup("Texture mapping", "tex_")

## Translation of the texture coordinates in the UV space.
@export var tex_uv_translation: Vector2 = Vector2.ZERO:
    set(value):
        tex_uv_translation = value
        emit_changed()

## The point which around texture UV is rotated. The default is top-left corner. Use (0.5, 0.5) for center.
@export var tex_uv_rotation_origin: Vector2 = Vector2(0.5, 0.5):
    set(value):
        tex_uv_rotation_origin = value
        emit_changed()

## Texture UV rotation in degrees clockwise.
@export_range(-360.0, 360.0) var tex_uv_rotation_angle_degrees: float = 0.0:
    set(value):
        tex_uv_rotation_angle_degrees = value
        emit_changed()

## Scaling of the texture coordinates in the UV space.    
@export var tex_uv_scale: Vector2 = Vector2.ONE:
    set(value):
        tex_uv_scale = value
        emit_changed()

@export_group("Level of detail", "lod_")

## How quickly the mesh will transition into lower LOD versions. 
## Keep it low for very thin geometry (e.g. radius is less than 0.25)
@export_range(0.001, 128.0) var lod_bias: float = 0.02:
    set(value):
        lod_bias = value
        emit_changed()

## Distance at which LOD 1 model will appear
@export var lod_level1_distance: float = 2.0:
    set(value):
        lod_level1_distance = value
        emit_changed()

## Distance at which LOD 2 model will appear
@export var lod_level2_distance: float = 10.0:
    set(value):
        lod_level2_distance = value
        emit_changed()

## Distance at which LOD 3 model will appear
@export var lod_level3_distance: float = 40.0:
    set(value):
        lod_level3_distance = value
        emit_changed()

## If enabled, StaticBody would be generated for each mesh. When [member single_mesh] is set to true,
## single StaticBody would be generated.
@export var use_collisions: bool = false:
    set(value):
        use_collisions = value
        notify_property_list_changed()
        emit_changed()

## Generated collision shape type for the rope's StaticBody. 
var col_shape_type: ColShapeType = ColShapeType.TRIMESH:
    set(value):
        col_shape_type = value
        emit_changed()

## The physics layer this collision object is in.
var col_collision_layer: int = 0:
    set(value):
        col_collision_layer = value
        emit_changed()

## The physics layer this collisoin object scans.
var col_collision_mask: int = 0:
    set(value):
        col_collision_mask = value
        emit_changed()

func _validate_property(property: Dictionary) -> void:
    if property.name in ["col_shape_type", "col_collision_layer", "col_collision_mask"]:
        if not use_collisions:
            property.usage = PROPERTY_USAGE_NO_EDITOR

func _get_property_list() -> Array:
    var properties = []
    
    if use_collisions:
        properties.append({
            "name": "Collision",
            "type": TYPE_NIL,
            "usage": PROPERTY_USAGE_GROUP,
            "hint_string": "col_"
        })

        properties.append({
            "name": "col_shape_type",
            "type": TYPE_INT,
            "hint": PROPERTY_HINT_ENUM,
            "hint_string": "Trimesh:0,Simple Convex:1,Simplified Convex:2",
            "usage": PROPERTY_USAGE_DEFAULT,
            "class_name": "shape_type"
        })

        properties.append({
            "name": "col_collision_layer",
            "type": TYPE_INT,
            "hint": PROPERTY_HINT_LAYERS_3D_PHYSICS,
            "usage": PROPERTY_USAGE_DEFAULT,
            "class_name": "collision_layer"
        })

        properties.append({
            "name": "col_collision_mask",
            "type": TYPE_INT,
            "hint": PROPERTY_HINT_LAYERS_3D_PHYSICS,
            "usage": PROPERTY_USAGE_DEFAULT,
            "class_name": "collision_mask"
        })
    
    return properties