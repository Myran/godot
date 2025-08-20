class_name GameStateSaveManager extends RefCounted


static func save_game_state(slot: int = 0) -> bool:
	var start_time: int = Time.get_ticks_msec()

	Log.info("Starting game state save", {"slot": slot}, [Log.TAG_DEBUG])

	# StateExtractor already filters out unsafe references
	# It only captures: card IDs, levels, positions, checksums
	var game_state: Dictionary = StateExtractor.extract_game_state()

	# Validate extracted state contains no Godot internal references
	if not _is_safe_for_serialization(game_state):
		Log.error("Game state contains unsafe references", {}, [Log.TAG_DEBUG])
		return false

	var rng_state: String = rng.seeded_rng.save_state() if rng.seeded_rng else ""

	var save_data: Dictionary = {
		"game_state": game_state,
		"rng_state": rng_state,
		"timestamp": Time.get_unix_time_from_system(),
		"version": "1.0"
	}

	var file_path: String = "user://save_slot_%d.dat" % slot
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		Log.error("Failed to open save file", {"path": file_path}, [Log.TAG_DEBUG])
		return false

	var bytes: PackedByteArray = var_to_bytes(save_data)
	file.store_var(bytes)
	file.close()

	var duration: int = Time.get_ticks_msec() - start_time

	Log.info(
		"Game state saved successfully",
		{
			"slot": slot,
			"duration_ms": duration,
			"file_size_bytes": bytes.size(),
			"file_path": file_path
		},
		[Log.TAG_DEBUG]
	)

	return true


static func load_game_state(slot: int = 0) -> bool:
	var start_time: int = Time.get_ticks_msec()

	Log.info("Starting game state load", {"slot": slot}, [Log.TAG_DEBUG])

	var file_path: String = "user://save_slot_%d.dat" % slot
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		Log.error("Failed to open save file", {"path": file_path}, [Log.TAG_DEBUG])
		return false

	var bytes: Variant = file.get_var()
	file.close()

	if not bytes is PackedByteArray:
		Log.error("Invalid save file format", {"type": typeof(bytes)}, [Log.TAG_DEBUG])
		return false

	var save_data: Variant = bytes_to_var(bytes)
	if not save_data or not save_data is Dictionary:
		Log.error("Failed to deserialize save data", {"type": typeof(save_data)}, [Log.TAG_DEBUG])
		return false

	var save_dict: Dictionary = save_data as Dictionary

	# Validate save data structure
	if not _validate_save_data(save_dict):
		Log.error("Invalid save data structure", {}, [Log.TAG_DEBUG])
		return false

	# Restore RNG state first
	var rng_state: String = save_dict.get("rng_state", "")
	if not rng_state.is_empty() and rng.seeded_rng:
		rng.seeded_rng.load_state(rng_state)
		Log.debug("RNG state restored", {"state_length": rng_state.length()}, [Log.TAG_DEBUG])

	# Apply game state (implementation needed in Game class)
	var game_state: Dictionary = save_dict.get("game_state", {})
	var success: bool = await _apply_game_state(game_state)

	var duration: int = Time.get_ticks_msec() - start_time

	if success:
		Log.info(
			"Game state loaded successfully",
			{"slot": slot, "duration_ms": duration, "timestamp": save_dict.get("timestamp", 0)},
			[Log.TAG_DEBUG]
		)
	else:
		Log.error("Failed to apply game state", {"slot": slot}, [Log.TAG_DEBUG])

	return success


static func _is_safe_for_serialization(data: Dictionary) -> bool:
	# StateExtractor already ensures safety, but double-check
	# No RIDs, ObjectIDs, Node references, or other Godot internals
	return StateExtractor.is_state_valid(data)


static func _validate_save_data(save_data: Dictionary) -> bool:
	var required_keys: Array[String] = ["game_state", "rng_state", "timestamp", "version"]

	for key: String in required_keys:
		if not save_data.has(key):
			Log.error("Missing required save data key", {"key": key}, [Log.TAG_DEBUG])
			return false

	var game_state: Variant = save_data.get("game_state")
	if not game_state is Dictionary:
		Log.error("Invalid game_state type", {"type": typeof(game_state)}, [Log.TAG_DEBUG])
		return false

	return true


