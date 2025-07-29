class_name StateExtractor
extends RefCounted

## StateExtractor - Continuous state checksum system for recording and playback integrity validation
##
## This utility class provides deterministic game state extraction and checksum generation
## for validating replay integrity and ensuring consistent state across different platforms.
##
## Key Features:
## - Real-time state extraction (< 5ms performance target)
## - Deterministic checksum generation using DictUtils.deterministic_hash()
## - Data normalization for cross-platform consistency
## - Integration with SessionManager for pre-action state capture
## - Comprehensive error handling for edge cases
##
## Usage Example:
## var game_state: Dictionary = StateExtractor.extract_game_state()
## var checksum: String = StateExtractor.generate_checksum(game_state)
## if StateExtractor.is_state_valid(game_state):
##     SessionManager.store_pre_action_state(checksum, game_state)


## Extract complete game state from all relevant game components
## Returns normalized dictionary containing current game state
## Performance target: < 5ms execution time
static func extract_game_state() -> Dictionary:
	var start_time: int = Time.get_ticks_msec()

	var game_state: Dictionary = {}

	# Extract core game components
	game_state["lineup"] = extract_lineup_state()
	game_state["board"] = extract_board_state()
	game_state["metadata"] = _extract_metadata()

	# Normalize data for deterministic hashing
	game_state = normalize_data(game_state)

	var execution_time: int = Time.get_ticks_msec() - start_time

	# Log performance metrics
	Log.debug(
		"StateExtractor: Game state extracted",
		{
			"execution_time_ms": execution_time,
			"state_size": game_state.size(),
			"performance_target_met": execution_time < 5
		},
		["state_extractor", "performance"]
	)

	# Warn if performance target missed
	if execution_time >= 5:
		Log.warning(
			"StateExtractor: Performance target missed",
			{"execution_time_ms": execution_time, "target_ms": 5},
			["state_extractor", "performance", "warning"]
		)

	return game_state


## Generate deterministic checksum for game state dictionary
## Uses DictUtils.deterministic_hash() for consistency
## Returns SHA256 hash string (64 characters hex)
static func generate_checksum(data: Dictionary) -> String:
	if not is_state_valid(data):
		Log.error(
			"StateExtractor: Cannot generate checksum for invalid state",
			{"data_size": data.size()},
			["state_extractor", "error"]
		)
		return ""

	# Use existing DictUtils implementation for consistency
	var checksum: String = DictUtils.deterministic_hash(data)

	Log.debug(
		"StateExtractor: Checksum generated",
		{"checksum": checksum, "data_size": data.size()},
		["state_extractor", "checksum"]
	)

	return checksum


## Normalize data for deterministic hashing and cross-platform consistency
## Handles float precision, key sorting, null values, and circular references
static func normalize_data(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}

	var normalized: Dictionary = {}

	# Process keys in deterministic order
	var sorted_keys: Array = DictUtils.keys_sorted(data)

	for key: Variant in sorted_keys:
		var value: Variant = data[key]
		var normalized_value: Variant = _normalize_value(value)

		# Skip null/invalid values to maintain consistency
		if normalized_value != null:
			normalized[key] = normalized_value

	return normalized


## Extract lineup state from game components
## Returns dictionary containing current lineup data
static func extract_lineup_state() -> Dictionary:
	var lineup_state: Dictionary = {}

	# Get the actual Game instance from the main scene
	var game: Game = _get_game_instance()
	if game:
		lineup_state["game_available"] = true

		# Extract real ally lineup data
		var allies_lineup: Dictionary[int, Card] = game.holder_allies.get_current_lineup()
		lineup_state["allies"] = _extract_lineup_data(allies_lineup)

		# Extract real enemy lineup data
		var enemy_lineup: Dictionary[int, Card] = game.holder_enemy.get_current_lineup()
		lineup_state["enemies"] = _extract_lineup_data(enemy_lineup)

		# Extract game state information
		lineup_state["current_game_state"] = core.GameState.keys()[
			game.game_handler.current_gamestate
		]
		lineup_state["ui_state"] = core.UIState.keys()[game.ui_state]
	else:
		lineup_state["game_available"] = false
		lineup_state["allies"] = {}
		lineup_state["enemies"] = {}

	# Add lineup metadata
	lineup_state["extraction_type"] = "lineup_state"

	return lineup_state


