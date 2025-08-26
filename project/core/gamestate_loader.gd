class_name GamestateLoader extends RefCounted


static func load_state_from_file(game: Game, gamestate_file_path: String) -> bool:
	"""Load and restore gamestate from file without restarting the app"""
	Log.info(
		"Loading gamestate from file in current session",
		{"file_path": gamestate_file_path},
		[Log.TAG_DEBUG, "gamestate", "load"]
	)

	# CRITICAL: Enable gamestate loading mode IMMEDIATELY to prevent any tilemap block creation
	if game.level_controller:
		game.level_controller.set_gamestate_loading_mode(true)
	# Lock input during gamestate loading to prevent user interaction
	if game.input_handler:
		game.input_handler.lock_input()

	# Read and parse JSON file
	var file: FileAccess = FileAccess.open(gamestate_file_path, FileAccess.READ)
	if not file:
		Log.error(
			"Cannot open gamestate file",
			{"file_path": gamestate_file_path},
			[Log.TAG_DEBUG, "gamestate", "load", "error"]
		)
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		Log.error(
			"Failed to parse gamestate JSON",
			{"file_path": gamestate_file_path, "error": parse_result},
			[Log.TAG_DEBUG, "gamestate", "load", "error"]
		)
		return false

	var gamestate_data: Dictionary = json.data

	# Extract the actual gamestate and RNG data
	var gamestate: Dictionary = gamestate_data.get("gamestate", {})
	var rng_state: String = gamestate_data.get("rng_state", "")

	if gamestate.is_empty():
		Log.error(
			"No gamestate data found in file",
			{"file_path": gamestate_file_path},
			[Log.TAG_DEBUG, "gamestate", "load", "error"]
		)
		return false

	# Restore RNG state first
	if not rng_state.is_empty():
		if rng.seeded_rng and rng.seeded_rng.has_method("load_state"):
			rng.seeded_rng.load_state(rng_state)
			Log.info("RNG state restored successfully", {}, [Log.TAG_DEBUG, "gamestate", "rng"])

	# Reset all game state before restoration
	@warning_ignore("redundant_await")
	await _reset_all_game_state_for_loading(game)

	# Restore board content
	await _restore_board_content(game, gamestate)

	# Restore lineup and transition to the saved game state
	var lineup_data: Dictionary = gamestate.get("lineup", {})
	var saved_game_state: String = lineup_data.get("current_game_state", "START")

	# Set the appropriate game state and transition
	var target_state: core.GameState
	match saved_game_state:
		"DRAFT":
			target_state = core.GameState.DRAFT
		"PREPARE":
			target_state = core.GameState.PREPARE
		"PREBATTLE":
			target_state = core.GameState.PREBATTLE
		"BATTLE":
			target_state = core.GameState.BATTLE
		"POSTBATTLE":
			target_state = core.GameState.POSTBATTLE
		_:
			target_state = core.GameState.START

	# Apply the restored game state
	game.game_handler.current_gamestate = target_state

	# Let LineupHandler restore lineup state if needed
	if not lineup_data.is_empty():
		# TODO: Implement lineup_handler.restore_from_saved_state(lineup_data)
		# For now, skip lineup restoration to focus on board determinism fix
		Log.info(
			"Lineup restoration skipped - method not implemented yet",
			{"lineup_data_size": lineup_data.size()},
			[Log.TAG_DEBUG, "gamestate", "lineup"]
		)

	# CRITICAL: Disable gamestate loading mode after restoration complete
	if game.level_controller:
		game.level_controller.set_gamestate_loading_mode(false)
	# Unlock input now that gamestate loading is complete
	if game.input_handler:
		game.input_handler.unlock_input()

	Log.info(
		"Gamestate loaded and transitioned successfully",
		{
			"file": gamestate_file_path.get_file(),
			"restored_state": saved_game_state,
			"target_state": core.GameState.keys()[target_state]
		},
		[Log.TAG_DEBUG, "gamestate", "load"]
	)

	return true


