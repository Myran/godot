# project/debug/debug_action_registry.gd
# Debug action registry for GameTwo - Pure registry logic only

class_name DebugActionRegistry
extends Node

# Signal emitted when registry initialization is complete
signal registry_initialized(action_count: int)

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

	# Emit signal to notify that registry is ready
	registry_initialized.emit(_flat_actions.size())


func _register_all_actions() -> void:
	# Register system-level actions (infrastructure/platform)
	var system_actions_script: GDScript = load(
		"res://debug/actions/registrations/system_actions.gd"
	)
	if system_actions_script:
		system_actions_script.register_all(self)

	# Load and register C++ Firebase actions (NEW)
	var cpp_firebase_actions_script: GDScript = load(
		"res://debug/actions/registrations/cpp_firebase_actions.gd"
	)
	if cpp_firebase_actions_script:
		cpp_firebase_actions_script.register_all(self)

	# Load and register Backend Firebase actions (NEW)
	var backend_firebase_actions_script: GDScript = load(
		"res://debug/actions/registrations/backend_firebase_actions.gd"
	)
	if backend_firebase_actions_script:
		backend_firebase_actions_script.register_all(self)

	# Load and register RTDB actions (existing integration tests)
	var rtdb_actions_script: GDScript = load("res://debug/actions/registrations/rtdb_actions.gd")
	if rtdb_actions_script:
		rtdb_actions_script.register_all(self)

	# Register game-specific actions (GameTwo domain logic)
	var game_actions_script: GDScript = load("res://debug/actions/registrations/game_actions.gd")
	if game_actions_script:
		game_actions_script.register_all(self)


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
			"group": action.group if not action.group.is_empty() else "none",
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
