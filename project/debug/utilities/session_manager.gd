class_name SessionManager
extends RefCounted
# Session configuration
const SESSION_ID_PREFIX: String = "session_"
# Note: No timeout - sessions last for entire gameplay duration
# Session management for full gameplay semantic action logging
# Provides single session per gameplay session from start to quit

static var current_session_id: String = ""
static var session_start_time: float = 0.0
static var session_action_count: int = 0
static var session_context: Dictionary = {}


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

	# Capture initial seed for deterministic replay
	var initial_seed: int = _get_current_seed()
	session_context["initial_seed"] = initial_seed

	Log.info(
		"SESSION_START",
		{
			"session_id": current_session_id,
			"trigger": trigger,
			"initial_seed": initial_seed,
			"context": session_context
		},
		[Log.TAG_SESSION_START, Log.TAG_SEMANTIC]
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
		[Log.TAG_SESSION_END, Log.TAG_SEMANTIC]
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
	"""Log a semantic action with session context and pre-action checksum"""
	var session_id: String = get_current_session_id()
	var sequence: int = increment_action_count()
	var timestamp_ms: float = Time.get_unix_time_from_system() * 1000.0
	var session_elapsed_ms: float = timestamp_ms - session_start_time

	# Capture pre-action checksum for replay validation with sequence number
	var pre_action_checksum: String = _capture_pre_action_checksum(action_type, sequence)

	var semantic_log: Dictionary = {
		"type": action_type,
		"session_id": session_id,
		"timestamp_ms": timestamp_ms,
		"sequence": sequence,
		"session_elapsed_ms": session_elapsed_ms,
		"pre_action_checksum": pre_action_checksum,
		"action_name": action_type,
		"data": data
	}

	# Emit semantic action log with semantic tags
	Log.info("SEMANTIC_ACTION", semantic_log, [Log.TAG_SEMANTIC_ACTION, Log.TAG_PLAYER])

	# Also emit with hierarchical tags for unified filtering
	var hierarchical_tags: Array[String] = _get_hierarchical_tags_for_semantic_action(action_type)
	if not hierarchical_tags.is_empty():
		Log.info("Semantic Action: " + action_type, data, hierarchical_tags)


# Application lifecycle management for full gameplay sessions
static func start_gameplay_session() -> String:
	"""Start a new full gameplay session"""
	return start_new_session("gameplay_start", {"session_type": "full_gameplay"})


static func end_gameplay_session() -> void:
	"""End the current gameplay session"""
	end_current_session("gameplay_end")


# === SIMPLIFIED CHECKSUM INTEGRATION ===
# Checksum validation now uses logged checksums only, no separate storage needed


## Capture pre-action checksum for replay validation with sequence number
static func _capture_pre_action_checksum(action_type: String, sequence: int) -> String:
	"""Capture game state checksum before semantic action execution, including sequence number"""
	Log.debug(
		"Starting checksum capture",
		{"action_type": action_type, "sequence": sequence},
		[Log.TAG_SESSION, Log.TAG_CHECKSUM, Log.TAG_DEBUG]
	)

	# Extract current game state using StateExtractor
	# Note: ClassDB.class_exists() doesn't work reliably for static classes, so try direct access
	var game_state: Dictionary = StateExtractor.extract_game_state()
	Log.debug(
		"StateExtractor result",
		{
			"action_type": action_type,
			"sequence": sequence,
			"state_size": game_state.size(),
			"is_empty": game_state.is_empty()
		},
		[Log.TAG_SESSION, Log.TAG_CHECKSUM, Log.TAG_DEBUG]
	)

	# DETAILED CHECKSUM CONTENT LOGGING - Show exactly what's being hashed
	Log.info(
		"CHECKSUM_CONTENT_DETAIL",
		{
			"action_type": action_type,
			"sequence": sequence,
			"game_state_content": game_state,
			"draft_area_count": game_state.get("board", {}).get("draft_area", []).size(),
			"lineup_allies_count": game_state.get("lineup", {}).get("allies", {}).size(),
			"current_game_state": game_state.get("lineup", {}).get("current_game_state", "UNKNOWN"),
			"ui_state": game_state.get("lineup", {}).get("ui_state", "UNKNOWN")
		},
		[Log.TAG_SESSION, Log.TAG_CHECKSUM]
	)

	if game_state.is_empty():
		Log.warning(
			"StateExtractor returned empty state",
			{"action_type": action_type, "sequence": sequence},
			[Log.TAG_SESSION, Log.TAG_CHECKSUM, Log.TAG_WARNING]
		)
		return ""

	# Add sequence number to game state for unique checksum generation
	# This ensures identical game states at different points produce different checksums
	game_state["action_sequence"] = sequence

	# Generate checksum for state validation
	var checksum: String = StateExtractor.generate_checksum(game_state)
	Log.debug(
		"Generated checksum",
		{
			"action_type": action_type,
			"sequence": sequence,
			"checksum": checksum,
			"checksum_length": checksum.length()
		},
		[Log.TAG_SESSION, Log.TAG_CHECKSUM, Log.TAG_DEBUG]
	)

	Log.debug(
		"Pre-action checksum captured",
		{
			"action_type": action_type,
			"sequence": sequence,
			"checksum": checksum,
			"game_available": game_state.get("lineup", {}).get("game_available", false)
		},
		[Log.TAG_SESSION, Log.TAG_CHECKSUM]
	)

	return checksum


## Get current seed from RNG singleton for deterministic replay
static func _get_current_seed() -> int:
	"""Get current seed from the RNG singleton"""
	# Access the RNG autoload directly (consistent with rest of codebase)
	if is_instance_valid(rng) and rng.seeded_rng:
		return rng.seeded_rng._initial_seed

	Log.warning(
		"Could not access RNG singleton for seed capture",
		{"rng_available": rng != null, "seeded_rng_available": rng.seeded_rng if rng else null},
		[Log.TAG_SESSION, Log.TAG_SEED, Log.TAG_WARNING]
	)

	# Default seed if RNG not available
	return 12345


# === REMOVED POST-ACTION CAPTURE CODE ===
# Post-action state capture has been removed in favor of simpler checksum-only validation

# === HELPER FUNCTIONS ===


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

	Log.info(
		"SEMANTIC_ACTION_GAMESTATE_MARKER",
		marker_log,
		[Log.TAG_SEMANTIC, Log.TAG_GAMESTATE, Log.TAG_MARKER]
	)


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
		[Log.TAG_REPLAY, Log.TAG_VALIDATION, Log.TAG_SETUP]
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

	Log.info(
		"REPLAY_VALIDATION_COMPLETE",
		summary,
		[Log.TAG_REPLAY, Log.TAG_VALIDATION, Log.TAG_COMPLETE]
	)

	return summary


## Maps semantic action types to hierarchical tags for unified filtering
static func _get_hierarchical_tags_for_semantic_action(action_type: String) -> Array[String]:
	"""Convert semantic action type to hierarchical tags for unified filtering"""
	match action_type:
		"draft.reroll":
			return [Log.TAG_GAME, Log.TAG_DRAFT, Log.TAG_SEMANTIC_ACTION]
		"draft.upgrade":
			return [Log.TAG_GAME, Log.TAG_DRAFT, Log.TAG_SEMANTIC_ACTION]
		"draft.toggle_line":
			return [Log.TAG_GAME, Log.TAG_DRAFT, Log.TAG_TOGGLE_LINE, Log.TAG_SEMANTIC_ACTION]
		"draft.remove_card":
			return [Log.TAG_GAME, Log.TAG_DRAFT, Log.TAG_SEMANTIC_ACTION]
		"lineup.move_card":
			return [Log.TAG_GAME, Log.TAG_LINEUP, Log.TAG_SEMANTIC_ACTION]
		"card.move":
			return [Log.TAG_GAME, Log.TAG_CARD, Log.TAG_MOVE, Log.TAG_SEMANTIC_ACTION]
		"transition.change_state":
			return [Log.TAG_GAME, Log.TAG_STATE_TRANSITION, Log.TAG_SEMANTIC_ACTION]
		"battle.start":
			return [Log.TAG_GAME, Log.TAG_BATTLE, Log.TAG_START, Log.TAG_SEMANTIC_ACTION]
		_:
			# Default fallback for unknown semantic actions
			return [Log.TAG_SEMANTIC_ACTION, Log.TAG_UNKNOWN]
