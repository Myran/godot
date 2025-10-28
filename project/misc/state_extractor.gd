class_name StateExtractor
extends RefCounted


static func extract_game_state() -> Dictionary:
	var start_time: int = Time.get_ticks_msec()

	var game_state: Dictionary = {}

	game_state["lineup"] = extract_lineup_state()
	game_state["board"] = extract_board_state()
	game_state["metadata"] = _extract_metadata()

	game_state = normalize_data(game_state)

	var execution_time: int = Time.get_ticks_msec() - start_time

	Log.debug(
		"StateExtractor: Game state extracted",
		{
			"execution_time_ms": execution_time,
			"state_size": game_state.size(),
			"performance_target_met": execution_time < 5
		},
		["state_extractor", "performance"]
	)

	if execution_time >= 5:
		Log.warning(
			"StateExtractor: Performance target missed",
			{"execution_time_ms": execution_time, "target_ms": 5},
			["state_extractor", "performance", "warning"]
		)

	return game_state


static func generate_checksum(data: Dictionary) -> String:
	if not is_state_valid(data):
		Log.error(
			"StateExtractor: Cannot generate checksum for invalid state",
			{"data_size": data.size()},
			["state_extractor", "error"]
		)
		return ""

	var checksum: String = DictUtils.deterministic_hash(data)

	Log.debug(
		"StateExtractor: Checksum generated",
		{"checksum": checksum, "data_size": data.size()},
		["state_extractor", "checksum"]
	)

	return checksum


static func normalize_data(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}

	var normalized: Dictionary = {}

	var sorted_keys: Array = DictUtils.keys_sorted(data)

	for key: Variant in sorted_keys:
		var value: Variant = data[key]
		var normalized_value: Variant = _normalize_value(value)

		if normalized_value != null:
			normalized[key] = normalized_value

	return normalized


static func extract_lineup_state() -> Dictionary:
	var lineup_state: Dictionary = {}

	var game: Game = _get_game_instance()
	if game:
		lineup_state["game_available"] = true

		var allies_lineup: Dictionary[int, Card] = game.holder_allies.get_current_lineup()
		lineup_state["allies"] = _extract_lineup_data(allies_lineup)

		var enemy_lineup: Dictionary[int, Card] = game.holder_enemy.get_current_lineup()
		lineup_state["enemies"] = _extract_lineup_data(enemy_lineup)

		lineup_state["current_game_state"] = core.GameState.keys()[
			game.game_handler.current_gamestate
		]
		lineup_state["ui_state"] = core.UIState.keys()[game.ui_state]
	else:
		lineup_state["game_available"] = false
		lineup_state["allies"] = {}
		lineup_state["enemies"] = {}

	lineup_state["extraction_type"] = "lineup_state"

	return lineup_state


static func extract_allied_lineup_only() -> Dictionary:
	var start_time: int = Time.get_ticks_msec()

	var lineup_data: Dictionary = {}

	var game: Game = _get_game_instance()
	if game:
		lineup_data["game_available"] = true

		var allies_lineup: Dictionary[int, Card] = game.holder_allies.get_current_lineup()
		lineup_data["allies"] = _extract_lineup_data(allies_lineup)

		# Include game state context for validation
		lineup_data["current_game_state"] = core.GameState.keys()[
			game.game_handler.current_gamestate
		]
		lineup_data["ui_state"] = core.UIState.keys()[game.ui_state]
	else:
		lineup_data["game_available"] = false
		lineup_data["allies"] = {}

	lineup_data["lineup_type"] = "allied_only"
	lineup_data["extraction_type"] = "allied_lineup_state"
	lineup_data["metadata"] = _extract_metadata()

	var execution_time: int = Time.get_ticks_msec() - start_time

	Log.debug(
		"StateExtractor: Allied lineup extracted",
		{
			"execution_time_ms": execution_time,
			"allied_units": lineup_data.get("allies", {}).size(),
			"game_available": lineup_data.get("game_available", false)
		},
		["state_extractor", "lineup", "allied"]
	)

	return normalize_data(lineup_data)


static func extract_enemy_lineup_only() -> Dictionary:
	var start_time: int = Time.get_ticks_msec()

	var lineup_data: Dictionary = {}

	var game: Game = _get_game_instance()
	if game:
		lineup_data["game_available"] = true

		var enemy_lineup: Dictionary[int, Card] = game.holder_enemy.get_current_lineup()
		lineup_data["enemies"] = _extract_lineup_data(enemy_lineup)

		# Include game state context for validation
		lineup_data["current_game_state"] = core.GameState.keys()[
			game.game_handler.current_gamestate
		]
		lineup_data["ui_state"] = core.UIState.keys()[game.ui_state]
	else:
		lineup_data["game_available"] = false
		lineup_data["enemies"] = {}

	lineup_data["lineup_type"] = "enemy_only"
	lineup_data["extraction_type"] = "enemy_lineup_state"
	lineup_data["metadata"] = _extract_metadata()

	var execution_time: int = Time.get_ticks_msec() - start_time

	Log.debug(
		"StateExtractor: Enemy lineup extracted",
		{
			"execution_time_ms": execution_time,
			"enemy_units": lineup_data.get("enemies", {}).size(),
			"game_available": lineup_data.get("game_available", false)
		},
		["state_extractor", "lineup", "enemy"]
	)

	return normalize_data(lineup_data)


