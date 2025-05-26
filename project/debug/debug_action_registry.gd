# project/debug/debug_action_registry.gd
extends Node

# Note: This registry now handles both resource-based and programmatic actions
# Manual actions are registered directly here during _ready()

var actions: Array[DebugAction] = []
const ACTIONS_PATH: String = "res://debug/actions/"

# Add support for programmatic registration
var _programmatic_actions: Array[DebugAction] = []


func _init() -> void:
	print("DebugActionRegistry instance created")


func _ready() -> void:
	Log.info("DebugActionRegistry initializing...", {}, ["debug", "system"])
	_scan_for_actions()
	_register_default_manual_actions()


func _scan_for_actions() -> void:
	actions.clear()

	# Use Android-compatible resource loading approach
	# DirAccess.open() doesn't work reliably on Android with packaged resources
	_load_known_actions()

	# If no actions loaded, try fallback directory scanning (for development)
	if actions.is_empty():
		Log.warning(
			"No actions loaded via known resource paths, trying fallback directory scan",
			{},
			["debug", "system"]
		)
		_recursive_scan_fallback(ACTIONS_PATH)

	# Sort actions alphabetically
	actions.sort_custom(
		func(a: DebugAction, b: DebugAction) -> bool: return a.action_name < b.action_name
	)

	var total_actions = actions.size() + _programmatic_actions.size()
	Log.info(
		(
			"DebugActionRegistry: Loaded %d resource actions, %d programmatic actions (total: %d)"
			% [actions.size(), _programmatic_actions.size(), total_actions]
		),
		{},
		["debug", "system"]
	)

	# Log available categories for debugging
	var categories = get_categories()
	Log.info(
		"Available categories after initialization: %s" % str(categories), {}, ["debug", "system"]
	)


func _load_known_actions() -> void:
	# Known action resource paths - Android-compatible approach
	# This list should be updated when new actions are added
	var known_action_paths: Array[String] = [
		# Core actions
		"res://debug/actions/core/log_system_info.tres",
		# RTDB actions
		"res://debug/actions/rtdb/rtdb_batch_operations.tres",
		"res://debug/actions/rtdb/rtdb_child_added_listener.tres",
		"res://debug/actions/rtdb/rtdb_child_changed_listener.tres",
		"res://debug/actions/rtdb/rtdb_child_removed_listener.tres",
		"res://debug/actions/rtdb/rtdb_concurrent_operations.tres",
		"res://debug/actions/rtdb/rtdb_delete_value.tres",
		"res://debug/actions/rtdb/rtdb_error_handling_test.tres",
		"res://debug/actions/rtdb/rtdb_get_nested_path.tres",
		"res://debug/actions/rtdb/rtdb_get_simple_value.tres",
		"res://debug/actions/rtdb/rtdb_large_data_test.tres",
		"res://debug/actions/rtdb/rtdb_list_children.tres",
		"res://debug/actions/rtdb/rtdb_path_validation.tres",
		"res://debug/actions/rtdb/rtdb_remove_all_listeners.tres",
		"res://debug/actions/rtdb/rtdb_set_nested_path.tres",
		"res://debug/actions/rtdb/rtdb_set_simple_value.tres",
		"res://debug/actions/rtdb/rtdb_single_value_listener.tres",
		"res://debug/actions/rtdb/rtdb_transaction_test.tres",
		"res://debug/actions/rtdb/rtdb_update_value.tres",
		# Legacy RTDB actions (migrated from scene_debug.gd)
		"res://debug/actions/rtdb/rtdb_legacy_basic_set_simple_value.tres",
		"res://debug/actions/rtdb/rtdb_legacy_basic_get_simple_value.tres",
		"res://debug/actions/rtdb/rtdb_legacy_basic_push_item.tres",
	]

	for resource_path: String in known_action_paths:
		_load_action_resource(resource_path)


