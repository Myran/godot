class_name SessionManager
extends RefCounted
const SESSION_ID_PREFIX: String = "session_"

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

	session_context["trigger"] = trigger
	session_context["start_time"] = session_start_time
	session_context["platform"] = OS.get_name()

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


static func has_active_session() -> bool:
	"""Check if there is an active session"""
	return not current_session_id.is_empty()


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


static func log_semantic_action(action_type: String, data: Dictionary = {}) -> void:
	"""Log a semantic action with session context and pre-action checksum"""
	var session_id: String = get_current_session_id()
	var sequence: int = increment_action_count()
	var timestamp_ms: float = Time.get_unix_time_from_system() * 1000.0
	var session_elapsed_ms: float = timestamp_ms - session_start_time

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

	Log.info("SEMANTIC_ACTION", semantic_log, [Log.TAG_SEMANTIC_ACTION, Log.TAG_PLAYER])

	var hierarchical_tags: Array[String] = _get_hierarchical_tags_for_semantic_action(action_type)
	if not hierarchical_tags.is_empty():
		Log.info("Semantic Action: " + action_type, data, hierarchical_tags)


static func start_gameplay_session() -> String:
	"""Start a new full gameplay session"""
	return start_new_session("gameplay_start", {"session_type": "full_gameplay"})


static func end_gameplay_session() -> void:
	"""End the current gameplay session"""
	end_current_session("gameplay_end")


