class_name SemanticActionMapper

# Maps semantic action types to debug action names for replay generation

# Core mapping from semantic action types to debug actions
static var ACTION_MAPPINGS: Dictionary = {
	"draft.reroll": "game.draft.reroll_player",
	"draft.upgrade": "game.draft.upgrade_player",
	"draft.toggle_line": "game.draft.toggle_column_player",
	"draft.remove_card": "game.draft.remove_block_player",
	"lineup.move_card": "game.lineup.move_card_player",
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

	# Add completion action - always use replay_complete which is context-aware
	# It will automatically detect automated vs manual mode and behave appropriately
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


## CRITICAL: Create replay config with comprehensive state validation integration
## This method ensures ALL semantic actions are validated during replay
static func create_replay_config_with_validation(
	session_id: String,
	debug_sequence: Array[Dictionary],
	metadata: Dictionary = {},
	mode: String = "automated",
	validation_enabled: bool = true
) -> Dictionary:
	"""Create replay config with automatic state validation injection - COMPANY SURVIVAL CRITICAL"""

	Log.info(
		"Creating replay config with state validation",
		{
			"session_id": session_id,
			"actions_count": debug_sequence.size(),
			"mode": mode,
			"validation_enabled": validation_enabled
		},
		["replay", "validation", "config_generation"]
	)

	# Start with base config
	var config: Dictionary = {
		"description": _generate_validation_description(session_id, mode, validation_enabled),
		"session_id": session_id,
		"actions": [],
		"metadata":
		_generate_validation_metadata(session_id, debug_sequence, mode, validation_enabled)
	}

	# Add any provided metadata
	for key: String in metadata:
		config.metadata[key] = metadata[key]

	# Add hide menu action first for clean replay
	config.actions.append("system.debug.hide_menu")

	if validation_enabled:
		# Inject state validation actions between semantic actions
		config.actions = _inject_validation_actions(debug_sequence, session_id)
	else:
		# Use standard action sequence without validation
		for debug_action: Dictionary in debug_sequence:
			config.actions.append(debug_action.get("action_name", "unknown"))

	# Add completion action - always use replay_complete which is context-aware
	# It will automatically detect automated vs manual mode and behave appropriately
	config.actions.append("system.debug.replay_complete")

	Log.info(
		"Replay config with validation created",
		{
			"session_id": session_id,
			"total_actions": config.actions.size(),
			"validation_enabled": validation_enabled,
			"mode": mode
		},
		["replay", "validation", "config_complete"]
	)

	return config


## CRITICAL: Inject validation actions between semantic actions for comprehensive testing
static func _inject_validation_actions(
	debug_sequence: Array[Dictionary], session_id: String
) -> Array[String]:
	"""Inject state validation actions between each semantic action for comprehensive testing"""
	var enhanced_actions: Array[String] = []

	Log.debug(
		"Injecting validation actions",
		{"session_id": session_id, "original_actions": debug_sequence.size()},
		["replay", "validation", "injection"]
	)

	# Add initial state capture before any actions
	enhanced_actions.append("system.debug.capture_initial_state")

	for i: int in range(debug_sequence.size()):
		var debug_action: Dictionary = debug_sequence[i]
		var action_name: String = debug_action.get("action_name", "unknown")
		var sequence: int = debug_action.get("sequence", i + 1)

		# Add pre-action state validation
		enhanced_actions.append("system.debug.validate_pre_action_state")

		# Add the actual semantic action
		enhanced_actions.append(action_name)

		# Add post-action state validation
		enhanced_actions.append("system.debug.validate_post_action_state")

		# Add state comparison validation
		enhanced_actions.append("system.debug.compare_action_states")

		Log.debug(
			"Injected validation for action",
			{"action_name": action_name, "sequence": sequence, "session_id": session_id},
			["replay", "validation", "action_injection"]
		)

	# Add final state validation
	enhanced_actions.append("system.debug.validate_final_state")

	Log.info(
		"Validation injection completed",
		{
			"session_id": session_id,
			"original_actions": debug_sequence.size(),
			"enhanced_actions": enhanced_actions.size(),
			"validation_ratio":
			(
				float(enhanced_actions.size()) / float(debug_sequence.size())
				if debug_sequence.size() > 0
				else 0.0
			)
		},
		["replay", "validation", "injection_complete"]
	)

	return enhanced_actions


## Generate description for validation-enabled configs
static func _generate_validation_description(
	session_id: String, mode: String, validation_enabled: bool
) -> String:
	"""Generate description indicating validation status"""
	var base_desc: String = "Generated replay from semantic session: %s" % session_id
	var validation_status: String = (
		" (WITH STATE VALIDATION)" if validation_enabled else " (NO VALIDATION)"
	)

	if mode == "manual":
		return base_desc + validation_status + " - Manual verification mode"
	else:
		return base_desc + validation_status + " - Automated testing mode"


## Generate metadata for validation-enabled configs
static func _generate_validation_metadata(
	session_id: String, debug_sequence: Array[Dictionary], mode: String, validation_enabled: bool
) -> Dictionary:
	"""Generate metadata with validation configuration"""
	var base_metadata: Dictionary = _generate_metadata(session_id, debug_sequence, mode)

	# Add validation-specific metadata
	base_metadata["state_validation_enabled"] = validation_enabled
	base_metadata["validation_injection"] = validation_enabled
	base_metadata["company_survival_mode"] = true  # Mark as critical for company survival

	if validation_enabled:
		base_metadata["validation_actions_injected"] = true
		base_metadata["validation_type"] = "comprehensive_state_validation"
		base_metadata["performance_monitoring"] = true
		base_metadata["failure_detection"] = "automatic"
	else:
		base_metadata["validation_actions_injected"] = false
		base_metadata["validation_type"] = "none"

	return base_metadata


## Create state validation actions for debugging workflow
## These are the actions that get injected between semantic actions
static func create_validation_debug_actions() -> Array[Dictionary]:
	"""Create debug action definitions for state validation workflow"""
	return [
		{
			"action_name": "system.debug.capture_initial_state",
			"description": "Capture initial game state before replay",
			"category": "System",
			"group": "State Validation"
		},
		{
			"action_name": "system.debug.validate_pre_action_state",
			"description": "Validate pre-action state capture",
			"category": "System",
			"group": "State Validation"
		},
		{
			"action_name": "system.debug.validate_post_action_state",
			"description": "Validate post-action state capture",
			"category": "System",
			"group": "State Validation"
		},
		{
			"action_name": "system.debug.compare_action_states",
			"description": "Compare pre and post action states for validation",
			"category": "System",
			"group": "State Validation"
		},
		{
			"action_name": "system.debug.validate_final_state",
			"description": "Validate final game state after replay completion",
			"category": "System",
			"group": "State Validation"
		}
	]


## PRODUCTION INTEGRATION: Generate replay config for production use
## Uses validation by default unless explicitly disabled
static func generate_production_replay_config(session_id: String) -> Dictionary:
	"""Generate production-ready replay config with full validation - DEFAULT FOR COMPANY SURVIVAL"""

	# Extract semantic actions from session logs
	var semantic_actions: Array = _extract_semantic_actions_from_session(session_id)

	if semantic_actions.is_empty():
		Log.error(
			"No semantic actions found for session",
			{"session_id": session_id},
			["replay", "validation", "generation_error"]
		)
		return {}

	# Convert to debug action sequence
	var debug_sequence: Array[Dictionary] = generate_debug_action_sequence(semantic_actions)

	# Create config with validation enabled by default
	return create_replay_config_with_validation(
		session_id,
		debug_sequence,
		{"production_mode": true, "validation_required": true},
		"automated",
		true  # validation_enabled = true for company survival
	)


## Extract semantic actions from session logs
static func _extract_semantic_actions_from_session(session_id: String) -> Array:
	"""Extract semantic actions from session logs for replay generation"""
	# This is a placeholder implementation - in production this would parse actual log files
	# For now, return empty array to avoid errors
	Log.warning(
		"Semantic action extraction not yet implemented - using placeholder",
		{"session_id": session_id},
		["replay", "validation", "placeholder"]
	)
	return []
