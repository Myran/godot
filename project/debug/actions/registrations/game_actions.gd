# project/debug/actions/registrations/game_actions.gd
# GameTwo-specific debug actions for gameplay, content, and domain logic

class_name GameDebugActions
extends RefCounted


static func register_all(registry: DebugActionRegistry) -> void:
	_register_gameplay_actions(registry)
	_register_match_level_actions(registry)
	_register_lineup_actions(registry)
	#_register_card_actions(registry)
	_register_database_actions(registry)
	_register_quick_actions(registry)

	Log.info("Game debug actions registered", {}, ["debug", "game"])


static func _register_gameplay_actions(registry: DebugActionRegistry) -> void:
	# Core gameplay actions
	registry.register_action(
		(
			DebugAction
			. create("Reset Match Level", _reset_match_level)
			. set_category("Gameplay")
			. set_description("Reset the current match level")
		)
	)


static func _register_match_level_actions(registry: DebugActionRegistry) -> void:
	# Match Level Actions
	registry.register_action(
		(
			DebugAction
			. create("Load Match Level 1", func() -> void: _load_match_level(1))
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 1")
		)
	)
	registry.register_action(
		(
			DebugAction
			. create("Load Match Level 2", func() -> void: _load_match_level(2))
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 2")
		)
	)
	registry.register_action(
		(
			DebugAction
			. create("Load Match Level 3", func() -> void: _load_match_level(3))
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 3")
		)
	)
	registry.register_action(
		(
			DebugAction
			. create("Load Match Level 4", func() -> void: _load_match_level(4))
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 4")
		)
	)
	registry.register_action(
		(
			DebugAction
			. create("Load Match Level 5", func() -> void: _load_match_level(5))
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 5")
		)
	)


static func _register_lineup_actions(registry: DebugActionRegistry) -> void:
	# Enemy/Debug Lineup Actions
	registry.register_action(
		(
			DebugAction
			. create("Populate Enemy Lineup", _populate_enemy_lineup)
			. set_category("Gameplay")
			. set_group("Preset Lineups")
			. set_description("Add test cards to enemy lineup")
		)
	)


#static func _register_card_actions(registry: DebugActionRegistry) -> void:
## Player Card Actions
#registry.register_action(
#(
#DebugAction
#. create("Spawn Test Cards", _spawn_test_cards)
#. set_category("Gameplay")
#. set_group("Cards")
#. set_description("Spawns 3 random test cards for the player")
#)
#)


static func _register_database_actions(registry: DebugActionRegistry) -> void:
	# GameTwo database actions
	registry.register_action(
		(
			DebugAction
			. create("Clear Card Cache", _clear_card_cache)
			. set_category("Database")
			. set_group("Cache")
			. set_description("Clear the card data cache")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("Toggle Local Battle DB", _toggle_local_battle_db)
			. set_category("Database")
			. set_description("Toggle between local and remote battle database")
		)
	)


static func _register_quick_actions(registry: DebugActionRegistry) -> void:
	# Quick utility actions for GameTwo
	registry.register_action(
		(
			DebugAction
			. create("Cycle Asset Variant", _cycle_asset_variant)
			. set_category("Quick Actions")
			. set_description("Cycle through asset variants (1-3)")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("Print Debug Info", _print_debug_info)
			. set_category("Quick Actions")
			. set_description("Print current debug settings")
		)
	)


# Game action implementations
static func _reset_match_level() -> void:
	# Reset the current match level
	if DebugManager:
		DebugManager.action(DebugManager.DebugEventType.EVENT_RESET_MATCH_LEVEL)
		Log.info("Match level reset", {}, ["debug", "gameplay"])
	else:
		Log.error("DebugManager not available", {}, ["debug", "error"])


static func _load_match_level(level_num: int) -> void:
	# Load a specific match level
	if DebugManager:
		DebugManager.action(
			DebugManager.DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_%02d" % level_num]
		)
		Log.info("Loading match level %d" % level_num, {}, ["debug", "gameplay"])
	else:
		Log.error("DebugManager not available", {}, ["debug", "error"])


