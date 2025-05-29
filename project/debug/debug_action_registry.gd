# project/debug/debug_action_registry.gd
# Debug action registry for GameTwo

class_name DebugActionRegistry
extends Node

# Internal storage: category -> group -> Array[DebugAction]
var _actions: Dictionary = {}
var _flat_actions: Array[DebugAction] = []


func _init() -> void:
	# Debug logging happens in _ready() when Log autoload is available
	pass


func _ready() -> void:
	assert(self == DebugRegistry, "DebugActionRegistry must be the DebugRegistry autoload")
	Log.info("Initializing debug action registry...", {}, ["debug", "system"])

	var start_time: int = Time.get_ticks_msec()
	_register_all_actions()
	var end_time: int = Time.get_ticks_msec()

	Log.info(
		"Debug action registry initialized",
		{
			"total_actions": _flat_actions.size(),
			"categories": get_categories().size(),
			"init_time_ms": end_time - start_time
		},
		["debug", "init"]
	)


func _register_all_actions() -> void:
	# Register built-in utility actions
	_register_builtin_actions()

	# Register manual debug actions
	_register_manual_actions()

	# Load and register actions from registration scripts
	var rtdb_actions_script = load("res://debug/actions/registrations/rtdb_actions.gd")
	if rtdb_actions_script:
		rtdb_actions_script.register_all(self)

	var core_actions_script = load("res://debug/actions/registrations/core_actions.gd")
	if core_actions_script:
		core_actions_script.register_all(self)

	var game_actions_script = load("res://debug/actions/registrations/game_actions.gd")
	if game_actions_script:
		game_actions_script.register_all(self)


func _register_builtin_actions() -> void:
	# Register built-in utility actions

	# System memory utilities
	register_action(
		(
			DebugAction
			. create("Force Low Memory Warning", _force_low_memory)
			. set_category("System")
			. set_group("Memory")
			. set_description("Simulates low memory condition for testing memory management")
		)
	)

	# Registry introspection utilities
	register_action(
		(
			DebugAction
			. create("Show Registry Stats", _show_registry_stats)
			. set_category("System")
			. set_group("Debug")
			. set_description("Display debug action registry statistics")
		)
	)

	# RTDB Status check - always available
	register_action(
		(
			DebugAction
			. create("RTDB Status", _rtdb_status_check)
			. set_category("RTDB")
			. set_group("Utilities")
			. set_description("Check RTDB availability and connection status")
		)
	)


func _register_manual_actions() -> void:
	# Register manual debug actions

	# Gameplay Actions
	register_action(
		(
			DebugAction
			. create("Reset Match Level", _reset_match_level)
			. set_category("Gameplay")
			. set_description("Reset the current match level")
		)
	)

	# Match Level Actions
	register_action(
		(
			DebugAction
			. create("Load Match Level 1", _load_match_level_1)
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 1")
		)
	)
	register_action(
		(
			DebugAction
			. create("Load Match Level 2", _load_match_level_2)
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 2")
		)
	)
	register_action(
		(
			DebugAction
			. create("Load Match Level 3", _load_match_level_3)
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 3")
		)
	)
	register_action(
		(
			DebugAction
			. create("Load Match Level 4", _load_match_level_4)
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 4")
		)
	)
	register_action(
		(
			DebugAction
			. create("Load Match Level 5", _load_match_level_5)
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 5")
		)
	)

	# Enemy/Debug Lineup Actions
	register_action(
		(
			DebugAction
			. create("Populate Enemy Lineup", _populate_enemy_lineup)
			. set_category("Gameplay")
			. set_group("Preset Lineups")
			. set_description("Add test cards to enemy lineup")
		)
	)

	# Database actions
	register_action(
		(
			DebugAction
			. create("Clear Card Cache", _clear_card_cache)
			. set_category("Database")
			. set_group("Cache")
			. set_description("Clear the card data cache")
		)
	)

	register_action(
		(
			DebugAction
			. create("Toggle Local Battle DB", _toggle_local_battle_db)
			. set_category("Database")
			. set_description("Toggle between local and remote battle database")
		)
	)

	# Quick Actions
	register_action(
		(
			DebugAction
			. create("Cycle Asset Variant", _cycle_asset_variant)
			. set_category("Quick Actions")
			. set_description("Cycle through asset variants (1-3)")
		)
	)

	register_action(
		(
			DebugAction
			. create("Print Debug Info", _print_debug_info)
			. set_category("Quick Actions")
			. set_description("Print current debug settings")
		)
	)

	Log.info("Manual debug actions registered", {}, ["debug", "manual"])


func _register_rtdb_actions() -> void:
	# This method is deprecated - RTDBDebugActions.register_all() is called directly in _register_all_actions()
	pass