## Extract board state from game components
## Returns dictionary containing current board data
static func extract_board_state() -> Dictionary:
	var board_state: Dictionary = {}

	# Get the actual Game instance from the main scene
	var game: Game = _get_game_instance()
	if game:
		board_state["game_available"] = true

		# Extract clicker/draft area state - include all block types for deterministic checksums
		var draft_blocks: Array[Block] = []
		if game.clicker and game.clicker.has_method("get_all_cards"):
			var all_blocks: Array[Block] = game.clicker.get_all_cards()
			for block: Block in all_blocks:
				if block:
					draft_blocks.append(block)
		board_state["draft_area"] = _extract_draft_data(draft_blocks)

		# Extract level information
		board_state["current_level"] = (
			game.level_controller.get_current_level()
			if game.level_controller and game.level_controller.has_method("get_current_level")
			else 0
		)

		# Extract battle state if available
		if game.battle_handler:
			board_state["battle_active"] = (
				game.battle_handler.is_battle_active()
				if game.battle_handler.has_method("is_battle_active")
				else false
			)
		else:
			board_state["battle_active"] = false

		# Extract input state
		board_state["input_locked"] = (
			game.input_handler.is_locked()
			if game.input_handler and game.input_handler.has_method("is_locked")
			else false
		)
	else:
		board_state["game_available"] = false
		board_state["draft_area"] = []
		board_state["current_level"] = 0
		board_state["battle_active"] = false
		board_state["input_locked"] = false

	# Add board metadata
	board_state["extraction_type"] = "board_state"

	return board_state


## Validate that game state dictionary is valid for checksum generation
## Returns true if state can be safely processed
static func is_state_valid(data: Dictionary) -> bool:
	# Handle null/empty state
	if not data or data.is_empty():
		Log.debug(
			"StateExtractor: Empty state detected",
			{"data_null": data == null, "data_empty": data.is_empty()},
			["state_extractor", "validation"]
		)
		return false

	# Validate deterministic keys
	if not DictUtils.validate_deterministic_keys(data):
		Log.warning(
			"StateExtractor: Non-deterministic keys detected",
			{"data_size": data.size()},
			["state_extractor", "validation", "warning"]
		)
		return false

	# Check for circular references (basic detection)
	if _has_circular_references(data):
		Log.error(
			"StateExtractor: Circular references detected",
			{"data_size": data.size()},
			["state_extractor", "error", "circular_ref"]
		)
		return false

	return true


## Private helper: Extract metadata about the current game state
static func _extract_metadata() -> Dictionary:
	var metadata: Dictionary = {}

	metadata["extractor_version"] = "1.0.0"

	return metadata


## Private helper: Normalize individual values for consistency
static func _normalize_value(value: Variant) -> Variant:
	# Handle null values
	if value == null:
		return null

	match typeof(value):
		TYPE_FLOAT:
			# Normalize floats to 6 decimal places for consistency
			# Type is guaranteed to be float by the match check
			var float_val: float = value
			var normalized_float: float = snappedf(float_val, 0.000001)
			return normalized_float

		TYPE_DICTIONARY:
			# Recursively normalize nested dictionaries
			# Type is guaranteed to be Dictionary by the match check
			var dict_val: Dictionary = value
			return normalize_data(dict_val)

		TYPE_ARRAY:
			# Normalize arrays by processing each element
			var normalized_array: Array = []
			for item: Variant in value:
				var normalized_item: Variant = _normalize_value(item)
				if normalized_item != null:
					normalized_array.append(normalized_item)
			return normalized_array

		TYPE_STRING:
			# Ensure string consistency (trim whitespace)
			return str(value).strip_edges()

		_:
			# Return other types as-is
			return value