func _recursive_scan_fallback(path: String) -> void:
	# Fallback directory scanning for development environments
	# This may not work on Android but is useful for desktop development
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		Log.warning("Could not scan actions directory (fallback): " + path, {}, ["debug", "system"])
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path: String = path.path_join(file_name)

		if dir.current_is_dir():
			_recursive_scan_fallback(full_path)
		elif file_name.ends_with(".tres"):
			_load_action_resource(full_path)

		file_name = dir.get_next()


func _load_action_resource(resource_path: String) -> void:
	if not ResourceLoader.exists(resource_path):
		Log.warning("Action resource not found: " + resource_path, {}, ["debug", "system"])
		return

	var resource: Resource = load(resource_path)
	if resource is DebugAction:
		actions.append(resource as DebugAction)
		Log.info("Loaded action: " + (resource as DebugAction).action_name, {}, ["debug", "system"])
	else:
		Log.warning("Resource is not a DebugAction: " + resource_path, {}, ["debug", "system"])


# Add method to register callable-based actions
func register_callable(
	name: String,
	callable: Callable,
	category: String = "Manual",
	group: String = "",
	description: String = ""
) -> void:
	var action := DebugAction.create_from_callable(name, callable, category, group, description)
	_programmatic_actions.append(action)
	var group_info = " (ungrouped)" if group == "" else "/" + group
	Log.info("Registered programmatic action: %s in %s%s" % [name, category, group_info])


func get_actions() -> Array[DebugAction]:
	# Combine resource-based and programmatic actions
	var all_actions: Array[DebugAction] = actions.duplicate()
	all_actions.append_array(_programmatic_actions)
	return all_actions


func get_categories() -> Array[String]:
	# Ensure actions are loaded
	if actions.is_empty():
		_scan_for_actions()

	var categories: Dictionary = {}

	# Add from resource-based actions
	for action: DebugAction in actions:
		if action and not action.category.is_empty():
			categories[action.category] = true

	# Add from programmatic actions
	for action: DebugAction in _programmatic_actions:
		if action and not action.category.is_empty():
			categories[action.category] = true

	var sorted_categories: Array[String]
	sorted_categories.assign(categories.keys())
	sorted_categories.sort()
	return sorted_categories


func get_groups_for_category(category_name: String) -> Array[String]:
	var groups: Dictionary = {}

	# Add from resource-based actions
	for action: DebugAction in actions:
		if action.category == category_name and not action.group.is_empty():
			groups[action.group] = true

	# Add from programmatic actions
	for action: DebugAction in _programmatic_actions:
		if action.category == category_name and not action.group.is_empty():
			groups[action.group] = true

	var sorted_groups: Array[String]
	sorted_groups.assign(groups.keys())
	sorted_groups.sort()
	return sorted_groups


func get_actions_for_group(category_name: String, group_name: String) -> Array[DebugAction]:
	var group_actions: Array[DebugAction] = []

	# Add from resource-based actions
	for action: DebugAction in actions:
		if action.category == category_name and action.group == group_name:
			group_actions.append(action)

	# Add from programmatic actions
	for action: DebugAction in _programmatic_actions:
		if action.category == category_name and action.group == group_name:
			group_actions.append(action)

	return group_actions


# Get ungrouped actions for a specific category
func get_ungrouped_actions(category_name: String) -> Array[DebugAction]:
	var ungrouped: Array[DebugAction] = []

	# Add from resource-based actions
	for action: DebugAction in actions:
		if action.category == category_name and action.group == "":
			ungrouped.append(action)

	# Add from programmatic actions
	for action: DebugAction in _programmatic_actions:
		if action.category == category_name and action.group == "":
			ungrouped.append(action)

	return ungrouped


# Check if category has ungrouped actions
func has_ungrouped_actions(category_name: String) -> bool:
	# Check resource-based actions
	for action: DebugAction in actions:
		if action.category == category_name and action.group == "":
			return true

	# Check programmatic actions
	for action: DebugAction in _programmatic_actions:
		if action.category == category_name and action.group == "":
			return true

	return false


