# project/debug/actions/registrations/game_actions.gd
class_name GameDebugActions
extends RefCounted


static func register_all(registry: DebugActionRegistry) -> void:
	_register_gameplay_actions(registry)
	_register_database_actions(registry)
	_register_quick_actions(registry)


static func _register_gameplay_actions(registry: DebugActionRegistry) -> void:
	# Reset Match Level - ungrouped
	registry.register_action(
		(
			DebugAction
			. create("Reset Match Level", _reset_match_level)
			. set_category("Gameplay")
			. set_description("Reset the current match level")
		)
	)

	# Match Level Actions - grouped together
	for i in range(1, 6):
		var level_num := i
		var level_string := "level_%02d" % level_num
		var action_name := "Load Match Level %d" % level_num
		var description := "Force load match level %d" % level_num

		registry.register_action(
			(
				DebugAction
				. create(action_name, func(): _force_load_match_level(level_string))
				. set_category("Gameplay")
				. set_group("Match Levels")
				. set_description(description)
			)
		)

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


static func _register_database_actions(registry: DebugActionRegistry) -> void:
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


# Implementation functions
static func _reset_match_level() -> void:
	DebugManager.action(DebugManager.DebugEventType.EVENT_RESET_MATCH_LEVEL)


static func _force_load_match_level(level_string: String) -> void:
	var args_array: Array[String] = [level_string]
	DebugManager.action(DebugManager.DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, args_array)


static func _populate_enemy_lineup() -> void:
	if not is_instance_valid(core) or not is_instance_valid(card_controller):
		Log.error("Cannot populate enemy lineup: core or card_controller missing")
		return

	# Create enemy cards
	for n in 3:
		var new_card: Card = await card_controller.create_unit_from_id(str(n), 1)
		new_card.block_context = Cards.CONTEXT.LINEUP
		core.action(core.EnemyLineupAddCardEvent.new(new_card, n))

	# Create debug cards
	for n in 3:
		var new_card: Card = await card_controller.create_unit_from_id(str(n), 1)
		new_card.block_context = Cards.CONTEXT.LINEUP
		core.action(core.DebugLineupAddCardEvent.new(new_card, n))

	Log.info("Enemy lineup populated with test cards")


static func _clear_card_cache() -> void:
	# Check if data_source instance exists and has the method
	if is_instance_valid(data_source) and data_source.has_method("clear_card_cache"):
		data_source.clear_card_cache()
	else:
		Log.info("data_source clear_card_cache method not available", {}, ["debug", "cache"])
	Log.info("Card cache cleared", {}, ["debug", "cache"])


static func _toggle_local_battle_db() -> void:
	var current_setting: bool = DebugManager.use_local_battle_db
	var new_setting: bool = not current_setting
	DebugManager.use_local_battle_db = new_setting
	Log.info("Local battle DB: " + str(new_setting), {}, ["debug", "database"])


static func _cycle_asset_variant() -> void:
	var current_variant: int = DebugManager.asset_variant
	var next_variant: int = (current_variant % 3) + 1
	DebugManager.asset_variant = next_variant
	Log.info("Asset variant set to: " + str(next_variant), {}, ["debug", "assets"])


static func _print_debug_info() -> void:
	Log.info("=== Debug Info ===", {}, ["debug", "info"])
	Log.info("Local DB: %s" % str(DebugManager.use_local_battle_db), {}, ["debug", "info"])
	Log.info("Asset Variant: %d" % DebugManager.asset_variant, {}, ["debug", "info"])
	Log.info("==================", {}, ["debug", "info"])
