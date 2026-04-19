extends Node

# Director.gd - Autoload script for game state management

# Game states enumeration
enum GameState {
    GAME_PLAY,
    PAUSE,
    GAME_OVER,
}

# Variables to hold the current game state and tension level
var current_state = GameState.GAME_PLAY
var tension_level = 0

# Function to change game state
func change_game_state(new_state: GameState):
    current_state = new_state
    print("Game state changed to: " + str(current_state))
    emit_signal("state_changed", current_state)

# Function to adjust the tension level
func adjust_tension(amount: int):
    tension_level += amount
    tension_level = clamp(tension_level, 0, 100)  # Clamp tension level between 0 and 100
    print("Tension level adjusted to: " + str(tension_level))
    emit_signal("tension_changed", tension_level)

# Function for AI evolution
func evolve_ai():
    # Placeholder for AI evolution logic
    print("AI is evolving...")

# Function to save game state
func save_game():
    var game_data = {
        "state": current_state,
        "tension_level": tension_level,
    }
    # Save game data to a file or database
    print("Game state saved!")

# Function to load game state
func load_game():
    # Load game data from a file or database
    current_state = GameState.GAME_PLAY  # Default for example
    tension_level = 0  # Default for example
    print("Game state loaded!")

# Signals
signal state_changed(new_state)
signal tension_changed(new_tension)

# Ready function called when the node is added to the scene
func _ready():
    print("Director ready!")
    load_game()  # Load game state on ready
