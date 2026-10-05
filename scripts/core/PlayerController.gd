extends CharacterBody3D
class_name PlayerController

enum MovementState { WALKING, RUNNING, CROUCHING, SWIMMING, FLYING, DRIVING, JUMPING, DASHING }

signal health_changed(current_health, max_health)
signal stamina_changed(current_stamina, max_stamina)
signal player_died
signal character_switched(index, character_name)

@export var max_health: float = 100.0
var health: float = 100.0
@export var max_stamina: float = 100.0
@export var dash_cost: float = 35.0
@export var stamina_regen: float = 25.0
var stamina: float = 100.0

@export_group("Movement Speeds")
@export var walk_speed: float = 6.0
@export var run_speed: float = 11.0
@export var jump_velocity: float = 8.5
@export var dash_velocity: float = 24.0
@export var gravity: float = 18.0

@export_group("Retro Mechanics")
@export var can_flip: bool = true
@export var flip_input_window: float = 0.15
@export var flip_impulse_strength: float = 1.2

var state: MovementState = MovementState.WALKING
var jumps_remaining: int = 2
var dashes_remaining: int = 2
var dash_timer: float = 0.0

var last_input_dir: Vector3 = Vector3.ZERO
var last_input_time: float = 0.0

# Node references
@onready var pivot: Node3D = $Pivot
@onready var ground_ray: RayCast3D = get_node_or_null("GroundRay")
var camera_rig: Node3D = null
var combat_manager: Node3D = null

# Multi-Character Model definitions
const CHARACTER_DEFS = [
    {
        "name": "Spider-Man",
        "path": "res://assets/PLAYER-1/09_spider-man_mua.glb",
        "scale": Vector3(0.026, 0.026, 0.026),
        "rot_y": PI,
        "offset_y": 0.0,
        "anims": {
            "idle": "idle",
            "walk": "walk",
            "run": "run",
            "jump": "jump_start",
            "dash": "power_1_start",
            "block": "blocking",
            "combo": ["attack_light1", "attack_light2", "attack_light3"]
        }
    },
    {
        "name": "Silver Surfer",
        "path": "res://assets/PLAYER-1/80_silver_surfer_mua.glb",
        "scale": Vector3(0.026, 0.026, 0.026),
        "rot_y": PI,
        "offset_y": 0.0,
        "anims": {
            "idle": "idle",
            "walk": "fly_slow",
            "run": "fly_fast",
            "jump": "fly_idle",
            "dash": "fly_fast",
            "block": "power_1",
            "combo": ["attack_light1", "attack_light2", "attack_heavy1"]
        }
    },
    {
        "name": "Sci-Fi Soldier",
        "path": "res://assets/PLAYER-1/stylized_sci-_fi_soldier_animated.glb",
        "scale": Vector3(0.14, 0.14, 0.14),
        "rot_y": 0.0,
        "offset_y": 0.0,
        "anims": {
            "idle": "2350535269888_TempMotion",
            "walk": "2350535269888_TempMotion",
            "run": "2350535269888_TempMotion",
            "jump": "2350535269888_TempMotion",
            "dash": "2350535269888_TempMotion",
            "block": "2350535269888_TempMotion",
            "combo": ["2350535269888_TempMotion"]
        }
    },
    {
        "name": "Arachnid Warrior",
        "path": "res://assets/PLAYER-1/starship_troopers_arachnid_warrior.glb",
        "scale": Vector3(0.85, 0.85, 0.85),
        "rot_y": PI,
        "offset_y": 0.0,
        "anims": {
            "idle": "Idle",
            "walk": "Walk",
            "run": "Walk",
            "jump": "Idle",
            "dash": "Walk",
            "block": "Idle",
            "combo": ["Attack", "Attack", "Attack"]
        }
    }
]

var active_character_index: int = 0
var character_instances: Array = []
var active_anim_player: AnimationPlayer = null
var is_attacking: bool = false
var attack_anim_timer: float = 0.0

func _ready() -> void:
    health = max_health
    stamina = max_stamina
    
    # Resolve Pivot
    if not pivot:
        pivot = Node3D.new()
        pivot.name = "Pivot"
        add_child(pivot)
        
    # Resolve CameraRig
    camera_rig = get_node_or_null("CameraRig")
    if not camera_rig:
        camera_rig = get_node_or_null("../CameraRig")
    if not camera_rig:
        camera_rig = get_node_or_null("Pivot/CameraRig")
    if not camera_rig:
        var cam_script = load("res://scripts/core/CameraSystem.gd")
        if cam_script:
            camera_rig = Node3D.new()
            camera_rig.set_script(cam_script)
            camera_rig.name = "CameraRig"
            add_child(camera_rig)

    # Resolve CombatManager
    combat_manager = get_node_or_null("Pivot/CombatManager")
    if not combat_manager:
        combat_manager = get_node_or_null("CombatManager")
    if combat_manager and combat_manager.has_signal("attack_executed"):
        combat_manager.attack_executed.connect(self._on_attack_executed)
        combat_manager.parry_triggered.connect(self._on_parry_triggered)
        
    _instantiate_characters()
    switch_character(0)

