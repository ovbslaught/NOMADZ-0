class_name AIAssistantResource
extends Resource

## Name of the assistant type (e.g., "Writer", "Programmer").
@export var type_name: String

enum Mode {
	CHAT,
	AGENT,
	PLAIN
}

## The behavior mode of the assistant.
## CHAT: Standard helpful assistant without tools.
## AGENT: Autonomous agent with tool access.
## PLAIN: Direct LLM interaction without complex system instructions.
@export var mode: Mode = Mode.AGENT

## Icon displayed in hub buttons and tabs for this assistant.
@export var type_icon: Texture2D

## The name of the AI model as listed in the available models section.
@export var ai_model: String

## The class of the LLM provider resource for that model, e.g. res://addons/GodAgent/llm_providers/ollama.tres, if empty it will try to use the API selected in AI Hub tab.
@export var llm_provider: Resource

@export_group("Agent Mode Settings")
## Used to give the System message to the chat in AGENT mode.
@export_multiline var agent_description: String = '
You are an autonomous GDscript programming agent for Godot 4.5. 
Execute all possible steps to complete the orders given to you.
ALL [ext_resource] blocks MUST appear at the TOP of the file before nodes.'
## The temperature for AGENT mode.
@export_range(0.0, 1.0) var agent_temperature := 0.1
## Maximum number of autonomous steps (tool calls) the agent can perform in a row.
## Set to 0 to disable autonomous loops (manual confirmation for every step).
@export var max_autonomous_steps: int = 7
## If true, the agent will execute the whole plan automatically.
@export var auto_execute_plan: bool = true

@export_group("Chat Mode Settings")
## Used to give the System message to the chat in CHAT mode.
@export_multiline var chat_description: String = '
You are a helpful assistant.'
## The temperature for CHAT mode.
@export_range(0.0, 1.0) var chat_temperature := 0.7

@export_group("Plain Mode Settings")
## Used to give the System message to the chat in PLAIN mode.
@export_multiline var plain_description: String = ""
## The temperature for PLAIN mode.
@export_range(0.0, 1.0) var plain_temperature := 0.5

@export_group("General Temperature Settings")
## Models have a default temperature recommended for most use cases.
## When checking this, the value of the temperature will be dictated by the specific mode temperature.
@export var use_custom_temperature: bool = false
