extends Node3D

## NOMADZ MELEE FSM v1.0
## 3-Hit Punch Combo Logic

var combo_step = 0
var combo_timer = 0.0
const COMBO_WINDOW = 0.8

@onready var anim_player = $"../AnimationPlayer"

func _input(event):
	if event.is_action_pressed("punch"):
		execute_combo()

func execute_combo():
	combo_timer = COMBO_WINDOW
	combo_step += 1
	
	if combo_step > 3: combo_step = 1 # Reset to first hit
	
	match combo_step:
		1: anim_player.play("punch_left")
		2: anim_player.play("punch_right")
		3: anim_player.play("kick_heavy")
		
	print("NOMADZ: Melee Chain - Step ", combo_step)

func _process(delta):
	if combo_timer > 0:
		combo_timer -= delta
	else:
		combo_step = 0 # Reset combo if time expires