func register_action(action: DebugAction) -> bool:
	# Register a debug action with validation

	if not action:
		Log.error("Cannot register null action", {}, ["debug", "error"])
		return false

	if action.action_name.is_empty():
		Log.error("Cannot register action with empty name", {}, ["debug", "error"])
		return false

	# Set default category if empty
	if action.category.is_empty():
		action.category = "Uncategorized"

	# Ensure category exists
	if not _actions.has(action.category):
		_actions[action.category] = {}

	# Ensure group exists
	var group_name: String = action.group if not action.group.is_empty() else "_ungrouped"
	if not _actions[action.category].has(group_name):
		var new_array: Array[DebugAction] = []
		_actions[action.category][group_name] = new_array

	# Register the action
	_actions[action.category][group_name].append(action)
	_flat_actions.append(action)

	Log.debug(
		"Debug action registered successfully",
		{
			"name": action.action_name,
			"category": action.category,
			"group": action.group,
			"total_actions": _flat_actions.size()
		},
		["debug", "registration"]
	)

	return true


# Public API methods for accessing registered actions
func get_categories() -> Array[String]:
	# Get all registered categories, sorted alphabetically
	var categories: Array[String] = []
	var keys_array: Array = _actions.keys()
	categories.assign(keys_array)
	categories.sort()
	return categories


func get_groups_for_category(category_name: String) -> Array[String]:
	# Get all groups within a category, excluding ungrouped actions
	if not _actions.has(category_name):
		var empty_array: Array[String] = []
		return empty_array

	var groups: Array[String] = []
	var keys_array: Array = _actions[category_name].keys()
	groups.assign(keys_array)
	groups.erase("_ungrouped")
	groups.sort()
	return groups


func get_actions_for_group(category_name: String, group_name: String) -> Array[DebugAction]:
	if not _actions.has(category_name):
		var empty_array: Array[DebugAction] = []
		return empty_array

	var group_key: String = group_name if not group_name.is_empty() else "_ungrouped"
	if not _actions[category_name].has(group_key):
		var empty_array: Array[DebugAction] = []
		return empty_array

	var actions_array: Array[DebugAction] = _actions[category_name][group_key]
	return actions_array


func get_ungrouped_actions(category_name: String) -> Array[DebugAction]:
	return get_actions_for_group(category_name, "")


func has_ungrouped_actions(category_name: String) -> bool:
	return _actions.has(category_name) and _actions[category_name].has("_ungrouped")


func get_all_actions() -> Array[DebugAction]:
	return _flat_actions


func get_actions() -> Array[DebugAction]:
	return get_all_actions()


# Action implementations
static func _rtdb_status_check() -> void:
	# Check RTDB status and availability
	var status: Dictionary = {
		"firebase_database_available": ClassDB.class_exists("FirebaseDatabase"),
		"firebase_auth_available": ClassDB.class_exists("FirebaseAuth"),
		"platform": OS.get_name(),
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info("RTDB Status Check", status, ["debug", "rtdb", "status"])


static func _force_low_memory() -> void:
	# Simulate low memory condition
	Log.warning("Simulating low memory condition for testing", {}, ["debug", "system", "memory"])

	if OS.has_method("low_processor_usage_mode"):
		var old_mode: bool = OS.low_processor_usage_mode
		OS.low_processor_usage_mode = true
		OS.low_processor_usage_mode = old_mode

	Log.info("Low memory simulation completed", {}, ["debug", "system", "memory"])


func _show_registry_stats() -> void:
	# Display debug action registry statistics
	var stats: Dictionary = {
		"total_actions": _flat_actions.size(),
		"total_categories": get_categories().size(),
		"categories": {}
	}

	for category: String in get_categories():
		var category_stats: Dictionary = {
			"groups": get_groups_for_category(category).size(),
			"ungrouped_actions": get_ungrouped_actions(category).size(),
			"total_actions": 0
		}

		for group: String in get_groups_for_category(category):
			category_stats.total_actions += get_actions_for_group(category, group).size()
		category_stats.total_actions += category_stats.ungrouped_actions

		stats.categories[category] = category_stats

	Log.info("Debug Action Registry Statistics", stats, ["debug", "registry", "stats"])


# Manual action implementations
static func _reset_match_level() -> void:
	# Reset the current match level
	if DebugManager:
		DebugManager.action(DebugManager.DebugEventType.EVENT_RESET_MATCH_LEVEL)
		Log.info("Match level reset", {}, ["debug", "gameplay"])
	else:
		Log.error("DebugManager not available", {}, ["debug", "error"])


static func _load_match_level_1() -> void:
	_load_match_level(1)


static func _load_match_level_2() -> void:
	_load_match_level(2)


static func _load_match_level_3() -> void:
	_load_match_level(3)


static func _load_match_level_4() -> void:
	_load_match_level(4)


static func _load_match_level_5() -> void:
	_load_match_level(5)


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
			new_card.block_context = Cards.CONTEXT.LINEUP
			core.action(core.EnemyLineupAddCardEvent.new(new_card, n))

	# Create debug cards
	for n: int in 3:
		var new_card: Variant = await card_controller.create_unit_from_id(str(n), 1)
		if new_card and is_instance_valid(new_card):
			new_card.block_context = Cards.CONTEXT.LINEUP
			core.action(core.DebugLineupAddCardEvent.new(new_card, n))

	Log.info("Enemy lineup populated", {}, ["debug", "gameplay"])


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
