extends Resource

# resource that works as central synchronization point for ui controls and gizmo objects, 
# both of which try to reflect its state
var visible_aabbs: bool = false
var visible_collision_shapes: bool = true
var visible_origins: bool = true