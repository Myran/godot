class_name SemanticActionMapper

# Maps semantic action types to debug action names for replay generation

# Core mapping from semantic action types to debug actions
static var ACTION_MAPPINGS: Dictionary = {
	"draft.reroll": "game.draft.reroll_player",
	"draft.upgrade": "game.draft.upgrade_player",
	"draft.toggle_line": "game.draft.toggle_column_player",
	"draft.remove_card": "game.draft.remove_block_player",
	"lineup.move_card": "game.lineup.move_card_player",
	"lineup.add_card": "game.lineup.add_card_player",
	"lineup.remove_card": "game.lineup.remove_card_player",
	"transition.change_state": "game.state.transition_player",
	"battle.start": "game.battle.start_player"
}


static func map_semantic_action_to_debug_action(semantic_type: String) -> String:
	"""Map a semantic action type to its corresponding debug action name"""
	return ACTION_MAPPINGS.get(semantic_type, "system.debug.unknown_semantic_action")


static func generate_debug_action_sequence(semantic_actions: Array) -> Array[Dictionary]:
	"""Convert semantic actions to debug action sequence with parameters"""
	var debug_sequence: Array[Dictionary] = []

	for semantic_action: Dictionary in semantic_actions:
		var debug_action: Dictionary = _convert_semantic_to_debug_action(semantic_action)
		if not debug_action.is_empty():
			debug_sequence.append(debug_action)

	return debug_sequence


static func create_replay_config(
	session_id: String,
	debug_sequence: Array[Dictionary],
	metadata: Dictionary = {},
	mode: String = "automated"
) -> Dictionary:
	"""Create a complete replay configuration from debug action sequence with automatic menu hiding
	
	Args:
		session_id: Unique identifier for the semantic session
		debug_sequence: Array of debug actions to include
		metadata: Additional metadata to include in config
		mode: "automated" (includes quit action) or "manual" (no quit action for manual verification)
	"""
	var config: Dictionary = {
		"description": _generate_description(session_id, mode),
		"session_id": session_id,
		"actions": [],
		"metadata": _generate_metadata(session_id, debug_sequence, mode)
	}

	# Add any provided metadata
	for key: String in metadata:
		config.metadata[key] = metadata[key]

	# Add hide menu action as first action for clean replay output
	config.actions.append("system.debug.hide_menu")

	# Extract action names for the config
	for debug_action: Dictionary in debug_sequence:
		config.actions.append(debug_action.get("action_name", "unknown"))

	# Add completion action based on mode
	if mode == "automated":
		config.actions.append("system.debug.quit_application")
	else:  # manual mode
		config.actions.append("system.debug.replay_complete")

	return config


static func _generate_description(session_id: String, mode: String) -> String:
	"""Generate appropriate description based on replay mode"""
	var base_desc: String = "Generated replay from semantic session: %s" % session_id
	if mode == "manual":
		return base_desc + " (Manual verification - no auto-quit)"
	else:
		return base_desc + " (Automated testing - auto-quit)"


static func _generate_metadata(
	session_id: String, debug_sequence: Array[Dictionary], mode: String
) -> Dictionary:
	"""Generate metadata with mode information"""
	return {
		"source_session": session_id,
		"generation_timestamp": Time.get_datetime_string_from_system(),
		"semantic_action_count": debug_sequence.size(),
		"replay_mode": mode,
		"auto_quit": mode == "automated",
		"manual_verification": mode == "manual"
	}


static func validate_debug_action_mapping(semantic_type: String) -> bool:
	"""Check if a semantic action type has a valid debug action mapping"""
	return ACTION_MAPPINGS.has(semantic_type)


static func get_supported_semantic_types() -> Array[String]:
	"""Get list of all supported semantic action types"""
	var types: Array[String] = []
	for type: String in ACTION_MAPPINGS:
		types.append(type)
	return types


static func get_mapping_coverage_report(semantic_actions: Array) -> Dictionary:
	"""Generate a report on mapping coverage for a set of semantic actions"""
	var report: Dictionary = {
		"total_actions": semantic_actions.size(),
		"mapped_actions": 0,
		"unmapped_actions": 0,
		"unmapped_types": []
	}

	var unmapped_types_set: Dictionary = {}

	for action: Dictionary in semantic_actions:
		var semantic_type: String = action.get("type", "")
		if validate_debug_action_mapping(semantic_type):
			report.mapped_actions += 1
		else:
			report.unmapped_actions += 1
			if not unmapped_types_set.has(semantic_type):
				unmapped_types_set[semantic_type] = true
				report.unmapped_types.append(semantic_type)

	return report


static func _convert_semantic_to_debug_action(semantic_action: Dictionary) -> Dictionary:
	"""Convert a single semantic action to debug action format"""
	var semantic_type: String = semantic_action.get("type", "")
	var debug_action_name: String = map_semantic_action_to_debug_action(semantic_type)

	if debug_action_name.is_empty():
		return {}

	var debug_action: Dictionary = {
		"action_name": debug_action_name,
		"semantic_type": semantic_type,
		"session_id": semantic_action.get("session_id", ""),
		"count": semantic_action.get("count", 0),
		"timestamp_ms": semantic_action.get("timestamp_ms", 0),
		"session_elapsed_ms": semantic_action.get("session_elapsed_ms", 0)
	}

	# Include action data/parameters
	var data: Dictionary = semantic_action.get("data", {})
	if not data.is_empty():
		debug_action["params"] = data

	return debug_action
