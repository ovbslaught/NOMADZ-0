class_name RLInferenceEngine
extends Node

@export var model_path: String = "res://ai/models/vulture_drone_ppo.onnx"
@export var observation_vector_size: int = 16
@export var action_vector_size: int = 4

var is_model_loaded: bool = false

func _ready() -> void:
	_initialize_inference_engine()

func _initialize_inference_engine() -> void:
	if FileAccess.file_exists(model_path):
		is_model_loaded = true
		print("[RLInferenceEngine] Successfully initialized policy model: ", model_path)
	else:
		push_warning("[RLInferenceEngine] Model file not found at: " + model_path)

func evaluate_observation(obs: PackedFloat32Array) -> PackedFloat32Array:
	if not is_model_loaded or obs.size() != observation_vector_size:
		return PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	
	# Stub implementation for ONNX/GDExtension tensor forward pass
	var actions = PackedFloat32Array()
	actions.resize(action_vector_size)
	for i in range(action_vector_size):
		actions[i] = clampf(obs[i % obs.size()] * 0.5, -1.0, 1.0)
	
	return actions
