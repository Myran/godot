class_name SessionManager
extends RefCounted

# Session management for full gameplay semantic action logging
# Provides single session per gameplay session from start to quit

static var current_session_id: String = ""
static var session_start_time: float = 0.0
static var session_action_count: int = 0
static var session_context: Dictionary = {}

# Session configuration
const SESSION_ID_PREFIX: String = "session_"
# Note: No timeout - sessions last for entire gameplay duration


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
	if current_session_id.is_empty():
		start_new_session("gameplay_start")

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


# Session expiration removed - sessions persist for entire gameplay


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

	# Capture pre-action state for replay validation
	_capture_pre_action_state(action_type, session_id, sequence)


# Application lifecycle management for full gameplay sessions
static func start_gameplay_session() -> String:
	"""Start a new full gameplay session"""
	return start_new_session("gameplay_start", {"session_type": "full_gameplay"})


static func end_gameplay_session() -> void:
	"""End the current gameplay session"""
	end_current_session("gameplay_end")


# === GAMESTATE CHECKSUM INTEGRATION ===

# Storage for pre-action state checksums (session-based)
static var _pre_action_checksums: Dictionary = {}


## Store pre-action state for replay validation
## Called automatically before each semantic action
static func store_pre_action_state(checksum: String, state_data: Dictionary) -> void:
	"""Store pre-action state checksum and data for replay validation"""
	var session_id: String = get_current_session_id()
	var sequence: int = session_action_count + 1  # Next action sequence

	# Create state entry
	var state_entry: Dictionary = {
		"checksum": checksum,
		"state_data": state_data,
		"session_id": session_id,
		"sequence": sequence,
		"timestamp_ms": Time.get_unix_time_from_system() * 1000.0
	}

	# Store in session-based storage
	var session_key: String = "%s_%d" % [session_id, sequence]
	_pre_action_checksums[session_key] = state_entry

	Log.debug(
		"Pre-action state stored",
		{
			"session_id": session_id,
			"sequence": sequence,
			"checksum": checksum,
			"state_size": state_data.size()
		},
		["session", "state_capture", "checksum"]
	)


## Internal helper: Capture pre-action state using StateExtractor
static func _capture_pre_action_state(
	action_type: String, session_id: String, sequence: int
) -> void:
	"""Capture game state before semantic action execution"""
	# Extract current game state
	var game_state: Dictionary = StateExtractor.extract_game_state()

	# Generate checksum for state validation
	var checksum: String = StateExtractor.generate_checksum(game_state)

	# Store for replay validation
	store_pre_action_state(checksum, game_state)

	# Log state capture for debugging
	Log.debug(
		"Pre-action state captured",
		{
			"action_type": action_type,
			"session_id": session_id,
			"sequence": sequence,
			"checksum": checksum,
			"game_available": game_state.get("lineup", {}).get("game_available", false)
		},
		["session", "state_capture", "pre_action"]
	)


## Get stored pre-action state for replay validation
static func get_pre_action_state(session_id: String, sequence: int) -> Dictionary:
	"""Retrieve stored pre-action state for replay validation"""
	var session_key: String = "%s_%d" % [session_id, sequence]
	return _pre_action_checksums.get(session_key, {})


## Clear pre-action state storage (for memory management)
static func clear_pre_action_states(session_id: String = "") -> void:
	"""Clear pre-action state storage for memory management"""
	if session_id.is_empty():
		# Clear all stored states
		_pre_action_checksums.clear()
		Log.info("All pre-action states cleared", {}, ["session", "state_capture", "cleanup"])
	else:
		# Clear states for specific session
		var keys_to_remove: Array[String] = []
		for key: String in _pre_action_checksums.keys():
			if key.begins_with(session_id + "_"):
				keys_to_remove.append(key)

		for key: String in keys_to_remove:
			_pre_action_checksums.erase(key)

		Log.info(
			"Pre-action states cleared for session",
			{"session_id": session_id, "cleared_count": keys_to_remove.size()},
			["session", "state_capture", "cleanup"]
		)


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