static func _populate_enemy_lineup() -> void:
	# Add test cards to enemy lineup
	if not is_instance_valid(core) or not is_instance_valid(card_controller):
		Log.error(
			"Cannot populate enemy lineup: core or card_controller missing", {}, ["debug", "error"]
		)
		return

	Log.info("Populating enemy lineup with test cards", {}, ["debug", "gameplay"])

	# Create enemy cards
	for n: int in 3:
		var new_card: Variant = await card_controller.create_unit_from_id(str(n), 1)
		if new_card and is_instance_valid(new_card):
			var typed_card: Card = new_card  # Fail fast if not actually a Card
			typed_card.block_context = Cards.CONTEXT.LINEUP
			core.action(core.EnemyLineupAddCardEvent.new(typed_card, n))

	# Create debug cards
	for n: int in 3:
		var new_card: Variant = await card_controller.create_unit_from_id(str(n), 1)
		if new_card and is_instance_valid(new_card):
			var typed_card: Card = new_card  # Fail fast if not actually a Card
			typed_card.block_context = Cards.CONTEXT.LINEUP
			core.action(core.DebugLineupAddCardEvent.new(typed_card, n))

	Log.info("Enemy lineup populated", {}, ["debug", "gameplay"])


#static func _spawn_test_cards() -> void:
## Spawn 3 random test cards for the player
#if not is_instance_valid(card_controller) or not is_instance_valid(core):
#Log.error("Cannot spawn cards: Missing card_controller or core", {}, ["debug", "error"])
#return
#
#Log.info("Spawning 3 test cards for player...", {}, ["debug", "gameplay"])
#
#for i: int in 3:
#var card: Variant = await card_controller.get_card_from_pool()
#if card:
#var typed_card: Card = card  # Fail fast if not actually a Card
## Add to player's hand or appropriate location
#core.action(core.DrawCardEvent.new(typed_card))
#var card_id: String = str(typed_card.get("id")) if typed_card.has("id") else "unknown"
#Log.debug("Spawned card: %s" % card_id, {"card_id": card_id}, ["debug", "gameplay"])
#
#Log.info("Test cards spawned successfully", {}, ["debug", "gameplay"])


static func _clear_card_cache() -> void:
	# Clear the card data cache
	if data_source and data_source.has_method("clear_card_cache"):
		data_source.clear_card_cache()
		Log.info("Card cache cleared", {}, ["debug", "database"])
	else:
		Log.warning(
			"data_source not available or doesn't support clear_card_cache",
			{},
			["debug", "database"]
		)


static func _toggle_local_battle_db() -> void:
	# Toggle between local and remote battle database
	if DebugManager:
		DebugManager.use_local_battle_db = not DebugManager.use_local_battle_db
		Log.info(
			"Local battle DB: %s" % DebugManager.use_local_battle_db, {}, ["debug", "database"]
		)
	else:
		Log.error("DebugManager not available", {}, ["debug", "error"])


static func _cycle_asset_variant() -> void:
	# Cycle through asset variants (1-3)
	if DebugManager:
		DebugManager.asset_variant = (DebugManager.asset_variant % 3) + 1
		Log.info("Asset variant set to: %d" % DebugManager.asset_variant, {}, ["debug", "quick"])
	else:
		Log.error("DebugManager not available", {}, ["debug", "error"])


static func _print_debug_info() -> void:
	# Print current debug settings
	Log.info("=== Debug Info ===", {}, ["debug", "quick"])
	if DebugManager:
		Log.info("Local DB: %s" % DebugManager.use_local_battle_db, {}, ["debug", "quick"])
		Log.info("Asset Variant: %d" % DebugManager.asset_variant, {}, ["debug", "quick"])
	else:
		Log.warning("DebugManager not available", {}, ["debug", "quick"])
	Log.info("==================", {}, ["debug", "quick"])