static func extract_board_state() -> Dictionary:
	var board_state: Dictionary = {}

	var game: Game = _get_game_instance()
	if game:
		board_state["game_available"] = true

		var draft_blocks: Array[Block] = []
		if game.clicker and game.clicker.has_method("get_all_cards"):
			var all_blocks: Array[Block] = game.clicker.get_all_cards()
			for block: Block in all_blocks:
				if block:
					draft_blocks.append(block)
		board_state["draft_area"] = _extract_draft_data(draft_blocks)

		board_state["current_level"] = (
			game.level_controller.get_current_level()
			if game.level_controller and game.level_controller.has_method("get_current_level")
			else 0
		)

		if game.battle_handler:
			board_state["battle_active"] = (
				game.battle_handler.is_battle_active()
				if game.battle_handler.has_method("is_battle_active")
				else false
			)
		else:
			board_state["battle_active"] = false

		board_state["input_locked"] = (
			game.input_handler.is_locked()
			if game.input_handler and game.input_handler.has_method("is_locked")
			else false
		)
	else:
		board_state["game_available"] = false
		board_state["draft_area"] = {}
		board_state["current_level"] = 0
		board_state["battle_active"] = false
		board_state["input_locked"] = false

	board_state["extraction_type"] = "board_state"

	return board_state


static func is_state_valid(data: Dictionary) -> bool:
	if not data or data.is_empty():
		Log.debug(
			"StateExtractor: Empty state detected",
			{"data_null": data == null, "data_empty": data.is_empty()},
			["state_extractor", "validation"]
		)
		return false

	if not DictUtils.validate_deterministic_keys(data):
		Log.warning(
			"StateExtractor: Non-deterministic keys detected",
			{"data_size": data.size()},
			["state_extractor", "validation", "warning"]
		)
		return false

	if _has_circular_references(data):
		Log.error(
			"StateExtractor: Circular references detected",
			{"data_size": data.size()},
			["state_extractor", "error", "circular_ref"]
		)
		return false

	return true


static func _extract_metadata() -> Dictionary:
	var metadata: Dictionary = {}

	metadata["extractor_version"] = GameConstants.StateExtraction.VERSION_STRING

	return metadata


static func _normalize_value(value: Variant) -> Variant:
	if value == null:
		return null

	match typeof(value):
		TYPE_FLOAT:
			var float_val: float = value
			var normalized_float: float = snappedf(
				float_val, GameConstants.StateExtraction.NORMALIZATION_FACTOR
			)
			return normalized_float

		TYPE_DICTIONARY:
			var dict_val: Dictionary = value
			return normalize_data(dict_val)

		TYPE_ARRAY:
			var normalized_array: Array = []
			for item: Variant in value:
				var normalized_item: Variant = _normalize_value(item)
				if normalized_item != null:
					normalized_array.append(normalized_item)
			return normalized_array

		TYPE_STRING:
			return str(value).strip_edges()

		_:
			return value


static func _has_circular_references(data: Dictionary, visited: Array = []) -> bool:
	if visited.size() > GameConstants.DebugLimits.MAX_NESTING_DEPTH:
		return true

	for key: Variant in data:
		var value: Variant = data[key]

		if typeof(value) == TYPE_DICTIONARY:
			var dict_value: Dictionary = value
			if dict_value in visited:
				return true

			var new_visited: Array = visited.duplicate()
			new_visited.append(dict_value)

			if _has_circular_references(dict_value, new_visited):
				return true

	return false


static func _get_game_instance() -> Game:
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
			"scene_type": Utils.get_type(current_scene),
			"scene_children":
			current_scene.get_children().map(func(child: Node) -> String: return child.name)
		},
		["state_extractor", "debug"]
	)

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
			"game_node_type": str(Utils.get_type(game_node)) if game_node != null else "null"
		},
		["state_extractor", "debug"]
	)
	return game_node


static func _extract_lineup_data(lineup: Dictionary[int, Card]) -> Dictionary:
	var lineup_data: Dictionary = {}

	for item: Dictionary in DictUtils.get_sorted_items(lineup):
		var position: int = item.key
		var card: Card = item.value

		if card:
			# Use the card's own serialization method to get complete data
			var card_data: Dictionary = card.serialize_to_dict()

			# Add lineup-specific position data
			card_data["position"] = position

			Log.debug(
				"Lineup card serialized using card's own serialization",
				{
					"card_id": card_data.get("card_id", "unknown"),
					"level": card_data.get("level", 0),
					"position": position,
					"has_unit_state": card_data.has("unit_state"),
					"unit_checksum": card_data.get("unit_checksum", "")
				},
				["state_extractor", "lineup", "card_serialization"]
			)

			lineup_data[str(position)] = card_data

	return lineup_data


static func _extract_draft_data(_draft_blocks: Array[Block]) -> Dictionary:
	# ARCHITECTURAL FIX: Use grid position as key for direct location mapping
	var draft_data: Dictionary = {}

	var game: Game = _get_game_instance()
	if not game or not game.clicker or not game.clicker.level:
		return draft_data

	var level_controller: LevelController = game.clicker.level

	# Iterate through all grid positions and extract blocks by location
	for grid_pos: Vector2i in level_controller.block_grid.keys():
		var block: Block = level_controller.block_grid[grid_pos]
		if block:
			# Use distributed block-level serialization
			var block_data: Dictionary = block.serialize_to_dict()

			# CRITICAL: Remove draft_position from block data - grid position is now the dictionary key
			if block_data.has("draft_position"):
				block_data.erase("draft_position")

			# Convert Vector2i to string for JSON compatibility while preserving exact position mapping
			var grid_pos_str: String = "(%d, %d)" % [grid_pos.x, grid_pos.y]
			draft_data[grid_pos_str] = block_data

			# Log serialization for debugging
			Log.debug(
				"Block serialized with Vector2i grid position as string dictionary key",
				{
					"grid_pos": grid_pos,
					"grid_pos_str": grid_pos_str,
					"object_type": block_data.get("object_type", "unknown"),
					"serialization_method": "block.serialize_to_dict()"
				},
				["state_extractor", "serialization", "distributed"]
			)

	return draft_data
