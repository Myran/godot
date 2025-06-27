class_name BoardCaptureAction extends CaptureActionBase

# Capture board state for deterministic validation
# For this card-based game, "board state" means the battle field state:
# ally lineups, enemy lineups, battle configuration, and game state

var game: Game


func _init() -> void:
	game = _get_game_node()


func capture_data() -> Dictionary:
	var board_data: Dictionary = {}

	if game:
		board_data = _capture_battle_field_state(game)

		Log.info(
			"Board state captured",
			{
				"has_game": true,
				"data_size": JSON.stringify(board_data).length(),
				"allies_count": board_data.get("allies_lineup", {}).size(),
				"enemy_count": board_data.get("enemy_lineup", {}).size(),
				"game_state": board_data.get("game_state", "unknown")
			},
			["debug", "board", "capture"]
		)
	else:
		Log.warning(
			"Game not found - cannot capture board state",
			{},
			["debug", "board", "capture", "warning"]
		)
		# Initialize empty board state
		board_data = {
			"allies_lineup": {},
			"enemy_lineup": {},
			"battle_config": {},
			"game_state": "unknown",
			"ui_state": "unknown"
		}

	return board_data


func get_state_type() -> String:
	return "board_state"


func _capture_battle_field_state(game_node: Game) -> Dictionary:
	var board_data: Dictionary = {}

	# Capture ally lineup state
	if game_node.holder_allies:
		board_data["allies_lineup"] = _capture_holder_state(game_node.holder_allies)

	# Capture enemy lineup state
	if game_node.holder_enemy:
		board_data["enemy_lineup"] = _capture_holder_state(game_node.holder_enemy)

	# Capture battle configuration
	if game_node.battle_handler:
		board_data["battle_config"] = _capture_battle_config(game_node.battle_handler)

	# Capture game state
	if game_node.game_handler:
		var game_state_value: core.GameState = game_node.game_handler.current_gamestate
		board_data["game_state"] = core.GameState.keys()[game_state_value]
	else:
		board_data["game_state"] = "unknown"

	# Capture UI state
	var ui_state_value: core.UIState = game_node.ui_state
	board_data["ui_state"] = core.UIState.keys()[ui_state_value]

	# Capture RNG state for determinism
	if rng and rng.seeded_rng:
		board_data["rng_state"] = {"initial_seed": rng.seeded_rng._initial_seed}

	# Ensure we always have some meaningful data to avoid empty capture failure
	if board_data.is_empty():
		board_data = {
			"allies_lineup": {},
			"enemy_lineup": {},
			"battle_config": {},
			"game_state": "START",
			"ui_state": "WAITING",
			"empty_capture": true
		}

	return board_data


func _capture_holder_state(holder: HolderContainer) -> Dictionary:
	var holder_data: Dictionary = {}

	if not holder:
		return holder_data

	# Capture cards in holder positions
	var cards_data: Dictionary = {}
	if holder.has_method("get_cards"):
		var cards: Dictionary = holder.get_cards()
		if cards is Dictionary:
			for position: Variant in cards:
				var card: Variant = cards[position]
				if card:
					cards_data[str(position)] = _capture_card_state(card)

	holder_data["cards"] = cards_data
	holder_data["capacity"] = holder.get_capacity() if holder.has_method("get_capacity") else 0

	return holder_data


func _capture_card_state(card: Variant) -> Dictionary:
	var card_data: Dictionary = {}

	if not card:
		return card_data

	# Capture essential card properties for deterministic comparison
	if card.has_method("get_card_info"):
		var card_info: Variant = card.get_card_info()
		if card_info:
			card_data["id"] = card_info.get("id", "unknown")

	if card.has_method("get_level"):
		card_data["level"] = card.get_level()
	elif card.has_property("level"):
		card_data["level"] = card.level

	if card.has_method("get_unit_info"):
		var unit_info: Variant = card.get_unit_info()
		if unit_info:
			card_data["health"] = unit_info.get("current_health", 0)
			card_data["attack"] = unit_info.get("current_attack", 0)

	return card_data


func _capture_battle_config(battle_handler: Variant) -> Dictionary:
	var config_data: Dictionary = {}

	if not battle_handler:
		return config_data

	# Capture battle state if available
	if battle_handler.has_method("get_battle_state"):
		config_data["battle_state"] = str(battle_handler.get_battle_state())

	if battle_handler.has_method("get_turn_count"):
		config_data["turn_count"] = battle_handler.get_turn_count()

	if battle_handler.has_method("is_battle_active"):
		config_data["is_active"] = battle_handler.is_battle_active()

	return config_data


func _get_game_node() -> Game:
	var root: Node = Engine.get_main_loop().current_scene
	if root and root.has_method("find_child"):
		return root.find_child("Game", true, false) as Game
	return null
