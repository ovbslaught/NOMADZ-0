extends KinematicBody
# CivAgentAI - Intelligent civilization agent that learns from arcade games
# Integrates with RetroArcadeManager for skill development and behavioral learning

class_name CivAgentAI

# Agent identity
var agent_id: String = ""
var agent_name: String = ""
var civilization: String = ""

# Physical properties
var movement_speed = 5.0
var rotation_speed = 2.0
var velocity = Vector3.ZERO

# AI behavior states
enum AgentState {
	IDLE,
	WANDERING,
	PLAYING_ARCADE,
	LEARNING,
	SOCIALIZING,
	WORKING,
	REST