class_name GameActionPlayer
extends RefCounted


static func _get_game_node() -> Game:
	var root: Node = Engine.get_main_loop().current_scene
	if root and root.has_method("find_child"):
		var found_node: Node = root.find_child("Game", true, false)
		if found_node is Game:
			return found_node as Game
	return null


static func _reroll_player(params: Dictionary = {}) -> bool:
	"""Simulate player reroll action with parameters"""

	var cost: int = params.get("cost", 0)
	if cost < 0:
		Log.error("Invalid cost parameter", {"cost": cost}, ["debug", "replay", "player", "error"])
		assert(false, "reroll_player: cost cannot be negative")
		return false

	var game: Game = _get_game_node()
	if not game:
		Log.error("Game node not available for reroll", {}, ["debug", "replay", "player", "error"])
		assert(false, "reroll_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "DRAFT":
		Log.error(
			"Cannot reroll outside DRAFT state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(false, "reroll_player: can only reroll in DRAFT state, current: " + current_state)
		return false

	if not game.clicker or not game.clicker.level:
		Log.error(
			"Draft system not available for reroll", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "reroll_player: draft system not available")
		return false

	Log.info(
		"Simulating player reroll action",
		{"cost": cost, "params": params},
		["debug", "replay", "player"]
	)

	game.draft_handler.reroll()

	return true


static func _upgrade_player(params: Dictionary = {}) -> bool:
	"""Simulate player upgrade action with parameters"""

	var level: int = params.get("level", 1)
	var level_error: String = _validate_range(level, 1, 5, "level")
	if not level_error.is_empty():
		Log.error(
			"Invalid level parameter",
			{"level": level, "error": level_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "upgrade_player: " + level_error)
		return false

	var game: Game = _get_game_node()
	if not game:
		Log.error("Game node not available for upgrade", {}, ["debug", "replay", "player", "error"])
		assert(false, "upgrade_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "DRAFT":
		Log.error(
			"Cannot upgrade outside DRAFT state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(false, "upgrade_player: can only upgrade in DRAFT state, current: " + current_state)
		return false

	if not game.clicker or not game.clicker.level:
		Log.error(
			"Draft system not available for upgrade", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "upgrade_player: draft system not available")
		return false

	Log.info(
		"Simulating player upgrade action",
		{"level": level, "params": params},
		["debug", "replay", "player"]
	)

	game.draft_handler.upgrade()

	return true


static func _toggle_column_player(params: Dictionary = {}) -> bool:
	"""Simulate player column toggle action with parameters"""

	var required_params: Array[String] = ["column_index", "new_state"]
	var param_error: String = _validate_required_params(params, required_params)
	if not param_error.is_empty():
		Log.error(
			"Missing required parameters",
			{"error": param_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "toggle_column_player: " + param_error)
		return false

	var column_index: int = params.get("column_index", -1)
	var new_state: bool = params.get("new_state", false)

	var column_error: String = _validate_range(column_index, 0, 4, "column_index")
	if not column_error.is_empty():
		Log.error(
			"Invalid column_index parameter",
			{"column_index": column_index, "error": column_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "toggle_column_player: " + column_error)
		return false

	var game: Game = _get_game_node()
	if not game:
		Log.error(
			"Game node not available for column toggle", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "toggle_column_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "DRAFT":
		Log.error(
			"Cannot toggle column outside DRAFT state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(
			false, "toggle_column_player: can only toggle in DRAFT state, current: " + current_state
		)
		return false

	if not game.clicker or not game.clicker.level:
		Log.error(
			"Draft system not available for column toggle",
			{},
			["debug", "replay", "player", "error"]
		)
		assert(false, "toggle_column_player: draft system not available")
		return false

	Log.info(
		"Simulating player column toggle action",
		{"column_index": column_index, "new_state": new_state, "params": params},
		["debug", "replay", "player"]
	)

	var event: core.DraftColumnStateEvent = core.DraftColumnStateEvent.new(column_index, new_state)
	event.source = core.EventSource.PLAYER
	core.action(event)

	return true


static func _remove_block_player(params: Dictionary = {}) -> bool:
	"""Simulate player block removal action with parameters - mirrors normal UI flow"""

	var required_params: Array[String] = ["position"]
	var param_error: String = _validate_required_params(params, required_params)
	if not param_error.is_empty():
		Log.error(
			"Missing required parameters",
			{"error": param_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "remove_block_player: " + param_error)
		return false

	var card_id: String = params.get("card_id", "")
	var position: Dictionary = params.get("position", {})

	var validation_error: String = _can_remove_block(card_id, position)
	if not validation_error.is_empty():
		Log.error(
			"Invalid parameters for block removal",
			{"error": validation_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "remove_block_player: " + validation_error)
		return false

	var game: Game = _get_game_node()
	if not game:
		Log.error(
			"Game node not available for block removal", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "remove_block_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "DRAFT":
		Log.error(
			"Cannot remove blocks outside DRAFT state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(
			false,
			"remove_block_player: can only remove blocks in DRAFT state, current: " + current_state
		)
		return false

	if not game.clicker or not game.clicker.level:
		Log.error(
			"Draft system not available for block removal",
			{},
			["debug", "replay", "player", "error"]
		)
		assert(false, "remove_block_player: draft system not available")
		return false

	var pos_x: int = position.get("x", -1)
	var pos_y: int = position.get("y", -1)
	var grid_pos: Vector2i = Vector2i(pos_x, pos_y)
	var actual_block: Block = Clicker.find_block_at_position(game.clicker, grid_pos)

	if not actual_block:
		Log.error(
			"No block found at specified position",
			{"position": position, "grid_pos": grid_pos},
			["debug", "replay", "player", "warning", "error"]
		)
		assert(false, "block not found at expeected position")
		return false

	if actual_block.object_type == core.ObjectType.CARD:
		var actual_card_id: String = actual_block.card_info.id
		if actual_card_id != card_id:
			Log.error(
				"Card ID mismatch at position",
				{"expected": card_id, "actual": actual_card_id, "position": position},
				["debug", "replay", "player", "error"]
			)
			assert(false, "remove_block_player: Card ID mismatch")
			return false
	elif actual_block.object_type == core.ObjectType.BLOCK_LOCKED:
		if not card_id.is_empty():
			Log.error(
				"Card ID should be empty for locked blocks",
				{"card_id": card_id, "position": position, "block_type": actual_block.object_type},
				["debug", "replay", "player", "error"]
			)
			assert(false, "remove_block_player: Card ID should be empty for locked blocks")
			return false
	else:
		Log.error(
			"Block at position is not removable",
			{"position": position, "block_type": actual_block.object_type},
			["debug", "replay", "player", "error"]
		)
		assert(false, "remove_block_player: Block is not removable")
		return false

	Log.info(
		"Performing block removal action",
		{"card_id": card_id, "position": position, "block_type": actual_block.object_type},
		["debug", "replay", "player"]
	)

	core.action(core.RemoveBlockFromDraft.new(actual_block, true))

	Log.info(
		"Block removal completed",
		{"card_id": card_id, "position": position},
		["debug", "replay", "player"]
	)

	return true


static func _move_card_player(params: Dictionary = {}) -> bool:
	"""Simulate player card move action with parameters"""

	var required_params: Array[String] = ["card_id", "from_position", "to_position"]
	var param_error: String = _validate_required_params(params, required_params)
	if not param_error.is_empty():
		Log.error(
			"Missing required parameters",
			{"error": param_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: " + param_error)
		return false

	var card_id: String = params.get("card_id", "")
	var from_position: int = params.get("from_position", -1)
	var to_position: int = params.get("to_position", -1)

	var from_error: String = _validate_range(from_position, 0, 9, "from_position")
	if not from_error.is_empty():
		Log.error(
			"Invalid from_position parameter",
			{"error": from_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: " + from_error)
		return false

	var to_error: String = _validate_range(to_position, 0, 9, "to_position")
	if not to_error.is_empty():
		Log.error(
			"Invalid to_position parameter",
			{"error": to_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: " + to_error)
		return false

	var move_error: String = _can_move_card(card_id, from_position)
	if not move_error.is_empty():
		Log.error("Cannot move card", {"error": move_error}, ["debug", "replay", "player", "error"])
		assert(false, "move_card_player: " + move_error)
		return false

	var game: Game = _get_game_node()
	if not game:
		Log.error(
			"Game node not available for card move", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "DRAFT" and current_state != "PREPARE":
		Log.error(
			"Cannot move cards in current state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(
			false,
			(
				"move_card_player: can only move cards in DRAFT or PREPARE state, current: "
				+ current_state
			)
		)
		return false

	if not core:
		Log.error(
			"Core system not available for card move", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: core system not available")
		return false

	Log.info(
		"Simulating player card move action",
		{
			"card_id": card_id,
			"from_position": from_position,
			"to_position": to_position,
			"params": params
		},
		["debug", "replay", "player"]
	)

	if not is_instance_valid(card_controller):
		Log.error(
			"card_controller not available for card move",
			{},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: card_controller not available")
		return false

	var card: Variant = await CardController.create_unit_from_id(card_id, 1)
	if not card:
		Log.error(
			"Failed to create card for move",
			{"card_id": card_id},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_player: Failed to create card")
		return false

	var typed_card: Card = card
	typed_card.block_context = Cards.CONTEXT.LINEUP

	var move_event: core.MoveLineupCardEvent = core.MoveLineupCardEvent.new(
		typed_card, from_position, to_position
	)
	core.action(move_event)

	return true


static func _move_card_to_lineup_player(params: Dictionary = {}) -> bool:
	"""Atomic draft-to-lineup move operation using LineupAddCardFromDraftEvent"""
	var required_params: Array[String] = ["card_id", "from_position", "to_position"]
	var param_error: String = _validate_required_params(params, required_params)
	if not param_error.is_empty():
		Log.error(
			"Missing required parameters",
			{"error": param_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_to_lineup_player: " + param_error)
		return false

	var card_id: String = params.get("card_id", "")
	var from_position: Dictionary = params.get("from_position", {})
	var to_position: int = params.get("to_position", -1)
	var from_x: int = from_position.get("x", -1)
	var from_y: int = from_position.get("y", -1)
	var grid_pos: Vector2i = Vector2i(from_x, from_y)

	var game: Game = _get_game_node()
	if not game:
		Log.error("Game node not available", {}, ["debug", "replay", "player", "error"])
		assert(false, "move_card_to_lineup_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "DRAFT":
		Log.error(
			"Cannot move cards outside DRAFT state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_to_lineup_player: invalid game state")
		return false

	var found_block: Variant = Clicker.find_block_at_position(game.clicker, grid_pos)
	var card_to_move: Card = null
	if found_block is Card:
		card_to_move = found_block
	if not card_to_move:
		Log.error(
			"No card found at position",
			{"position": from_position},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_to_lineup_player: card not found")
		return false

	var target_holder: Holder = game.lineup_handler.holder_container.get_holder(to_position)
	if not target_holder.can_set_card(card_to_move):
		Log.error(
			"Target lineup position occupied",
			{"position": to_position, "card_id": card_id},
			["debug", "replay", "player", "error"]
		)
		assert(false, "move_card_to_lineup_player: target position occupied")
		return false

	Log.info(
		"Executing draft-to-lineup move via LineupAddCardFromDraftEvent",
		{"card_id": card_id, "from": from_position, "to": to_position},
		["debug", "replay", "player", "move"]
	)

	core.action(core.LineupAddCardFromDraftEvent.new(card_to_move, grid_pos, to_position))

	Log.info(
		"Draft-to-lineup move completed successfully",
		{"card_id": card_id, "from": from_position, "to": to_position},
		["debug", "replay", "player", "move"]
	)
	return true


static func _transition_player(params: Dictionary = {}) -> bool:
	"""Simulate player state transition action with parameters"""
	# Expected starting state (empty = skip validation)
	var from_state: String = params.get("from_state", "")
	var to_state: String = params.get("to_state", "PREPARE")  # Target state

	if to_state.is_empty():
		Log.error(
			"to_state parameter is required",
			{"params": params},
			["debug", "replay", "player", "error"]
		)
		assert(false, "transition_player: to_state parameter is required")
		return false

	if not from_state.is_empty():
		var game: Game = _get_game_node()
		if not game:
			Log.error(
				"Cannot validate state transition - game node not available",
				{"expected_from_state": from_state, "target_state": to_state},
				["debug", "replay", "player", "error"]
			)
			assert(false, "transition_player: game node not available")
			return false

		var current_state_name: String = core.GameState.keys()[game.game_handler.current_gamestate]
		if current_state_name != from_state:
			(
				Log
				. error(
					"State transition validation failed - current state doesn't match expected from_state",
					{
						"expected_from_state": from_state,
						"actual_current_state": current_state_name,
						"target_state": to_state,
						"params": params
					},
					["debug", "replay", "player", "error"]
				)
			)
			assert(
				false,
				(
					"transition_player: expected state "
					+ from_state
					+ " but current is "
					+ current_state_name
				)
			)
			return false

	Log.info(
		"Simulating player state transition action",
		{"from_state": from_state, "to_state": to_state, "params": params},
		["debug", "replay", "player"]
	)

	var target_state: core.GameState

	match to_state:
		"START":
			target_state = core.GameState.START
		"PREPARE":
			target_state = core.GameState.PREPARE
		"DRAFT":
			target_state = core.GameState.DRAFT
		"PREBATTLE":
			target_state = core.GameState.PREBATTLE
		"BATTLE":
			target_state = core.GameState.BATTLE
		"POSTBATTLE":
			target_state = core.GameState.POSTBATTLE
		_:
			Log.error(
				"Unknown target state for replay",
				{"to_state": to_state},
				["debug", "replay", "player", "error"]
			)
			assert(false, "transition_player: unknown target state: " + to_state)
			return false

	var event: core.TransitionEvent = core.TransitionEvent.new(target_state)
	event.source = core.EventSource.PLAYER
	core.action(event)

	return true


static func _start_battle_player(params: Dictionary = {}) -> bool:
	"""Simulate player battle start action with parameters"""

	var player_lineup_count: int = params.get("player_lineup_count", 3)
	var enemy_lineup_count: int = params.get("enemy_lineup_count", 3)

	var player_error: String = _validate_range(player_lineup_count, 1, 10, "player_lineup_count")
	if not player_error.is_empty():
		Log.error(
			"Invalid player_lineup_count parameter",
			{"error": player_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "start_battle_player: " + player_error)
		return false

	var enemy_error: String = _validate_range(enemy_lineup_count, 1, 10, "enemy_lineup_count")
	if not enemy_error.is_empty():
		Log.error(
			"Invalid enemy_lineup_count parameter",
			{"error": enemy_error},
			["debug", "replay", "player", "error"]
		)
		assert(false, "start_battle_player: " + enemy_error)
		return false

	var game: Game = _get_game_node()
	if not game:
		Log.error(
			"Game node not available for battle start", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "start_battle_player: game node not available")
		return false

	var current_state: String = core.GameState.keys()[game.game_handler.current_gamestate]
	if current_state != "PREPARE":
		Log.error(
			"Cannot start battle from current state",
			{"current_state": current_state},
			["debug", "replay", "player", "error"]
		)
		assert(
			false,
			(
				"start_battle_player: can only start battle from PREPARE state, current: "
				+ current_state
			)
		)
		return false

	if not ui:
		Log.error(
			"UI system not available for battle start", {}, ["debug", "replay", "player", "error"]
		)
		assert(false, "start_battle_player: UI system not available")
		return false

	Log.info(
		"Simulating player battle start action",
		{
			"player_lineup_count": player_lineup_count,
			"enemy_lineup_count": enemy_lineup_count,
			"params": params
		},
		["debug", "replay", "player"]
	)

	ui.action(ui.StartBattleEvent.new())

	return true


static func _validate_required_params(params: Dictionary, required_keys: Array[String]) -> String:
	"""
	Validate that all required parameters are present.
	Returns empty string if valid, error message if invalid.
	"""
	for key: String in required_keys:
		if not params.has(key):
			return "Missing required parameter: " + key
		var value: Variant = params[key]
		if value == null:
			return "Parameter '" + key + "' cannot be null"
	return ""


static func _validate_range(value: int, min_val: int, max_val: int, param_name: String) -> String:
	"""Validate integer is within range. Returns empty string if valid, error message if invalid."""
	if value < min_val or value > max_val:
		return (
			param_name
			+ " must be between "
			+ str(min_val)
			+ " and "
			+ str(max_val)
			+ " (got "
			+ str(value)
			+ ")"
		)
	return ""


static func _validate_position_dict(position: Dictionary, param_name: String) -> String:
	"""
	Validate position dictionary has x,y coordinates within clicker bounds.
	Returns empty string if valid.
	"""
	if not position.has("x") or not position.has("y"):
		return param_name + " must have 'x' and 'y' coordinates"

	var x: int = position.get("x", -1)
	var y: int = position.get("y", -1)

	var x_error: String = _validate_range(x, 0, 4, param_name + ".x")
	if not x_error.is_empty():
		return x_error

	var y_error: String = _validate_range(y, 0, 3, param_name + ".y")
	if not y_error.is_empty():
		return y_error

	return ""


static func _can_move_card(card_id: String, from_position: int) -> String:
	"""Check if card can be moved from position. Returns empty string if valid."""
	if card_id.is_empty():
		return "card_id cannot be empty"

	var range_error: String = _validate_range(from_position, 0, 9, "from_position")
	if not range_error.is_empty():
		return range_error

	var game: Game = _get_game_node()
	if not game or not game.lineup_handler:
		return "lineup not available for validation"

	if from_position >= game.lineup_handler.get_card_count():
		return "from_position " + str(from_position) + " exceeds lineup size"

	var card_at_position: Card = game.lineup_handler.get_card_at_position(from_position)
	if not card_at_position:
		return "no card found at from_position " + str(from_position)

	if card_at_position.card_info.id != card_id:
		return "card_id mismatch: expected " + card_id + ", found " + card_at_position.card_info.id

	return ""


static func _can_remove_block(card_id: String, position: Dictionary) -> String:
	"""Check if block can be removed from card at position. Returns empty string if valid."""
	var pos_error: String = _validate_position_dict(position, "position")
	if not pos_error.is_empty():
		return pos_error

	var game: Game = _get_game_node()
	if not game or not game.clicker:
		return "draft system not available for validation"

	var pos_x: int = position.get("x", -1)
	var pos_y: int = position.get("y", -1)
	var grid_pos: Vector2i = Vector2i(pos_x, pos_y)

	var block_at_position: Block = Clicker.find_block_at_position(game.clicker, grid_pos)
	if not block_at_position:
		return "no block found at position (" + str(grid_pos.x) + "," + str(grid_pos.y) + ")"

	if block_at_position.object_type == core.ObjectType.BLOCK_LOCKED:
		if not card_id.is_empty():
			return "card_id should be empty for locked blocks, got: " + card_id
	elif block_at_position.object_type == core.ObjectType.CARD:
		if not card_id.is_empty():
			if block_at_position.card_info.id != card_id:
				return (
					"card_id mismatch: expected "
					+ card_id
					+ ", found "
					+ block_at_position.card_info.id
				)
	else:
		return (
			"block at position is not removable (type: " + str(block_at_position.object_type) + ")"
		)

	return ""