static func _restore_board_content(game: Game, gamestate: Dictionary) -> void:
	"""Restore board content using existing deserialization system"""
	var board_data: Dictionary = gamestate.get("board", {})
	var draft_area: Dictionary = board_data.get("draft_area", {})

	if draft_area.is_empty():
		Log.warning(
			"No draft area data found in gamestate",
			{},
			[Log.TAG_INITIALIZATION, "gamestate", "board"]
		)
		return

	Log.info(
		"Restoring board content from saved state",
		{"total_positions": draft_area.size()},
		[Log.TAG_INITIALIZATION, "gamestate", "board"]
	)

	# Clear all existing blocks before restoring gamestate
	game.level_controller.clear_all_blocks()

	var blocks_restored: int = 0
	var cards_restored: int = 0

	# Process positions in deterministic order (sorted by Vector2i position)
	var position_keys: Array[Vector2i] = []
	for key: Variant in draft_area.keys():
		# Handle both Vector2i keys (in memory) and string keys (from JSON deserialization)
		var grid_pos: Vector2i
		if key is Vector2i:
			grid_pos = key
		elif key is String:
			# Parse string representation like "(0, 0)" back to Vector2i
			var key_str: String = key
			# Remove parentheses and split by comma
			key_str = key_str.replace("(", "").replace(")", "").replace(" ", "")
			var coords: PackedStringArray = key_str.split(",")
			if coords.size() == 2:
				grid_pos = Vector2i(coords[0].to_int(), coords[1].to_int())
			else:
				Log.warning(
					"Invalid grid position string format",
					{"key": key_str},
					["gamestate", "parsing"]
				)
				continue
		else:
			Log.warning(
				"Unexpected key type in draft_area",
				{"key": key, "type": typeof(key)},
				["gamestate", "parsing"]
			)
			continue

		position_keys.append(grid_pos)

	# Sort position keys deterministically (by y first, then x for row-major order)
	position_keys.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			if a.y == b.y:
				return a.x < b.x
			return a.y < b.y
	)

	# Create a mapping from Vector2i back to original keys for data access
	var pos_to_key: Dictionary = {}
	for key: Variant in draft_area.keys():
		var grid_pos: Vector2i
		if key is Vector2i:
			grid_pos = key
			pos_to_key[grid_pos] = key
		elif key is String:
			var key_str: String = key
			key_str = key_str.replace("(", "").replace(")", "").replace(" ", "")
			var coords: PackedStringArray = key_str.split(",")
			if coords.size() == 2:
				grid_pos = Vector2i(coords[0].to_int(), coords[1].to_int())
				pos_to_key[grid_pos] = key

	# Process blocks in deterministic position order
	for grid_pos: Vector2i in position_keys:
		var original_key: Variant = pos_to_key.get(grid_pos)
		if original_key == null:
			continue
		var block_data: Variant = draft_area[original_key]

		if not block_data is Dictionary:
			continue

		var block_dict: Dictionary = block_data
		var object_type: int = block_dict.get("object_type", 0)

		# Route to appropriate deserializer based on object_type
		var restored_block: Block = await _deserialize_block_by_type(game, object_type, block_dict)
		if restored_block:
			# Use the Vector2i grid position directly - no conversion needed
			game.level_controller.add_to_grid(grid_pos, restored_block, 0)

			blocks_restored += 1
			if object_type == core.ObjectType.CARD:
				cards_restored += 1

			Log.debug(
				"Block restored to grid",
				{
					"object_type": object_type,
					"grid_pos": grid_pos,
					"block_type": restored_block.get_class()
				},
				[Log.TAG_INITIALIZATION, "gamestate", "board"]
			)
		else:
			Log.warning(
				"Failed to restore block from data",
				{"object_type": object_type, "grid_pos": grid_pos},
				[Log.TAG_INITIALIZATION, "gamestate", "board"]
			)

	Log.info(
		"Board content restoration complete",
		{
			"total_blocks_restored": blocks_restored,
			"cards_restored": cards_restored,
			"total_positions_processed": draft_area.size()
		},
		[Log.TAG_INITIALIZATION, "gamestate", "board"]
	)


static func _deserialize_block_by_type(
	game: Game, object_type: int, block_data: Dictionary
) -> Block:
	"""Route to appropriate deserializer based on object_type"""
	match object_type:
		core.ObjectType.CARD:
			# Use existing card deserialization system (async because it loads from database)
			return await Card.deserialize_from_dict(block_data)
		core.ObjectType.EMPTY_SPACE, core.ObjectType.BLOCK_ITEM:
			# Use existing item block deserialization system (synchronous)
			return ItemBlock.deserialize_from_dict(block_data)
		core.ObjectType.BLOCK_UPGRADE:
			# Use block factory to create upgrade blocks with proper level
			var upgrade_level: int = block_data.get("level", 1)
			Log.debug(
				"Deserializing upgrade block",
				{"requested_level": upgrade_level, "block_data": block_data},
				["deserialization", "upgrade_block"]
			)
			var created_block: Block = game.level_controller.create_upgrade_block(upgrade_level)
			Log.debug(
				"Created upgrade block",
				{"created_level": created_block.level},
				["deserialization", "upgrade_block"]
			)
			return created_block
		core.ObjectType.BLOCK_LOCKED:
			# Use block factory to create locked blocks
			return game.level_controller._block_factory.create_locked_block()
		core.ObjectType.BLOCK_NOSPACE:
			# Use block factory to create nospace blocks
			return game.level_controller._block_factory.create_nospace_block()
		core.ObjectType.BLOCK_PASSTROUGH:
			# Use block factory to create passthrough blocks
			return game.level_controller._block_factory.create_passtrough_block()
		_:
			Log.warning(
				"Deserialization not implemented for object type",
				{"object_type": object_type, "available_types": core.ObjectType.keys()},
				[Log.TAG_INITIALIZATION, "gamestate", "deserialization"]
			)
			return null