static func _apply_game_state(game_state: Dictionary) -> bool:
	var game: Game = _get_game_instance()
	if not game:
		Log.error("Cannot restore gamestate - Game instance not found", {}, [Log.TAG_DEBUG])
		return false

	# Restore board state first (level, battle status)
	var board_state: Dictionary = game_state.get("board", {})
	if not board_state.is_empty():
		await _restore_board_state(game, board_state)

	# Restore lineup state (recreate cards from IDs)
	var lineup_state: Dictionary = game_state.get("lineup", {})
	if not lineup_state.is_empty():
		await _restore_lineup_state(game, lineup_state)

	Log.info(
		"Game state restored successfully",
		{
			"board_restored": not board_state.is_empty(),
			"lineup_restored": not lineup_state.is_empty()
		},
		[Log.TAG_DEBUG]
	)

	return true


static func _restore_board_state(game: Game, board_state: Dictionary) -> void:
	# Restore current level
	var target_level: int = board_state.get("current_level", 1)
	if game.level_controller and target_level > 0:
		if game.level_controller.has_method("setup_level"):
			game.level_controller.setup_level("level_%d" % target_level)

	# Restore battle status and input state will be handled naturally by game flow
	Log.debug("Board state restored", {"level": target_level}, [Log.TAG_DEBUG])


static func _restore_lineup_state(game: Game, lineup_state: Dictionary) -> void:
	if not game.lineup_handler:
		Log.error("Cannot restore lineup - LineupHandler not available", {}, [Log.TAG_DEBUG])
		return

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


static func _restore_position_data(
	game: Game, position_data: Dictionary, lineup_type: String
) -> void:
	for position_str: String in position_data.keys():
		var position: int = int(position_str)
		var card_data: Dictionary = position_data[position_str]

		var card_id: String = card_data.get("card_id", "")
		var level: int = card_data.get("level", 1)

		if card_id.is_empty():
			continue

		# Recreate card using existing systems (following CLAUDE.md conventions)
		var card: Card = await _create_unit_from_id(card_id, level)
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


static func _create_unit_from_id(card_id: String, level: int) -> Card:
	# Use card controller to create unit from ID
	if card_controller and card_controller.has_method("create_unit_from_id"):
		return await card_controller.create_unit_from_id(card_id, level)

	Log.error(
		"CardController not available for unit creation",
		{"card_id": card_id, "level": level},
		[Log.TAG_DEBUG]
	)
	return null


static func _clear_current_lineup(game: Game) -> void:
	# Clear existing lineup safely using existing systems
	if game.holder_allies and game.holder_allies.has_method("get_current_lineup"):
		var current_lineup: Dictionary = game.holder_allies.get_current_lineup()
		for position: int in current_lineup.keys():
			if game.holder_allies.has_method("get_holder"):
				var holder: Variant = game.holder_allies.get_holder(position)
				if holder and holder.has_method("set_card"):
					holder.set_card(null)  # Clear the position


static func _get_game_instance() -> Game:
	var main_loop: SceneTree = Engine.get_main_loop()
	if not main_loop:
		return null
	var current_scene: Node = main_loop.current_scene
	if current_scene and current_scene is Game:
		return current_scene as Game
	return null


# Public utility methods for file management
static func save_exists(slot: int = 0) -> bool:
	var file_path: String = "user://save_slot_%d.dat" % slot
	return FileAccess.file_exists(file_path)


static func delete_save(slot: int = 0) -> bool:
	var file_path: String = "user://save_slot_%d.dat" % slot
	if FileAccess.file_exists(file_path):
		var dir: DirAccess = DirAccess.open("user://")
		if dir:
			var result: Error = dir.remove(file_path.get_file())
			if result == OK:
				Log.info("Save file deleted", {"slot": slot}, [Log.TAG_DEBUG])
				return true
			else:
				Log.error(
					"Failed to delete save file", {"slot": slot, "error": result}, [Log.TAG_DEBUG]
				)
	return false


static func get_save_info(slot: int = 0) -> Dictionary:
	var file_path: String = "user://save_slot_%d.dat" % slot
	if not FileAccess.file_exists(file_path):
		return {}

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var bytes: Variant = file.get_var()
	file.close()

	if not bytes is PackedByteArray:
		return {}

	var save_data: Variant = bytes_to_var(bytes)
	if not save_data or not save_data is Dictionary:
		return {}

	var save_dict: Dictionary = save_data as Dictionary

	return {
		"timestamp": save_dict.get("timestamp", 0),
		"version": save_dict.get("version", "unknown"),
		"file_size": (bytes as PackedByteArray).size()
	}