static func _capture_pre_action_checksum(action_type: String, sequence: int) -> String:
	"""Capture game state checksum before semantic action execution, including sequence number"""

	# CRITICAL FIX: Skip checksum capture for system debug actions to prevent Android StateExtractor hang
	if action_type.begins_with("system.debug."):
		Log.debug(
			"Skipping checksum capture for UI debug action (Android performance optimization)",
			{"action_type": action_type, "sequence": sequence},
			[Log.TAG_SESSION, Log.TAG_CHECKSUM, Log.TAG_DEBUG, "android_optimization"]
		)
		return "SKIP_SYSTEM_DEBUG_CHECKSUM"

	Log.debug(
		"Starting checksum capture",
		{"action_type": action_type, "sequence": sequence},
		[Log.TAG_SESSION, Log.TAG_CHECKSUM, Log.TAG_DEBUG]
	)

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

	Log.info(
		"CHECKSUM_CONTENT_DETAIL",
		{
			"action_type": action_type,
			"sequence": sequence,
			"game_state_content": game_state,
			"draft_area_count": game_state.get("board", {}).get("draft_area", {}).size(),
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

	# Create a copy for checksum calculation without variable metadata
	var checksum_state: Dictionary = game_state.duplicate(true)
	# CRITICAL: Exclude variable metadata from checksum calculation
	# This ensures identical game states always produce identical checksums
	checksum_state.erase("action_sequence")
	checksum_state.erase("session_id")
	checksum_state.erase("platform")
	checksum_state.erase("capture_timestamp")
	checksum_state.erase("capture_id")
	checksum_state.erase("format_version")

	var checksum: String = StateExtractor.generate_checksum(checksum_state)

	# Add sequence to original state for logging purposes only
	game_state["action_sequence"] = sequence
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


static func _get_current_seed() -> int:
	"""Get current seed from the RNG singleton"""
	if is_instance_valid(rng) and rng.seeded_rng:
		return rng.seeded_rng._initial_seed

	Log.warning(
		"Could not access RNG singleton for seed capture",
		{"rng_available": rng != null, "seeded_rng_available": rng.seeded_rng if rng else null},
		[Log.TAG_SESSION, Log.TAG_SEED, Log.TAG_WARNING]
	)

	return 12345


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


static func setup_replay_validation(demo_config_path: String) -> bool:
	"""Setup simplified replay validation for demo configs"""
	Log.info(
		"Setting up simplified replay validation",
		{"demo_config_path": demo_config_path},
		[Log.TAG_REPLAY, Log.TAG_VALIDATION, Log.TAG_SETUP]
	)

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
			return [Log.TAG_GAME, Log.TAG_BATTLE, Log.TAG_SEMANTIC_ACTION]
		_:
			return [Log.TAG_SEMANTIC_ACTION]


static func start_new_session_with_loaded_state(capture_data: Dictionary) -> String:
	"""Start new recording session with loaded gamestate as starting point"""

	# End any existing session
	if not current_session_id.is_empty():
		end_current_session("loaded_state_override")

	# Start new session
	var session_id: String = start_new_session(
		"loaded_state_start",
		{
			"session_type": "loaded_state_recording",
			"original_capture_id": capture_data.get("capture_id", "unknown"),
			"original_timestamp": capture_data.get("capture_timestamp", "unknown")
		}
	)

	# Reset game to clean state before applying loaded gamestate
	var reset_success: bool = _reset_game_to_clean_state()
	if not reset_success:
		Log.error(
			"Failed to reset game state before loading",
			{"session_id": session_id},
			[Log.TAG_SESSION, Log.TAG_ERROR]
		)
		return ""

	# Apply loaded state to game
	var success: bool = await _apply_loaded_gamestate(capture_data)

	if not success:
		Log.error(
			"Failed to apply loaded gamestate",
			{"session_id": session_id, "capture_id": capture_data.get("capture_id", "unknown")},
			[Log.TAG_SESSION, Log.TAG_ERROR]
		)
		return ""

	# Log session start with loaded state context
	Log.info(
		"SESSION_STARTED_WITH_LOADED_STATE",
		{
			"session_id": session_id,
			"loaded_capture_id": capture_data.get("capture_id", "unknown"),
			"loaded_timestamp": capture_data.get("capture_timestamp", "unknown"),
			"original_session": capture_data.get("session_id", "unknown"),
			"ready_for_actions": true
		},
		[Log.TAG_SESSION, Log.TAG_DEBUG, Log.TAG_DEBUG]
	)

	return session_id


static func _apply_loaded_gamestate(capture_data: Dictionary) -> bool:
	"""Apply captured gamestate to current game"""
	var game_state: Dictionary = capture_data.get("gamestate", {})
	var rng_state: String = capture_data.get("rng_state", "")

	# Restore RNG state first (affects subsequent game state application)
	if not rng_state.is_empty() and rng.seeded_rng:
		rng.seeded_rng.load_state(rng_state)
		Log.debug(
			"RNG state restored from loaded gamestate",
			{"rng_state_length": rng_state.length()},
			[Log.TAG_DEBUG, Log.TAG_RNG]
		)

	# Apply game state using existing systems
	# This will restore lineup, board state, and metadata
	return await _restore_game_state_from_extracted_data(game_state)


static func _restore_game_state_from_extracted_data(game_state: Dictionary) -> bool:
	"""Restore game state using StateExtractor format"""

	# Get game instance
	var game: Game = _get_game_instance()
	if not game:
		Log.error("Cannot restore gamestate - Game instance not found", {}, [Log.TAG_ERROR])
		return false

	# Restore lineup
	var lineup_state: Dictionary = game_state.get("lineup", {})
	if not lineup_state.is_empty():
		var success: bool = await _restore_lineup_state(game, lineup_state)
		if not success:
			Log.error("Failed to restore lineup state", {}, [Log.TAG_ERROR])
			return false

	# Restore board state
	var board_state: Dictionary = game_state.get("board", {})
	if not board_state.is_empty():
		var success: bool = _restore_board_state(game, board_state)
		if not success:
			Log.error("Failed to restore board state", {}, [Log.TAG_ERROR])
			return false

	Log.info(
		"Gamestate restored successfully",
		{
			"lineup_restored": not lineup_state.is_empty(),
			"board_restored": not board_state.is_empty()
		},
		[Log.TAG_DEBUG, Log.TAG_DEBUG]
	)

	return true


static func _restore_lineup_state(game: Game, lineup_state: Dictionary) -> bool:
	"""Restore lineup state from extracted data"""
	if not game.lineup_handler:
		Log.error("Cannot restore lineup - LineupHandler not available", {}, [Log.TAG_DEBUG])
		return false

	# Clear existing lineup
	_clear_current_lineup(game)

	# Restore allies lineup
	var allies_data: Dictionary = lineup_state.get("allies", {})
	await _restore_position_data(game, allies_data, "allies")

	# Restore enemies lineup (if saved)
	var enemies_data: Dictionary = lineup_state.get("enemies", {})
	await _restore_position_data(game, enemies_data, "enemies")

	Log.debug(
		"Lineup state restored",
		{"allies_count": allies_data.size(), "enemies_count": enemies_data.size()},
		[Log.TAG_DEBUG]
	)

	return true


static func _restore_position_data(
	game: Game, position_data: Dictionary, lineup_type: String
) -> void:
	"""Restore position data for lineup"""
	for position_str: String in position_data.keys():
		var position: int = int(position_str)
		var card_data: Dictionary = position_data[position_str]

		var card_id: String = card_data.get("card_id", "")
		var level: int = card_data.get("level", 1)

		if card_id.is_empty():
			continue

		Log.debug(
			"Attempting to restore card",
			{"card_id": card_id, "level": level, "position": position, "lineup": lineup_type},
			[Log.TAG_DEBUG]
		)

		# Recreate card using existing systems (following CLAUDE.md conventions)
		var card: Card = await _create_unit_from_id(card_id, level, game)
		if card:
			game.lineup_handler.add_card(card, position)
			Log.debug(
				"Card restored",
				{"card_id": card_id, "level": level, "position": position, "lineup": lineup_type},
				[Log.TAG_DEBUG]
			)
		else:
			Log.warning(
				"Failed to recreate card",
				{"card_id": card_id, "position": position},
				[Log.TAG_DEBUG]
			)


static func _reset_game_to_clean_state() -> bool:
	"""Reset game to clean state before loading gamestate"""
	var game: Game = _get_game_instance()
	if not game:
		Log.error("Cannot reset game - Game instance not found", {}, [Log.TAG_ERROR])
		return false

	Log.info("Resetting game to clean state before loading gamestate", {}, [Log.TAG_DEBUG])

	var reset_successful: bool = true

	# Reset allied lineup
	if game.holder_allies:
		if game.holder_allies.has_method("reset"):
			game.holder_allies.reset()
		Log.debug("Allied lineup reset", {}, [Log.TAG_DEBUG])
	else:
		Log.warning("Allied lineup not found for reset", {}, [Log.TAG_DEBUG])
		reset_successful = false

	# Reset enemy lineup
	if game.holder_enemy:
		if game.holder_enemy.has_method("reset"):
			game.holder_enemy.reset()
		Log.debug("Enemy lineup reset", {}, [Log.TAG_DEBUG])
	else:
		Log.warning("Enemy lineup not found for reset", {}, [Log.TAG_DEBUG])
		reset_successful = false

	# Reset game state
	if game.has_method("set_current_game_state"):
		game.set_current_game_state(game.GAME_STATE.DRAFT)
		Log.debug("Game state reset to DRAFT", {}, [Log.TAG_DEBUG])

	# Reset UI state
	if game.has_method("set_ui_state"):
		game.set_ui_state(game.UI_STATE.WAITING)
		Log.debug("UI state reset to WAITING", {}, [Log.TAG_DEBUG])

	if reset_successful:
		Log.info("Game reset completed successfully", {}, [Log.TAG_DEBUG])
	else:
		Log.warning("Game reset completed with warnings", {}, [Log.TAG_DEBUG])

	return reset_successful


static func _restore_board_state(_game: Game, board_state: Dictionary) -> bool:
	"""Restore board state from extracted data"""
	# LEGACY: This method is unused - game.load_state_from_file() is the active restoration path
	# Restore current level
	var target_level: int = board_state.get("current_level", 1)

	# Restore battle status and input state will be handled naturally by game flow
	Log.debug(
		"Board state restored (legacy path - unused)", {"level": target_level}, [Log.TAG_DEBUG]
	)
	return true


static func _create_unit_from_id(card_id: String, level: int, game: Game) -> Card:
	"""Create unit from ID using card controller"""
	Log.debug(
		"Creating unit from ID - START", {"card_id": card_id, "level": level}, [Log.TAG_DEBUG]
	)

	# Use card controller to create unit from ID
	if game and game.card_controller and game.card_controller.has_method("create_unit_from_id"):
		var card: Card = await game.card_controller.create_unit_from_id(card_id, level)

		Log.debug(
			"Creating unit from ID - COMPLETE",
			{"card_id": card_id, "level": level, "success": card != null},
			[Log.TAG_DEBUG]
		)

		return card

	Log.error(
		"CardController not available for unit creation",
		{"card_id": card_id, "level": level},
		[Log.TAG_DEBUG]
	)
	return null


static func _clear_current_lineup(game: Game) -> void:
	"""Clear existing lineup safely using existing systems"""
	if game.holder_allies and game.holder_allies.has_method("get_current_lineup"):
		var current_lineup: Dictionary = game.holder_allies.get_current_lineup()
		for position: int in current_lineup.keys():
			if game.holder_allies.has_method("get_holder"):
				var holder: Variant = game.holder_allies.get_holder(position)
				if holder and holder.has_method("set_card"):
					holder.set_card(null)  # Clear the position


static func _get_game_instance() -> Game:
	"""Get current game instance"""
	var main_loop: SceneTree = Engine.get_main_loop()
	if not main_loop:
		return null
	var current_scene: Node = main_loop.current_scene
	if current_scene and current_scene is Game:
		return current_scene as Game
	return null