## Private helper: Basic circular reference detection
static func _has_circular_references(data: Dictionary, visited: Array = []) -> bool:
	# Simple depth-based detection (prevents infinite recursion)
	if visited.size() > 10:  # Maximum reasonable nesting depth
		return true

	for key: Variant in data:
		var value: Variant = data[key]

		# Check if we've seen this exact dictionary before
		if typeof(value) == TYPE_DICTIONARY:
			var dict_value: Dictionary = value
			if dict_value in visited:
				return true

			var new_visited: Array = visited.duplicate()
			new_visited.append(dict_value)

			if _has_circular_references(dict_value, new_visited):
				return true

	return false


## Private helper: Get the Game instance from the main scene
static func _get_game_instance() -> Game:
	# Access the main scene and find the Game node
	var main_loop: SceneTree = Engine.get_main_loop()
	if not main_loop:
		Log.warning("StateExtractor: No main loop available", {}, ["state_extractor", "debug"])
		return null

	var current_scene: Node = main_loop.current_scene
	if not current_scene:
		Log.warning("StateExtractor: No current scene available", {}, ["state_extractor", "debug"])
		return null

	Log.debug(
		"StateExtractor: Scene info",
		{
			"scene_name": current_scene.name,
			"scene_type": current_scene.get_class(),
			"scene_children":
			current_scene.get_children().map(func(child: Node) -> String: return child.name)
		},
		["state_extractor", "debug"]
	)

	# Find the Game node with strong typing - fail fast if wrong type
	if not current_scene.has_node("Game"):
		Log.warning(
			"StateExtractor: Game node not found in current scene",
			{
				"scene_name": current_scene.name,
				"available_children":
				current_scene.get_children().map(func(child: Node) -> String: return child.name)
			},
			["state_extractor", "debug"]
		)
		return null

	var game_node: Game = current_scene.get_node("Game")
	Log.debug(
		"StateExtractor: Game node found",
		{
			"game_node_name": str(game_node.name) if game_node else "null",
			"game_node_type": game_node.get_class() if game_node else "null"
		},
		["state_extractor", "debug"]
	)
	return game_node


## Private helper: Extract card data from lineup dictionary
static func _extract_lineup_data(lineup: Dictionary[int, Card]) -> Dictionary:
	var lineup_data: Dictionary = {}

	# Use DictUtils for deterministic iteration
	for item: Dictionary in DictUtils.get_sorted_items(lineup):
		var position: int = item.key
		var card: Card = item.value

		if card:
			lineup_data[position] = {
				"card_id": card.card_info.id if card.card_info else "",
				"level": card.level,
				"health": card.unit_info.current_health if card.unit_info else 0,
				"attack": card.unit_info.current_attack if card.unit_info else 0,
				"position": position
			}

	return lineup_data


## Private helper: Extract draft area block data (cards and items)
static func _extract_draft_data(draft_blocks: Array[Block]) -> Array:
	var draft_data: Array = []

	for i: int in range(draft_blocks.size()):
		var block: Block = draft_blocks[i]
		if block:
			var block_data: Dictionary = {"object_type": block.object_type, "draft_position": i}

			# Add type-specific data
			if block.object_type == core.ObjectType.CARD:
				var card: Card = block as Card
				block_data["card_id"] = card.card_info.id if card.card_info else ""
				block_data["level"] = card.level
			elif block.object_type == core.ObjectType.BLOCK_ITEM:
				block_data["level"] = block.level if "level" in block else 0
			else:
				# For other block types, just include basic info
				block_data["level"] = block.level if "level" in block else 0

			draft_data.append(block_data)

	return draft_data
