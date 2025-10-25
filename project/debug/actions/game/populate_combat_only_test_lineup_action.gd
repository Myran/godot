extends RefCounted

## Dedicated lineup for combat-only ability validation test
## Minimal, isolated lineup to prevent unintended side effects from shared lineup changes
## ONLY includes units needed to test TEMPORARY persistence type abilities


static func execute() -> bool:
	var game: Game = _get_game_node()
	if (
		not is_instance_valid(core)
		or not is_instance_valid(game)
		or not is_instance_valid(game.card_controller)
	):
		Log.error(
			"Cannot populate combat-only test lineup: core or card_controller missing",
			{},
			["debug", "error", "test"]
		)
		return false

	if not _wait_for_game_systems_ready():
		return false

	core.action(core.LineupOperationStartEvent.new())

	# Enemy lineup: Minimal setup with one axe man (has TEMPORARY ability)
	var enemy_card_ids: Array[String] = ["2", "1", "0"]  # Axe Man (TEMPORARY), Archer, Brettonian Guard
	for i: int in enemy_card_ids.size():
		var card_id: String = enemy_card_ids[i]
		var new_card: Card = await game.card_controller.create_unit_from_id(card_id, 1)

		if not new_card or not is_instance_valid(new_card):
			Log.error(
				"Failed to create enemy card for combat-only test",
				{"card_id": card_id, "position": i},
				["debug", "error", "test"]
			)
			return false

		new_card.block_context = Cards.CONTEXT.LINEUP
		core.action(core.EnemyLineupAddCardEvent.new(new_card, i))

	# Allied lineup: Minimal setup with one axe man (has TEMPORARY ability)
	var allied_card_ids: Array[String] = ["2", "1", "0"]  # Axe Man (TEMPORARY), Archer, Brettonian Guard
	for n: int in allied_card_ids.size():
		var card_id: String = allied_card_ids[n]
		var new_card: Card = await game.card_controller.create_unit_from_id(card_id, 1)

		if not new_card or not is_instance_valid(new_card):
			Log.error(
				"Failed to create allied card for combat-only test",
				{"card_id": card_id, "position": n},
				["debug", "error", "test"]
			)
			return false

		new_card.block_context = Cards.CONTEXT.LINEUP
		core.action(core.DebugLineupAddCardEvent.new(new_card, n))

	core.action(core.LineupOperationCompleteEvent.new())

	Log.info(
		"Combat-only test lineup populated",
		{
			"enemy_units": enemy_card_ids.size(),
			"allied_units": allied_card_ids.size(),
			"axe_man_count": 2,
			"test_purpose": "TEMPORARY persistence validation"
		},
		["debug", "test", "lineup", "combat_ability"]
	)

	return true


static func _get_game_node() -> Game:
	var root: Node = Engine.get_main_loop().current_scene
	if root and root.has_method("find_child"):
		var found_node: Node = root.find_child("Game", true, false)
		if found_node is Game:
			return found_node as Game
	return null


static func _wait_for_game_systems_ready() -> bool:
	var game_node: Node = null
	var root: Node = Engine.get_main_loop().current_scene

	if root and root.has_method("find_child"):
		game_node = root.find_child("Game", true, false)

	if not game_node:
		return false

	var clicker_node: Node = null
	if game_node.has_method("get") and game_node.get("clicker"):
		clicker_node = game_node.get("clicker")
		if clicker_node.has_method("get") and clicker_node.get("level"):
			return true

	if clicker_node:
		return true

	return false
