# project/debug/debug_action_registry.gd
extends Node

var actions: Array[DebugAction] = []
const ACTIONS_PATH = "res://debug/actions/"  # Directory to scan for actions


# This must be called to initialize the registry when loaded as a autoload
func _init():
	# Don't use Log here as it might not be initialized yet
	print("DebugActionRegistry instance created")

func _ready():
	# Now Log should be available
	Log.info("DebugActionRegistry initializing...", {}, ["debug", "system"])

	# Check if actions directory exists
	var dir = DirAccess.open(ACTIONS_PATH)
	if not dir:
		var err = DirAccess.get_open_error()
		Log.error("DebugActionRegistry: Actions directory not found: " + ACTIONS_PATH,
			{"error_code": err}, ["debug", "system"])

		# Create the directory if it doesn't exist
		DirAccess.make_dir_recursive_absolute(ACTIONS_PATH)
		Log.info("Created actions directory: " + ACTIONS_PATH, {}, ["debug", "system"])

		# Continue with scanning - it will just find no actions but won't crash

	_scan_for_actions()


func _scan_for_actions() -> void:
	actions.clear()

	# Try both scanning approach and hardcoded fallback for mobile compatibility
	_recursive_scan(ACTIONS_PATH)

	# Mobile fallback: directly load known resource files
	if actions.is_empty():
		Log.info("No actions found via directory scan, trying direct resource loading...", {}, ["debug", "system"])
		_load_known_actions()

	# Ultimate fallback: programmatic registration
	if actions.is_empty():
		Log.info("No actions found via resource loading, using programmatic registration...", {}, ["debug", "system"])
		_register_all_actions_programmatically()

	actions.sort_custom(func(a, b): return a.action_name < b.action_name)  # Sort alphabetically
	Log.info(
		"DebugActionRegistry: Scanned and loaded %d actions." % actions.size(),
		{},
		["debug", "system"]
	)


func _load_known_actions() -> void:
	# Direct loading of known action resources for mobile compatibility
	var known_action_paths: Array[String] = [
		"res://debug/actions/core/log_system_info.tres",
		"res://debug/actions/rtdb/rtdb_set_simple_value.tres"
	]

	for action_path in known_action_paths:
		if ResourceLoader.exists(action_path):
			var resource = load(action_path)
			if resource is DebugAction:
				actions.append(resource)
				Log.debug("Loaded action: " + resource.action_name, {}, ["debug", "system"])
			else:
				Log.warning("Resource at " + action_path + " is not a DebugAction", {}, ["debug", "system"])
		else:
			Log.warning("Action resource not found: " + action_path, {}, ["debug", "system"])


func _recursive_scan(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue

			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				_recursive_scan(full_path)
			elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
				if ResourceLoader.exists(full_path):
					var resource = load(full_path)
					if resource is DebugAction:
						actions.append(resource)
						Log.debug("Scanned action: " + resource.action_name, {}, ["debug", "system"])
				else:
					Log.warning("Resource file not accessible: " + full_path, {}, ["debug", "system"])
			file_name = dir.get_next()
	else:
		Log.warning(
			"DebugActionRegistry: Could not open directory for scanning: " + path + " (this is normal on some platforms)",
			{},
			["debug", "system"]
		)


func get_actions() -> Array[DebugAction]:
	return actions


# These getter methods must be available for the debug menu to function
func get_categories() -> Array[String]:
	# First make sure the registry is initialized
	if actions.is_empty() and not Engine.is_editor_hint():
		_scan_for_actions()

	var cats = {}
	for action in actions:
		if action and action.get("category"):
			cats[action.category] = true
	var sorted_cats : Array [String]
	sorted_cats.assign(cats.keys())
	sorted_cats.sort()
	return sorted_cats


func get_groups_for_category(category_name: String) -> Array[String]:
	var groups = {}
	for action in actions:
		if action.category == category_name:
			groups[action.group] = true
	var sorted_groups: Array[String]
	sorted_groups.assign(groups.keys())

	sorted_groups.sort()

	return sorted_groups


func get_actions_for_group(category_name: String, group_name: String) -> Array[DebugAction]:
	var group_actions: Array[DebugAction] = []
	for action in actions:
		if action.category == category_name and action.group == group_name:
			group_actions.append(action)
	# Actions are already sorted by name globally, so they should be sorted within the group.
	return group_actions


# Manual registration method for guaranteed cross-platform compatibility
func register_action(action: DebugAction) -> void:
	if action and not actions.has(action):
		actions.append(action)
		Log.debug("Manually registered action: " + action.action_name, {}, ["debug", "system"])


# Alternative approach: Register all actions programmatically
func _register_all_actions_programmatically() -> void:
	# This method can be called as a fallback if resource loading fails
	# Create actions directly in code instead of loading from .tres files

	# System Info Action
	var system_info_action = LogSystemInfoAction.new()
	register_action(system_info_action)

	# RTDB Action
	var rtdb_action = RTDBSetSimpleValueAction.new()
	register_action(rtdb_action)

	Log.info("Registered actions programmatically as fallback", {}, ["debug", "system"])
