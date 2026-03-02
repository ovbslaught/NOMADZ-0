# === NEW: DockingManager (attach to SolCharacter root) ===
class DockingManager extends Node:
    @export var dock_speed: float = 2.0
    @export var alignment_threshold: float = 0.05  # meters
    
    signal docked(mech: Node3D)
    signal ejected
    
    var current_mech: Node3D
    var current_socket: Marker3D
    var is_docked: bool = false
    
    func attempt_dock(mech: Node3D):
        if is_docked: return
        var best_socket = find_best_socket(mech)
        if best_socket and alignment_ok(best_socket, mech):
            perform_dock(mech, best_socket)
    
    func find_best_socket(mech: Node3D) -> Marker3D:
        var best_dist = INF
        var best: Marker3D = null
        for s in get_parent().get_children():
            if s.name.begins_with("MechSocket_"):
                var world_pos = s.global_position
                var mech_dock = mech.get_node_or_null("PilotDock")  # mech must have this Marker3D
                if mech_dock:
                    var dist = world_pos.distance_to(mech_dock.global_position)
                    if dist < best_dist:
                        best_dist = dist
                        best = s
        return best
    
    func alignment_ok(my_socket: Marker3D, mech: Node3D) -> bool:
        var target = mech.get_node("PilotDock")
        return my_socket.global_position.distance_to(target.global_position) < alignment_threshold
    
    func perform_dock(mech: Node3D, my_socket: Marker3D):
        current_mech = mech
        current_socket = my_socket
        is_docked = true
        
        # Smooth snap
        var tween = create_tween()
        tween.tween_property(get_parent(), "global_transform", 
            mech.get_node("PilotDock").global_transform * my_socket.transform.inverse(),
            1.0 / dock_speed).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
        
        # Visuals
        spawn_dock_particles(my_socket)
        get_parent().get_node("Hair").visible = false  # helmet stays on in cockpit
        
        # Physics lock (PinJoint3D for rigid feel)
        var joint = PinJoint3D.new()
        joint.node_a = get_parent().get_path()
        joint.node_b = mech.get_path()
        mech.add_child(joint)
        
        docked.emit(mech)
        print("✅ DOCKED to ", mech.name)
    
    func eject():
        if not is_docked: return
        is_docked = false
        # remove joint, lerp out, restore hair if helmet off
        get_parent().get_node("Hair").visible = !get_parent().get_node("Helmet").visible
        ejected.emit()
        print("🚀 EJECTED")

    func spawn_dock_particles(socket: Marker3D):
        var particles = GPUParticles3D.new()
        particles.mesh = SphereMesh.new()
        particles.position = socket.position
        particles.amount = 64
        particles.lifetime = 0.8
        get_parent().add_child(particles)
        await get_tree().create_timer(1.0).timeout
        particles.queue_free()

# In create_sol_character() – attach manager
var docking = DockingManager.new()
root.add_child(docking)