func _instantiate_characters() -> void:
    for i in range(CHARACTER_DEFS.size()):
        var cdef = CHARACTER_DEFS[i]
        var p = cdef["path"]
        var inst_root: Node3D = null
        if ResourceLoader.exists(p):
            var scene_res = load(p)
            if scene_res is PackedScene:
                inst_root = scene_res.instantiate() as Node3D
        
        # Fallback to direct GLTFDocument runtime loader
        if not inst_root and FileAccess.file_exists(p):
            var gltf = GLTFDocument.new()
            var state = GLTFState.new()
            var err = gltf.append_from_file(p, state)
            if err == OK:
                inst_root = gltf.generate_scene(state) as Node3D
                
        if inst_root:
            inst_root.name = "CharModel_" + str(i)
            inst_root.scale = cdef["scale"]
            inst_root.rotation.y = cdef["rot_y"]
            inst_root.position.y = cdef["offset_y"]
            inst_root.visible = false
            pivot.add_child(inst_root)
            var ap = _find_animation_player(inst_root)
            if ap:
                _normalize_animation_quaternions(ap)
        else:
            push_warning("[PLAYER] Could not instantiate model: " + p)
            
        character_instances.append(inst_root)

func _normalize_animation_quaternions(ap: AnimationPlayer) -> void:
    if not ap:
        return
    for anim_name in ap.get_animation_list():
        var anim = ap.get_animation(anim_name)
        if not anim:
            continue
        for track_idx in range(anim.get_track_count()):
            if anim.track_get_type(track_idx) == Animation.TYPE_ROTATION_3D:
                for key_idx in range(anim.track_get_key_count(track_idx)):
                    var q = anim.track_get_key_value(track_idx, key_idx)
                    if q is Quaternion:
                        anim.track_set_key_value(track_idx, key_idx, q.normalized())

func switch_character(index: int) -> void:
    if character_instances.is_empty():
        return
    active_character_index = wrapi(index, 0, character_instances.size())
    
    for i in range(character_instances.size()):
        var inst = character_instances[i]
        if inst:
            inst.visible = (i == active_character_index)
            
    # Find AnimationPlayer on active model
    active_anim_player = null
    var active_inst = character_instances[active_character_index]
    if active_inst:
        active_anim_player = _find_animation_player(active_inst)
        
    var char_name = CHARACTER_DEFS[active_character_index]["name"]
    print("[PLAYER] Switched to Character: ", char_name)
    emit_signal("character_switched", active_character_index, char_name)
    _play_anim("idle")

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var res = _find_animation_player(child)
        if res:
            return res
    return null

func _play_anim(anim_key: String, custom_name: String = "") -> void:
    if not active_anim_player:
        return
    var anim_name = custom_name
    if anim_name == "":
        var anim_dict = CHARACTER_DEFS[active_character_index]["anims"]
        anim_name = anim_dict.get(anim_key, "")
        
    if anim_name != "" and active_anim_player.has_animation(anim_name):
        if active_anim_player.current_animation != anim_name:
            active_anim_player.play(anim_name)

func _physics_process(delta: float) -> void:
    if dash_timer > 0:
        dash_timer -= delta
        
    if attack_anim_timer > 0:
        attack_anim_timer -= delta
        if attack_anim_timer <= 0:
            is_attacking = false

    var is_on_floor_cached = ground_ray.is_colliding() if (ground_ray and ground_ray.is_inside_tree()) else is_on_floor()

    if not is_on_floor_cached and state != MovementState.FLYING and dash_timer <= 0:
        velocity.y -= gravity * delta

    if is_on_floor_cached:
        jumps_remaining = 2
        dashes_remaining = 2
        if state in [MovementState.JUMPING, MovementState.FLYING, MovementState.DASHING]:
            state = MovementState.WALKING

    if stamina < max_stamina:
        stamina = min(stamina + stamina_regen * delta, max_stamina)
        emit_signal("stamina_changed", stamina, max_stamina)

    handle_input(delta)
    move_and_slide()
    _update_animation_state()

