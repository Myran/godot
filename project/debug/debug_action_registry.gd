# project/debug/debug_action_registry.gd
extends Node

var actions: Array[DebugAction] = []
const ACTIONS_PATH: String = "res://debug/actions/"


func _init() -> void:
	print("DebugActionRegistry instance created")


func _ready() -> void:
	Log.info("DebugActionRegistry initializing...", {}, ["debug", "system"])
	_scan_for_actions()


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

	Log.info("DebugActionRegistry: Loaded %d actions." % actions.size(), {}, ["debug", "system"])


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


func get_actions() -> Array[DebugAction]:
	return actions


func get_categories() -> Array[String]:
	# Ensure actions are loaded
	if actions.is_empty():
		_scan_for_actions()

	var categories: Dictionary = {}
	for action: DebugAction in actions:
		if action and not action.category.is_empty():
			categories[action.category] = true

	var sorted_categories: Array[String]
	sorted_categories.assign(categories.keys())
	sorted_categories.sort()
	return sorted_categories


func get_groups_for_category(category_name: String) -> Array[String]:
	var groups: Dictionary = {}
	for action: DebugAction in actions:
		if action.category == category_name and not action.group.is_empty():
			groups[action.group] = true

	var sorted_groups: Array[String]
	sorted_groups.assign(groups.keys())
	sorted_groups.sort()
	return sorted_groups


func get_actions_for_group(category_name: String, group_name: String) -> Array[DebugAction]:
	var group_actions: Array[DebugAction] = []
	for action: DebugAction in actions:
		if action.category == category_name and action.group == group_name:
			group_actions.append(action)
	return group_actions


func register_action(action: DebugAction) -> void:
	if not action:
		push_error("Cannot register null action")
		return

	if actions.has(action):
		return  # Already registered

	actions.append(action)
	Log.debug("Manually registered action: " + action.action_name, {}, ["debug", "system"])


# Programmatic registration - following YAGNI, only register actions that exist
func _register_all_actions_programmatically() -> void:
	# Disabled - causes class loading issues in some environments
	# Use resource scanning instead
	Log.info("Programmatic registration disabled, using resource scanning", {}, ["debug", "system"])
	return
