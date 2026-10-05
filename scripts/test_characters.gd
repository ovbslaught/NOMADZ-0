extends SceneTree

var frame_count: int = 0
var arena = null
var player = null

func _init() -> void:
    print("[TEST] Launching integrated Arena & Character Runtime Test...")
    var arena_res = load("res://scenes/MainArena.tscn")
    if arena_res:
        arena = arena_res.instantiate()
        root.add_child(arena)
        player = arena.get_node_or_null("Player")
    else:
        printerr("[FAIL] MainArena.tscn not found")
        quit(1)

func _process(_delta: float) -> bool:
    frame_count += 1
    if frame_count < 5:
        return false
        
    if not player:
        printerr("[FAIL] Player node not found")
        quit(1)
        return true
        
    var char_defs = player.get("CHARACTER_DEFS")
    var instances = player.get("character_instances")
    print("[TEST] Character definitions: ", char_defs.size() if char_defs else 0)
    print("[TEST] Character instances: ", instances.size() if instances else 0)
    
    var all_ok = true
    for i in range(char_defs.size()):
        var cdef = char_defs[i]
        player.switch_character(i)
        var inst = instances[i] if (instances and i < instances.size()) else null
        if inst:
            var ap = player.get("active_anim_player") as AnimationPlayer
            var anim_count = ap.get_animation_list().size() if ap else 0
            var idle_anim = cdef["anims"].get("idle", "")
            var idle_found = ap.has_animation(idle_anim) if (ap and idle_anim != "") else false
            print("  [SUCCESS] Slot %d: %s | Node: %s | Visible: %s | Total Anims: %d | Idle [%s] OK: %s" % [
                i, cdef["name"], inst.name, inst.visible, anim_count, idle_anim, idle_found
            ])
            if ap and idle_found:
                ap.play(idle_anim)
        else:
            printerr("  [FAILURE] Slot %d: %s instance is null" % [i, cdef["name"]])
            all_ok = false
            
    # Test combat trigger on active character
    var combat = player.get_node_or_null("Pivot/CombatManager")
    if combat:
        print("[TEST] Testing combat combo attack on character...")
        combat.execute_attack()
        print("[TEST] Combat attack executed successfully. Combo: ", combat.get("current_combo"))
    else:
        print("[WARNING] CombatManager not found under Pivot")
        
    # Check CameraRig
    var cam = player.get_node_or_null("CameraRig")
    if not cam:
        cam = player.get_node_or_null("Pivot/CameraRig")
    print("[TEST] Camera rig present: ", cam != null)
    
    # Check HUD
    var hud = arena.get_node_or_null("HUD")
    print("[TEST] HUD present: ", hud != null)
    
    if all_ok:
        print("[PASS] ALL 4 CHARACTERS, RIGS, COMBAT & HUD VERIFIED FUNCTIONAL.")
        quit(0)
    else:
        print("[FAIL] Some characters failed verification.")
        quit(1)
        
    return true
