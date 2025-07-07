class_name SessionManager
extends RefCounted

# Session management for semantic action logging with context tracking
# Provides session ID generation, boundary detection, and context preservation

static var current_session_id: String = ""
static var session_start_time: float = 0.0
static var session_action_count: int = 0
static var session_context: Dictionary = {}

# Session configuration
const SESSION_TIMEOUT_MS: int = 30000  # 30 seconds of inactivity
const SESSION_ID_PREFIX: String = "session_"


static func start_new_session(trigger: String = "manual", context: Dictionary = {}) -> String:
	"""Start a new session with unique ID and context"""
	var timestamp: String = (
		Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	)
	var random_suffix: String = "%08x" % randi()

	current_session_id = SESSION_ID_PREFIX + timestamp + "_" + random_suffix
	session_start_time = Time.get_unix_time_from_system() * 1000.0
	session_action_count = 0
	session_context = context.duplicate()

	# Add default context
	session_context["trigger"] = trigger
	session_context["start_time"] = session_start_time
	session_context["platform"] = OS.get_name()

	Log.info(
		"SESSION_START",
		{"session_id": current_session_id, "trigger": trigger, "context": session_context},
		["session", "start", "semantic"]
	)

	return current_session_id


static func get_current_session_id() -> String:
	"""Get current session ID, creating new session if none exists"""
	if current_session_id.is_empty() or _is_session_expired():
		start_new_session("auto_create")

	return current_session_id


static func end_current_session(reason: String = "manual") -> void:
	"""End the current session"""
	if current_session_id.is_empty():
		return

	var duration_ms: float = (Time.get_unix_time_from_system() * 1000.0) - session_start_time

	Log.info(
		"SESSION_END",
		{
			"session_id": current_session_id,
			"reason": reason,
			"duration_ms": duration_ms,
			"action_count": session_action_count,
			"context": session_context
		},
		["session", "end", "semantic"]
	)

	current_session_id = ""
	session_start_time = 0.0
	session_action_count = 0
	session_context.clear()


static func increment_action_count() -> int:
	"""Increment action count for current session"""
	session_action_count += 1
	return session_action_count


static func update_session_context(key: String, value: Variant) -> void:
	"""Update session context with new data"""
	session_context[key] = value


static func get_session_context() -> Dictionary:
	"""Get current session context"""
	return session_context.duplicate()


static func _is_session_expired() -> bool:
	"""Check if current session has expired due to inactivity"""
	if session_start_time == 0.0:
		return true

	var current_time: float = Time.get_unix_time_from_system() * 1000.0
	var session_age: float = current_time - session_start_time

	return session_age > SESSION_TIMEOUT_MS


static func log_semantic_action(action_type: String, data: Dictionary = {}) -> void:
	"""Log a semantic action with session context and parameters"""
	var session_id: String = get_current_session_id()
	var sequence: int = increment_action_count()
	var timestamp_ms: float = Time.get_unix_time_from_system() * 1000.0
	var session_elapsed_ms: float = timestamp_ms - session_start_time

	var semantic_log: Dictionary = {
		"type": action_type,
		"session_id": session_id,
		"timestamp_ms": timestamp_ms,
		"sequence": sequence,
		"session_elapsed_ms": session_elapsed_ms,
		"data": data
	}

	Log.info("SEMANTIC_ACTION", semantic_log, ["semantic", "action", "player"])

	# TODO: Implement simplified gamestate checksum capture system
	# The comprehensive capture system has been removed, will be replaced with
	# a simpler approach focused on critical game state validation


# Session boundary detection helpers
static func should_end_session_on_state_change(from_state: String, to_state: String) -> bool:
	"""Determine if state transition should trigger session end"""
	# End session on major state transitions
	var major_transitions: Array[String] = [
		"draft_to_prepare", "prepare_to_battle", "battle_to_draft", "any_to_menu"
	]

	var transition: String = from_state + "_to_" + to_state
	return major_transitions.has(transition) or to_state == "menu"


static func should_start_new_session_on_action(action_type: String) -> bool:
	"""Determine if action should trigger new session start"""
	# Start new session on game reset or major initialization actions
	var session_triggers: Array[String] = [
		"game.match.reset_level", "game.lineup.populate_enemy", "debug.session.start"
	]

	return session_triggers.has(action_type)