static func _draft_position_to_grid(draft_position: int) -> Vector2i:
	"""Convert draft position to grid coordinates"""
	# Standard grid layout: 20 positions in 4 rows x 5 columns
	# Position 0-4 = row 0, position 5-9 = row 1, etc.
	var grid_width: int = 5
	var grid_x: int = draft_position % grid_width  # Column: remainder when divided by width
	@warning_ignore("integer_division")
	var grid_y: int = int(draft_position / grid_width)  # Row: how many complete rows fit
	return Vector2i(grid_x, grid_y)


static func _reset_all_game_state_for_loading(game: Game) -> void:
	"""Complete state reset before gamestate loading - clears all boards, lineups, and UI state"""
	Log.info(
		"Resetting all game state for gamestate loading", {}, [Log.TAG_DEBUG, "gamestate", "reset"]
	)

	var reset_start_time: int = Time.get_ticks_msec()
	var components_reset: Array[String] = []

	# 1. Reset board/clicker state completely
	if game.level_controller:
		# CRITICAL: Enable gamestate loading mode to prevent tilemap block creation
		game.level_controller.set_gamestate_loading_mode(true)
		game.level_controller.clear_all_blocks()  # This already exists and clears grid + scene tree
		components_reset.append("board_blocks")

		# Also clear any level-specific state
		if game.level_controller.current_level:
			# Clear any remaining tilemap cells that might conflict
			game.level_controller.current_level.clear()
			components_reset.append("tilemap")

	# 2. Reset lineup completely
	if game.holder_allies:
		var cleared_allies: int = _clear_holder_container(game.holder_allies)
		if cleared_allies > 0:
			components_reset.append("allies_lineup")

	if game.holder_enemy:
		var cleared_enemies: int = _clear_holder_container(game.holder_enemy)
		if cleared_enemies > 0:
			components_reset.append("enemies_lineup")

	# 3. Reset draft area state if there are held columns
	if game.clicker:
		game.clicker.columns_locked.clear()
		game.clicker.refill_counter.clear()
		components_reset.append("draft_state")

	# 4. Reset UI state to clean slate
	game.ui_state = core.UIState.LOCKED  # Lock UI during loading
	components_reset.append("ui_state")

	# 5. Reset all game handlers to clean state
	_reset_all_handlers(game)
	components_reset.append("game_handlers")

	# 6. Clear any queued actions that might interfere
	game._idle_action_queue.clear()
	game._processing_idle_action = false
	components_reset.append("action_queue")

	var reset_duration: int = Time.get_ticks_msec() - reset_start_time

	Log.info(
		"Game state reset complete for gamestate loading",
		{
			"components_reset": components_reset,
			"reset_duration_ms": reset_duration,
			"ui_state": "LOCKED"
		},
		[Log.TAG_DEBUG, "gamestate", "reset"]
	)


static func _clear_holder_container(holder_container: HolderContainer) -> int:
	"""Clear all cards from a holder container and return count cleared"""
	if not holder_container:
		return 0

	var cards_cleared: int = 0
	var lineup: Dictionary = holder_container.get_current_lineup()

	# Remove all cards from holders using silent forceful cleanup
	for holder_pos: int in lineup.keys():
		var holder: Holder = holder_container.get_holder(holder_pos)
		if holder and holder.get_card():
			holder.force_clear_silent()
			cards_cleared += 1

	var container_name: String = "unnamed"
	if holder_container.name and holder_container.name != "":
		container_name = holder_container.name
	Log.debug(
		"Holder container cleared",
		{"container": container_name, "cards_cleared": cards_cleared},
		[Log.TAG_DEBUG, "gamestate", "reset"]
	)

	return cards_cleared


static func _reset_all_handlers(game: Game) -> void:
	"""Reset all game handlers to clean state for gamestate loading"""
	Log.debug(
		"Resetting all game handlers for gamestate loading",
		{},
		[Log.TAG_DEBUG, "gamestate", "handlers"]
	)

	var handlers_reset: Array[String] = []

	# 1. Reset GameHandler state
	if game.game_handler:
		# GameHandler will be set to the correct state during restoration
		# For now, reset to a clean initial state
		game.game_handler.set_gamestate(core.GameState.START)
		handlers_reset.append("game_handler")

	# 2. Reset InputHandler state
	if game.input_handler:
		# Reset input state (touch positions, drag state, etc.)
		game.input_handler.reset_inputs()
		handlers_reset.append("input_handler")

	# 3. Reset CardHandler state
	if game.card_handler:
		# CardHandler is typically stateless, no reset needed
		handlers_reset.append("card_handler")

	# 4. Reset DraftHandler state
	if game.draft_handler:
		# Reset draft upgrade level to default
		game.draft_handler.current_draft_upgrade_level = 0
		handlers_reset.append("draft_handler")

	# 5. Reset LineupHandler state
	if game.lineup_handler:
		# LineupHandler works with holder_container which we've already cleared
		# No additional state to reset
		handlers_reset.append("lineup_handler")

	# 6. Reset BattleHandler state
	if game.battle_handler:
		# BattleHandler is typically stateless for battle creation
		# No persistent state to reset
		handlers_reset.append("battle_handler")

	Log.debug(
		"Game handlers reset complete",
		{"handlers_reset": handlers_reset},
		[Log.TAG_DEBUG, "gamestate", "handlers"]
	)

