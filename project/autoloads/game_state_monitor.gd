# project/autoloads/game_state_monitor.gd
# GameStateMonitor - Tracks when the game system reaches an idle state
# Provides reliable async waiting for debug actions and testing

extends Node

signal system_idle
const STABLE_FRAME_COUNT: int = 3  # System must be stable for 3 frames
var _last_game_state: core.GameState
var _last_ui_state: core.UIState
var _stable_frames: int = 0


func _ready() -> void:
	Log.info("GameStateMonitor initialized", {}, ["debug", "system"])
	set_process(true)


func _find_game_node() -> Node:
	"""Find the Game node in the scene tree"""
	# Look for Game node as child of main scene
	var main_scene: Node = get_tree().current_scene
	var game_node: Node = main_scene.find_child("Game", true, false)
	if game_node:
		return game_node

	# Last resort: search the entire tree
	return _find_game_node_recursive(get_tree().root)


func _find_game_node_recursive(node: Node) -> Node:
	"""Recursively search for Game node"""
	# Check if this node has the class name "Game"
	if node.get_script() and node.get_script().get_global_name() == "Game":
		return node

	for child_node: Node in node.get_children():
		var result: Node = _find_game_node_recursive(child_node)
		if result:
			return result

	return null


func _process(_delta: float) -> void:
	var game_node: Node = _find_game_node()
	if not game_node:
		return

	var current_game_state: core.GameState = game_node.game_handler.current_gamestate
	var current_ui_state: core.UIState = game_node.ui_state

	# Check if state is stable and idle
	var is_idle: bool = (
		current_ui_state == core.UIState.WAITING
		and current_game_state in [core.GameState.PREPARE, core.GameState.POSTBATTLE]
	)

	if is_idle and current_game_state == _last_game_state and current_ui_state == _last_ui_state:
		_stable_frames += 1
		if _stable_frames >= STABLE_FRAME_COUNT:
			Log.debug(
				"System reached idle state",
				{
					"game_state": core.GameState.keys()[current_game_state],
					"ui_state": core.UIState.keys()[current_ui_state]
				},
				["debug", "system", "idle"]
			)
			system_idle.emit()
			_stable_frames = 0  # Reset to avoid spam
	else:
		_stable_frames = 0

	_last_game_state = current_game_state
	_last_ui_state = current_ui_state


func await_system_idle() -> void:
	"""Wait for the game system to reach a stable idle state"""
	Log.debug("Waiting for system idle state", {}, ["debug", "system", "await"])
	await system_idle
	Log.debug("System idle state reached", {}, ["debug", "system", "await"])


func is_system_idle() -> bool:
	"""Check if system is currently in idle state without waiting"""
	var game_node: Node = _find_game_node()
	if not game_node:
		return false

	var current_game_state: core.GameState = game_node.game_handler.current_gamestate
	var current_ui_state: core.UIState = game_node.ui_state

	return (
		current_ui_state == core.UIState.WAITING
		and current_game_state in [core.GameState.PREPARE, core.GameState.POSTBATTLE]
	)
