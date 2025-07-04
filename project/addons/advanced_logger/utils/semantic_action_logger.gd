class_name SemanticActionLogger
extends RefCounted

# Enhanced semantic action logging with proper session management
# Delegates to SessionManager for session handling and uses improved logging format

# Compatibility wrapper for existing code - delegates to SessionManager
static func log_action(action_type: String, data: Dictionary = {}) -> void:
	"""Log a semantic player action with session context (compatibility wrapper)"""
	SessionManager.log_semantic_action(action_type, data)

# Session management - delegates to SessionManager
static func start_session(session_id: String = "") -> String:
	"""Start a new session (compatibility wrapper)"""
	if session_id.is_empty():
		return SessionManager.start_new_session("legacy_start")
	else:
		SessionManager.current_session_id = session_id
		SessionManager.session_start_time = Time.get_unix_time_from_system() * 1000.0
		SessionManager.session_action_count = 0
		return session_id

static func end_session() -> void:
	"""End current session (compatibility wrapper)"""
	SessionManager.end_current_session("legacy_end")

static func get_session_info() -> Dictionary:
	"""Get current session info (compatibility wrapper)"""
	return {
		"session_id": SessionManager.get_current_session_id(),
		"action_count": SessionManager.session_action_count,
		"is_active": not SessionManager.current_session_id.is_empty()
	}

# Enhanced logging methods using SemanticLogger
static func log_draft_action(action_type: String, data: Dictionary = {}) -> void:
	"""Enhanced draft action logging"""
	match action_type:
		"draft.reroll":
			SemanticLogger.log_draft_reroll(
				data.get("cost", 0),
				data.get("previous_cards", []),
				data.get("seed_before", -1)
			)
		"draft.upgrade":
			SemanticLogger.log_draft_upgrade(
				data.get("level", 1),
				data.get("cost", 0),
				data.get("target_card", "")
			)
		"draft.toggle_line":
			SemanticLogger.log_draft_toggle_line(
				data.get("column_index", -1),
				data.get("new_state", false)
			)
		"draft.remove_card":
			var pos: Vector2i = Vector2i(-1, -1)
			if data.has("position") and data.position is Dictionary:
				pos = Vector2i(data.position.get("x", -1), data.position.get("y", -1))
			SemanticLogger.log_draft_remove_card(data.get("card_id", ""), pos)
		_:
			# Fallback to basic logging
			SessionManager.log_semantic_action(action_type, data)

static func log_lineup_action(action_type: String, data: Dictionary = {}) -> void:
	"""Enhanced lineup action logging"""
	match action_type:
		"lineup.move_card":
			SemanticLogger.log_lineup_move_card(
				data.get("card_id", ""),
				data.get("from_position", -1),
				data.get("to_position", -1)
			)
		"lineup.add_card":
			var source_pos: Vector2i = Vector2i(-1, -1)
			if data.has("source_position") and data.source_position is Dictionary:
				source_pos = Vector2i(data.source_position.get("x", -1), data.source_position.get("y", -1))
			SemanticLogger.log_lineup_add_card(
				data.get("card_id", ""),
				data.get("target_position", -1),
				source_pos
			)
		"lineup.remove_card":
			SemanticLogger.log_lineup_remove_card(
				data.get("card_id", ""),
				data.get("position", -1)
			)
		_:
			# Fallback to basic logging
			SessionManager.log_semantic_action(action_type, data)

static func log_state_transition(from_state: String, to_state: String) -> void:
	"""Enhanced state transition logging"""
	SemanticLogger.log_state_transition(from_state, to_state)

static func log_battle_action(action_type: String, data: Dictionary = {}) -> void:
	"""Enhanced battle action logging"""
	match action_type:
		"battle.start":
			SemanticLogger.log_battle_start(
				data.get("player_lineup", []),
				data.get("enemy_lineup", [])
			)
		_:
			# Fallback to basic logging
			SessionManager.log_semantic_action(action_type, data)

# Enhanced session control with context
static func start_draft_session(level: int = 1) -> String:
	"""Start a draft session with context"""
	return SemanticLogger.start_draft_session(level)

static func start_battle_session(player_lineup: Array = [], enemy_lineup: Array = []) -> String:
	"""Start a battle session with context"""
	return SemanticLogger.start_battle_session(player_lineup, enemy_lineup)

# Compatibility methods for existing code
static func _ensure_session_active() -> void:
	"""Ensure session is active (compatibility)"""
	SessionManager.get_current_session_id()  # This will create one if needed

static func _generate_session_id() -> String:
	"""Generate session ID (compatibility)"""
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	return "session_%s_%d" % [timestamp, randi() % 10000]

static func _get_debug_session_id() -> String:
	"""Get debug session ID (compatibility)"""
	return "game_session_%d" % Time.get_ticks_msec()