func handle_input(delta: float) -> void:
    # 0. Character Swap (C key, 1-4 keys, or cycle action)
    if Input.is_physical_key_pressed(KEY_1):
        switch_character(0)
    elif Input.is_physical_key_pressed(KEY_2):
        switch_character(1)
    elif Input.is_physical_key_pressed(KEY_3):
        switch_character(2)
    elif Input.is_physical_key_pressed(KEY_4):
        switch_character(3)
    var cycle_pressed = (InputMap.has_action("cycle_character") and Input.is_action_just_pressed("cycle_character")) or (Input.is_physical_key_pressed(KEY_C) and not Input.is_key_pressed(KEY_CTRL))
    if cycle_pressed:
        switch_character(active_character_index + 1)

    # 1. Analog / WASD Movement
    var stick_input = Vector2.ZERO
    if InputMap.has_action("move_left") and InputMap.has_action("move_right") and InputMap.has_action("move_forward") and InputMap.has_action("move_backward"):
        stick_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    
    # Direct keyboard polling fallback
    if stick_input.length() < 0.1:
        if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
            stick_input.x -= 1.0
        if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
            stick_input.x += 1.0
        if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
            stick_input.y -= 1.0
        if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
            stick_input.y += 1.0
        stick_input = stick_input.normalized()

    # Align movement relative to camera
    var direction = Vector3.ZERO
    if camera_rig and camera_rig.has_method("get_camera_basis"):
        var cam_basis = camera_rig.get_camera_basis()
        var fwd = -cam_basis.z
        fwd.y = 0.0
        fwd = fwd.normalized()
        var right = cam_basis.x
        right.y = 0.0
        right = right.normalized()
        direction = (right * stick_input.x + fwd * -stick_input.y).normalized()
    else:
        direction = (transform.basis * Vector3(stick_input.x, 0, stick_input.y)).normalized()

    # 2. Check Flip logic
    handle_flip_logic(direction)

    # 3. Jump (Space or Gamepad A)
    var jump_pressed = (InputMap.has_action("jump") and Input.is_action_just_pressed("jump")) or Input.is_physical_key_pressed(KEY_SPACE)
    if jump_pressed and jumps_remaining > 0 and not is_attacking:
        velocity.y = jump_velocity
        jumps_remaining -= 1
        state = MovementState.JUMPING
        _play_anim("jump")

    # 4. Dash (Shift or Gamepad RB)
    var dash_pressed = (InputMap.has_action("dash") and Input.is_action_just_pressed("dash")) or Input.is_physical_key_pressed(KEY_SHIFT)
    if dash_pressed and stamina >= dash_cost and dash_timer <= 0:
        if direction.length() < 0.01 and pivot:
            direction = -pivot.global_transform.basis.z
            
        velocity.x = direction.x * dash_velocity
        velocity.z = direction.z * dash_velocity
        dashes_remaining -= 1
        stamina -= dash_cost
        emit_signal("stamina_changed", stamina, max_stamina)
        dash_timer = 0.25
        state = MovementState.DASHING
        _play_anim("dash")

    # 5. Apply Movement Speed
    if dash_timer <= 0:
        var is_sprinting = Input.is_physical_key_pressed(KEY_SHIFT) and direction.length() > 0.1
        var current_speed = run_speed if is_sprinting else walk_speed
        
        if direction.length() > 0.1:
            state = MovementState.RUNNING if is_sprinting else MovementState.WALKING
            if pivot:
                var target_look = global_position + direction
                if global_position.distance_to(target_look) > 0.1:
                    pivot.look_at(target_look, Vector3.UP)
            velocity.x = direction.x * current_speed
            velocity.z = direction.z * current_speed
        else:
            state = MovementState.WALKING
            velocity.x = move_toward(velocity.x, 0.0, current_speed)
            velocity.z = move_toward(velocity.z, 0.0, current_speed)

func _update_animation_state() -> void:
    if is_attacking or state == MovementState.DASHING:
        return
        
    if not is_on_floor():
        _play_anim("jump")
        return
        
    var h_vel = Vector2(velocity.x, velocity.z).length()
    if h_vel > 4.0:
        _play_anim("run")
    elif h_vel > 0.3:
        _play_anim("walk")
    else:
        _play_anim("idle")

func _on_attack_executed(combo_step: int) -> void:
    is_attacking = true
    attack_anim_timer = 0.5
    var combo_anims = CHARACTER_DEFS[active_character_index]["anims"].get("combo", [])
    if not combo_anims.is_empty():
        var idx = wrapi(combo_step - 1, 0, combo_anims.size())
        _play_anim("", combo_anims[idx])

func _on_parry_triggered() -> void:
    _play_anim("block")

func handle_flip_logic(direction: Vector3) -> void:
    if not can_flip or direction.length() < 0.1: 
        return
    var now = Time.get_ticks_msec() / 1000.0
    if last_input_dir.length() > 0.1:
        if last_input_dir.dot(direction) < -0.8 and (now - last_input_time) < flip_input_window:
            execute_flip(direction)
            last_input_time = now
            return
    last_input_dir = direction
    last_input_time = now

func execute_flip(new_direction: Vector3) -> void:
    if pivot: 
        pivot.look_at(global_position + new_direction, Vector3.UP)
    velocity = -velocity * flip_impulse_strength
    velocity.y = jump_velocity * 0.8
    _play_anim("dash")
    
    if Engine.has_singleton("Director"):
        Engine.get_singleton("Director").raise_tension(0.2)
    if camera_rig and camera_rig.has_method("apply_trauma"):
        camera_rig.apply_trauma(0.4)

func take_damage(amount: float) -> void:
    if health <= 0: return
    health -= amount
    emit_signal("health_changed", health, max_health)
    
    if camera_rig and camera_rig.has_method("apply_trauma"):
        camera_rig.apply_trauma(0.5)
        
    print("[PLAYER] Took damage! HP: ", health)
    if health <= 0:
        health = 0
        emit_signal("player_died")
        if Engine.has_singleton("Director"):
            Engine.get_singleton("Director").on_player_died()
        print("[PLAYER] CRITICAL SYSTEM FAILURE. UNIT DESTROYED.")