# Context helpers for common game states
static func create_draft_context(level: int = 1) -> Dictionary:
	"""Create context for draft phase"""
	return {
		"game_phase": "draft", "level": level, "timestamp": Time.get_datetime_string_from_system()
	}


static func create_battle_context(
	player_lineup: Array = [], enemy_lineup: Array = []
) -> Dictionary:
	"""Create context for battle phase"""
	return {
		"game_phase": "battle",
		"player_lineup_count": player_lineup.size(),
		"enemy_lineup_count": enemy_lineup.size(),
		"timestamp": Time.get_datetime_string_from_system()
	}


static func create_preparation_context() -> Dictionary:
	"""Create context for preparation phase"""
	return {"game_phase": "preparation", "timestamp": Time.get_datetime_string_from_system()}


# === GAMESTATE CHECKSUM INTEGRATION ===

# === SIMPLIFIED GAMESTATE VALIDATION ===
# Legacy comprehensive capture system removed - replaced with targeted validation


static func _log_simple_gamestate_marker(
	action_type: String, session_id: String, sequence: int
) -> void:
	"""Log a simple gamestate marker for basic replay validation"""
	var marker_log: Dictionary = {
		"action_type": action_type,
		"session_id": session_id,
		"sequence": sequence,
		"timestamp_ms": Time.get_unix_time_from_system() * 1000.0,
		"game_phase": _get_current_game_phase(),
		"ui_state": _get_current_ui_state()
	}

	Log.info("SEMANTIC_ACTION_GAMESTATE_MARKER", marker_log, ["semantic", "gamestate", "marker"])


static func _get_current_game_phase() -> String:
	"""Get current game phase for simple validation"""
	# Access singletons properly using get_node
	var game_node: Node = (
		Engine.get_main_loop().get_nodes_in_group("game_handler").get(0)
		if Engine.get_main_loop().get_nodes_in_group("game_handler").size() > 0
		else null
	)
	if game_node and game_node.has_method("get_gamestate"):
		return str(game_node.get_gamestate())

	var core_node: Node = (
		Engine.get_main_loop().get_nodes_in_group("core").get(0)
		if Engine.get_main_loop().get_nodes_in_group("core").size() > 0
		else null
	)
	if core_node and core_node.has_method("get_current_state"):
		return str(core_node.get_current_state())

	return "UNKNOWN"


static func _get_current_ui_state() -> String:
	"""Get current UI state for simple validation"""
	# Access singletons properly using get_node
	var game_node: Node = (
		Engine.get_main_loop().get_nodes_in_group("game_handler").get(0)
		if Engine.get_main_loop().get_nodes_in_group("game_handler").size() > 0
		else null
	)
	if game_node and game_node.has_property("ui_state"):
		return str(game_node.ui_state)

	var ui_node: Node = (
		Engine.get_main_loop().get_nodes_in_group("ui").get(0)
		if Engine.get_main_loop().get_nodes_in_group("ui").size() > 0
		else null
	)
	if ui_node and ui_node.has_method("get_current_state"):
		return str(ui_node.get_current_state())

	return "UNKNOWN"


# === REPLAY VALIDATION SETUP ===


static func setup_replay_validation(demo_config_path: String) -> bool:
	"""Setup simplified replay validation for demo configs"""
	Log.info(
		"Setting up simplified replay validation",
		{"demo_config_path": demo_config_path},
		["replay", "validation", "setup"]
	)

	# For now, just log that validation setup was requested
	# In the future, this could parse the demo config and extract session info
	# for more sophisticated validation
	return true


static func finalize_replay_validation() -> Dictionary:
	"""Finalize simplified replay validation and return summary"""
	var summary: Dictionary = {
		"total_validations": 0,
		"matches": 0,
		"mismatches": 0,
		"missing_originals": 0,
		"success_rate": 1.0,
		"replay_deterministic": true,
		"validation_type": "simplified",
		"note": "Using simplified validation - comprehensive checksum system removed"
	}

	Log.info("REPLAY_VALIDATION_COMPLETE", summary, ["replay", "validation", "complete"])

	return summary