func register_action(action: DebugAction) -> void:
	if not action:
		push_error("Cannot register null action")
		return

	if actions.has(action):
		return  # Already registered

	actions.append(action)
	Log.debug("Manually registered action: " + action.action_name, {}, ["debug", "system"])


# Register all default manual actions directly in the unified registry
func _register_default_manual_actions() -> void:
	Log.info("Registering default manual actions in unified registry", {}, ["debug", "system"])

	# Gameplay Actions - some with groups, some without
	register_callable(
		"Reset Match Level",
		func(): DebugManager.action(DebugManager.DebugEventType.EVENT_RESET_MATCH_LEVEL),
		"Gameplay",
		"",
		"Reset the current match level"  # No group
	)

	# Match Level Actions - grouped together
	for i in range(1, 6):
		var level_num = i  # Capture the value for the lambda
		register_callable(
			"Load Match Level %d" % level_num,
			func(level = level_num):
				DebugManager.action(
					DebugManager.DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_%02d" % level]
				),
			"Gameplay",
			"Match Levels",
			"Force load match level %d" % level_num
		)

	# Enemy/Debug Lineup Actions
	register_callable(
		"Populate Enemy Lineup",
		_populate_enemy_lineup,
		"Gameplay",
		"Preset Lineups",
		"Add test cards to enemy lineup"
	)

	# Database actions - mixed grouped and ungrouped
	register_callable(
		"Clear Card Cache",
		func():
			if data_source and data_source.has_method("clear_card_cache"):
				data_source.clear_card_cache()
			Log.info("Card cache cleared"),
		"Database",
		"Cache",
		"Clear the card data cache"
	)

	register_callable(
		"Toggle Local Battle DB",
		func():
			DebugManager.use_local_battle_db = not DebugManager.use_local_battle_db
			Log.info("Local battle DB: " + str(DebugManager.use_local_battle_db)),
		"Database",
		"",
		"Toggle between local and remote battle database"  # No group
	)

	# Quick Actions - all without groups (simpler organization)
	register_callable(
		"Cycle Asset Variant",
		func():
			DebugManager.asset_variant = (DebugManager.asset_variant % 3) + 1
			Log.info("Asset variant set to: " + str(DebugManager.asset_variant)),
		"Quick Actions",
		"",
		"Cycle through asset variants (1-3)"
	)

	register_callable(
		"Print Debug Info",
		func():
			Log.info("=== Debug Info ===")
			Log.info("Local DB: %s" % DebugManager.use_local_battle_db)
			Log.info("Asset Variant: %d" % DebugManager.asset_variant)
			Log.info("=================="),
		"Quick Actions",
		"",
		"Print current debug settings"
	)

	# System Actions - no groups needed
	register_callable(
		"Force Garbage Collection",
		func():
			OS.request_permissions()
			Log.info("Garbage collection requested"),
		"System",
		"",
		"Request garbage collection"
	)

	Log.info("Default manual actions registered", {}, ["debug", "system"])


# Legacy function preserved for enemy lineup action
func _populate_enemy_lineup() -> void:
	if not is_instance_valid(core) or not is_instance_valid(card_controller):
		Log.error("Cannot populate enemy lineup: core or card_controller missing")
		return

	# Create enemy cards
	for n in 3:
		var new_card = await card_controller.create_unit_from_id(str(n), 1)
		new_card.block_context = Cards.CONTEXT.LINEUP
		core.action(core.EnemyLineupAddCardEvent.new(new_card, n))

	# Create debug cards
	for n in 3:
		var new_card = await card_controller.create_unit_from_id(str(n), 1)
		new_card.block_context = Cards.CONTEXT.LINEUP
		core.action(core.DebugLineupAddCardEvent.new(new_card, n))

	Log.info("Enemy lineup populated with test cards")


# Programmatic registration - following YAGNI, only register actions that exist
func _register_all_actions_programmatically() -> void:
	# Disabled - causes class loading issues in some environments
	# Use resource scanning instead
	Log.info("Programmatic registration disabled, using resource scanning", {}, ["debug", "system"])
	return
