# NOMADZ Character Swap System (Godot 4)

One abstract player, many bodies. All humanoid characters conform to
SkeletonProfileHumanoid so a single controller and animation library
drives every one of them.

## Architecture

    res://characters/
      abstract_player.tscn      <- the only scene with a CharacterBody3D
        CharacterBody3D
          CollisionShape3D
          MeshHolder (Node3D)   <- swap target: bodies get instanced under here
          CameraPivot / SpringArm3D
      bodies/
        cope/cope_body.tscn     <- each body: Node3D > Skeleton3D + MeshInstance3D(s)
        ironman/ironman_body.tscn
        spider/spider_body.tscn
        dragon/dragon_body.tscn
      anims/shared/             <- retargeted animations, profile-conformant

## Controller — abstract_player.gd

```gdscript
extends CharacterBody3D

const SPEED := 5.0
const RUN_SPEED := 8.5
const JUMP_VELOCITY := 4.5

@onready var mesh_holder: Node3D = $MeshHolder
@onready var anim: AnimationTree = $AnimationTree

var current_body_id: StringName = &""
var bodies: Dictionary = {}
var gravity: float = ProjectSettings.get_setting(
    "physics/3d/default_gravity")

func _ready() -> void:
    register_body(&"cope",    preload("res://characters/bodies/cope/cope_body.tscn"))
    register_body(&"ironman", preload("res://characters/bodies/ironman/ironman_body.tscn"))
    register_body(&"spider",  preload("res://characters/bodies/spider/spider_body.tscn"))
    register_body(&"dragon",  preload("res://characters/bodies/dragon/dragon_body.tscn"))
    swap_body(&"cope")

func register_body(id: StringName, scene: PackedScene) -> void:
    bodies[id] = scene

func swap_body(id: StringName) -> void:
    if not bodies.has(id) or id == current_body_id:
        return
    for child in mesh_holder.get_children():
        child.queue_free()
    var inst := bodies[id].instantiate()
    mesh_holder.add_child(inst)
    inst.owner = self
    var humanoid: bool = inst.get_meta("humanoid", true)
    anim.active = humanoid
    current_body_id = id
    print("[SWAP] now playing as: ", id)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY
    var input_dir := Input.get_vector("move_left", "move_right",
                                       "move_forward", "move_back")
    var speed := RUN_SPEED if Input.is_action_pressed("sprint") else SPEED
    var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
    if dir:
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
        mesh_holder.rotation.y = atan2(dir.x, dir.z)
    else:
        velocity.x = move_toward(velocity.x, 0, speed)
        velocity.z = move_toward(velocity.z, 0, speed)
    move_and_slide()

func _unhandled_input(_event: InputEvent) -> void:
    if Input.is_action_just_pressed("swap_1"): swap_body(&"cope")
    if Input.is_action_just_pressed("swap_2"): swap_body(&"ironman")
    if Input.is_action_just_pressed("swap_3"): swap_body(&"spider")
    if Input.is_action_just_pressed("swap_4"): swap_body(&"dragon")
```

## Retarget on import (once per model)

Import dock: Skeleton -> Retarget enabled, preset SkeletonProfileHumanoid,
bone map verified, Rest = Reset, unique names ON. Reimport. Shared
animations now play on every humanoid body.

## Rigging the unrigged

Mixamo: FBX/OBJ under 100MB -> auto-rig -> download FBX Binary With Skin
-> import with retarget -> wrap as body scene -> register in controller.
~10 min per humanoid (base meshes, hero001, troopers).

Non-humanoids (SciFiDroid, props): no skeleton. Tween it:

```gdscript
func _ready() -> void:
    var tween := create_tween().set_loops()
    tween.tween_property(self, "position:y", 0.4, 1.2).as_relative()
    tween.tween_property(self, "position:y", -0.4, 1.2).as_relative()
```

## Order of attack

1. Retarget + wire the 5 already-rigged models.
2. Prove the swap with cope + ironman, then add bodies.
3. Mixamo the base meshes in batches.
4. Dragon/droid via their own logic branches (meta humanoid=false).
5. Per-character stats after swapping is boring and reliable.
