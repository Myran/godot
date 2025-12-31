class_name DebugActionRegistry
extends Node

signal registry_initialized(action_count: int)

var _actions: Dictionary = {}
var _flat_actions: Array[DebugAction] = []


func _init() -> void:
	pass


func _ready() -> void:
	assert(self == DebugRegistry, "DebugActionRegistry must be the DebugRegistry autoload")
	Log.info("Initializing debug action registry...", {}, [Log.TAG_DEBUG, Log.TAG_SYSTEM])

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

	registry_initialized.emit(_flat_actions.size())


func _register_all_actions() -> void:
	var system_actions_script: GDScript = load(
		"res://debug/actions/registrations/system_actions.gd"
	)
	if system_actions_script:
		system_actions_script.register_all(self)

	var cpp_firebase_actions_script: GDScript = load(
		"res://debug/actions/registrations/cpp_firebase_actions.gd"
	)
	if cpp_firebase_actions_script:
		cpp_firebase_actions_script.register_all(self)

	var backend_firebase_actions_script: GDScript = load(
		"res://debug/actions/registrations/backend_firebase_actions.gd"
	)
	if backend_firebase_actions_script:
		backend_firebase_actions_script.register_all(self)

	var rtdb_actions_script: GDScript = load("res://debug/actions/registrations/rtdb_actions.gd")
	if rtdb_actions_script:
		rtdb_actions_script.register_all(self)

	var game_actions_script: GDScript = load("res://debug/actions/registrations/game_actions.gd")
	if game_actions_script:
		game_actions_script.register_all(self)

	var firebase_debug_actions_script: GDScript = load(
		"res://debug/actions/registrations/firebase_debug_actions.gd"
	)
	if firebase_debug_actions_script:
		firebase_debug_actions_script.register_all(self)

	var sentry_debug_actions_script: GDScript = load(
		"res://debug/actions/registrations/sentry_debug_actions.gd"
	)
	if sentry_debug_actions_script:
		sentry_debug_actions_script.register_all(self)

	var firebase_test_actions_script: GDScript = load(
		"res://debug/actions/registrations/firebase_test_actions.gd"
	)
	if firebase_test_actions_script:
		firebase_test_actions_script.register_all(self)


func register_action(action: DebugAction) -> bool:
	if not action:
		Log.error("Cannot register null action", {}, [Log.TAG_DEBUG, Log.TAG_ERROR])
		return false

	if action.action_name.is_empty():
		Log.error("Cannot register action with empty name", {}, [Log.TAG_DEBUG, Log.TAG_ERROR])
		return false

	if action.category.is_empty():
		action.category = "Uncategorized"

	if not _actions.has(action.category):
		_actions[action.category] = {}

	var group_name: String = action.group if not action.group.is_empty() else "_ungrouped"
	if not _actions[action.category].has(group_name):
		var new_array: Array[DebugAction] = []
		_actions[action.category][group_name] = new_array

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


func get_categories() -> Array[String]:
	return DictUtils.keys_typed_sorted(_actions, TYPE_STRING)


func get_groups_for_category(category_name: String) -> Array[String]:
	if not _actions.has(category_name):
		var empty_array: Array[String] = []
		return empty_array

	var category_dict: Dictionary = _actions[category_name]
	var groups: Array[String] = DictUtils.keys_typed_sorted(category_dict, TYPE_STRING)
	groups.erase("_ungrouped")
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


func find_actions_matching(pattern: String) -> Array[String]:
	"""
	Find all action names that match the given wildcard pattern.
	Supports basic glob patterns with * for any characters.

	Examples:
	- "cpp.*" -> matches "cpp.firebase.set_value", "cpp.firebase.get_value", etc.
	- "*.firebase.*" -> matches any action with 'firebase' in the middle
	- "*.*.error_handling" -> matches error handling actions across all layers
	- "exact_name" -> exact match (no wildcards)
	"""
	var matching_names: Array[String] = []

	var regex_pattern: String = _glob_to_regex(pattern)
	var regex: RegEx = RegEx.new()
	var compile_result: Error = regex.compile(regex_pattern)

	if compile_result != OK:
		Log.warning(
			"Invalid wildcard pattern",
			{"pattern": pattern, "regex": regex_pattern, "error": compile_result},
			[Log.TAG_DEBUG, Log.TAG_WILDCARD]
		)
		return matching_names

	for action: DebugAction in _flat_actions:
		var action_name: String = action.action_name
		if regex.search(action_name):
			matching_names.append(action_name)

	matching_names.sort()

	Log.debug(
		"Wildcard pattern match completed",
		{"pattern": pattern, "matches_found": matching_names.size(), "matches": matching_names},
		[Log.TAG_DEBUG, Log.TAG_WILDCARD]
	)

	return matching_names


func find_action_by_name(action_name: String) -> DebugAction:
	"""
	Find a single action by exact name.
	Returns null if not found.
	"""
	for action: DebugAction in _flat_actions:
		if action.action_name == action_name:
			return action

	return null


func _glob_to_regex(glob_pattern: String) -> String:
	"""
	Convert a simple glob pattern to a regex pattern.
	Currently supports:
	- * (asterisk) -> matches any characters (including none)
	- Literal characters are escaped
	"""
	var regex_pattern: String = ""

	var escaped: String = glob_pattern
	escaped = escaped.replace("\\", "\\\\")  # Escape backslashes first
	escaped = escaped.replace(".", "\\.")  # Escape dots
	escaped = escaped.replace("+", "\\+")  # Escape plus
	escaped = escaped.replace("?", "\\?")  # Escape question marks
	escaped = escaped.replace("^", "\\^")  # Escape carets
	escaped = escaped.replace("$", "\\$")  # Escape dollar signs
	escaped = escaped.replace("(", "\\(")  # Escape parentheses
	escaped = escaped.replace(")", "\\)")
	escaped = escaped.replace("[", "\\[")  # Escape brackets
	escaped = escaped.replace("]", "\\]")
	escaped = escaped.replace("{", "\\{")  # Escape braces
	escaped = escaped.replace("}", "\\}")
	escaped = escaped.replace("|", "\\|")  # Escape pipes

	escaped = escaped.replace("*", ".*")

	regex_pattern = "^" + escaped + "$"

	return regex_pattern
