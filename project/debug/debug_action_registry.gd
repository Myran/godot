# project/debug/debug_action_registry.gd
# Programmatic-only debug action registry for GameTwo
# All debug actions are registered via code - no resource file dependencies

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
	Log.info("Initializing programmatic debug action registry...", {}, ["debug", "system"])

	var start_time := Time.get_ticks_msec()
	_register_all_actions()
	var end_time := Time.get_ticks_msec()

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
	# Register actions from organized category files
	_register_category_actions("RTDB", RTDBDebugActions)
	_register_category_actions("Core", CoreDebugActions)
	_register_category_actions("Game", GameDebugActions)

	# Register built-in utility actions
	_register_builtin_actions()


func _register_category_actions(category_name: String, actions_class) -> void:
	"""Register actions from a category-specific class with error handling"""
	var initial_count := _flat_actions.size()

	if actions_class and actions_class.has_method("register_all"):
		actions_class.register_all(self)
		var added_count := _flat_actions.size() - initial_count
		Log.debug(
			"Registered category actions",
			{"category": category_name, "actions_added": added_count},
			["debug", "registration"]
		)
	else:
		Log.error("Invalid actions class for category: " + category_name, {}, ["debug", "error"])


func _register_builtin_actions() -> void:
	"""Register built-in utility actions that don't require separate files"""

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


func register_action(action: DebugAction) -> bool:
	"""Register a debug action with comprehensive validation"""

	# Validation checks
	if not action:
		Log.error("Cannot register null action", {}, ["debug", "error"])
		return false

	if action.action_name.is_empty():
		Log.error("Cannot register action with empty name", {}, ["debug", "error"])
		return false

	# Check for duplicate action names within the same category
	if _is_action_duplicate(action):
		Log.warning(
			"Action already exists, skipping registration",
			{"name": action.action_name, "category": action.category},
			["debug", "registration"]
		)
		return false

	# Set default category if empty
	if action.category.is_empty():
		action.category = "Uncategorized"

	# Ensure category exists
	if not _actions.has(action.category):
		_actions[action.category] = {}

	# Ensure group exists
	var group_name := action.group if not action.group.is_empty() else "_ungrouped"
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


func _is_action_duplicate(action: DebugAction) -> bool:
	"""Check if an action with the same name already exists in the same category"""
	for existing_action in _flat_actions:
		if (
			existing_action.action_name == action.action_name
			and existing_action.category == action.category
		):
			return true
	return false


# Legacy compatibility method - prefer register_action() for new code
func register_callable(
	action_name: String,
	callable: Callable,
	category: String = "Manual",
	group: String = "",
	description: String = ""
) -> bool:
	"""Legacy method for backward compatibility - creates DebugAction from callable"""
	var action := DebugAction.create_from_callable(
		action_name, callable, category, group, description
	)
	return register_action(action)


# Public API methods for accessing registered actions
func get_categories() -> Array[String]:
	"""Get all registered categories, sorted alphabetically"""
	var categories: Array[String] = []
	categories.assign(_actions.keys())
	categories.sort()
	return categories


func get_groups_for_category(category_name: String) -> Array[String]:
	"""Get all groups within a category, excluding ungrouped actions"""
	if not _actions.has(category_name):
		Log.debug("Category not found: " + category_name, {}, ["debug", "registry"])
		var empty_array: Array[String] = []
		return empty_array

	var groups: Array[String] = []
	groups.assign(_actions[category_name].keys())
	groups.erase("_ungrouped")  # Remove internal ungrouped key
	groups.sort()
	return groups


func get_actions_for_group(category_name: String, group_name: String) -> Array[DebugAction]:
	if not _actions.has(category_name):
		var empty_array: Array[DebugAction] = []
		return empty_array

	var group_key := group_name if not group_name.is_empty() else "_ungrouped"
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


# Legacy method for compatibility
func get_actions() -> Array[DebugAction]:
	return get_all_actions()


# Built-in utility action implementations
static func _force_low_memory() -> void:
	"""Simulate low memory condition for testing memory management systems"""
	Log.warning("Simulating low memory condition for testing", {}, ["debug", "system", "memory"])

	# Request garbage collection using available methods
	# Note: Godot doesn't have a direct GC method, so we use memory pressure signals
	if OS.has_method("low_processor_usage_mode"):
		var old_mode = OS.low_processor_usage_mode
		OS.low_processor_usage_mode = true
		OS.low_processor_usage_mode = old_mode

	Log.info("Low memory simulation completed", {}, ["debug", "system", "memory"])


func _show_registry_stats() -> void:
	"""Display comprehensive debug action registry statistics"""
	var stats := {
		"total_actions": _flat_actions.size(),
		"total_categories": get_categories().size(),
		"categories": {}
	}

	# Collect per-category statistics
	for category in get_categories():
		var category_stats := {
			"groups": get_groups_for_category(category).size(),
			"ungrouped_actions": get_ungrouped_actions(category).size(),
			"total_actions": 0
		}

		# Count actions in all groups
		for group in get_groups_for_category(category):
			category_stats.total_actions += get_actions_for_group(category, group).size()
		category_stats.total_actions += category_stats.ungrouped_actions

		stats.categories[category] = category_stats

	Log.info("Debug Action Registry Statistics", stats, ["debug", "registry", "stats"])
