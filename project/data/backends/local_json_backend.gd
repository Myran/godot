class_name LocalJSONBackend
extends DataBackend

## Local JSON backend for data retrieval from local JSON files.
## Handles file loading, parsing, and data access with JSONPathNavigator.
const DEFAULT_SHEETS_ID: String = "1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY"
# Suppress warning for the signal since it's required for the DataBackend interface
@warning_ignore("unused_signal")

# Loaded JSON data
var local_data: Dictionary = {}

# File paths (initialized from ProjectSettings)
#var default_db_file: String
var battle_db_file: String
var current_file: String

# Sheet ID for the main data structure


func _init(file_path: String = "") -> void:
	Log.info("LocalJSONBackend initializing", {
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])

	# Load file paths from project settings with fallbacks
	#default_db_file = _get_project_setting("gametwo/data/default_db_file", "res://resources/data.json")
	battle_db_file = _get_project_setting("gametwo/data/battle_db_file", "res://resources/gameone-577cb-export.json")

	if file_path.is_empty():
		current_file = battle_db_file
	else:
		current_file = file_path

	Log.debug("LocalJSONBackend file paths", {
		"battle_db_file": battle_db_file,
		"current_file": current_file,
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])

func initialize() -> bool:
	# Check if we should use the battle DB file

	current_file = battle_db_file
	Log.debug("Using battle database file", {"file": current_file}, [Log.TAG_LOCAL])

	var success: bool = _load_local_data()
	if success:
		call_deferred("emit_signal", "startup_completed")
	return success

func is_available() -> bool:
	return not local_data.is_empty()

func get_data(p_path: Array[Variant], p_key: String) -> Variant:
	if not is_available():
		Log.error("Local data not available", {"backend_id": get_instance_id()}, [Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR])
		return null

	Log.debug("Getting local data", {
		"path": p_path,
		"key": p_key,
		"call_stack": _get_simple_stack_trace(),
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])

	# Create navigation path with sheets handling
	var target_data: Variant = local_data
	var navigation_path: Array[Variant] = []

	# Get sheets ID from project settings or use default
	var sheets_id: String = _get_project_setting("gametwo/data/sheets_id", DEFAULT_SHEETS_ID)

	# Handle sheets path prefix consistently - no special cases, always use JSONPathNavigator
	if p_path.size() > 0 and p_path[0] is String and p_path[0] == "sheets":
		# First navigate to the sheets data
		var sheets_nav_result: NavigationResult = JSONPathNavigator.navigate(local_data, [sheets_id])

		if not sheets_nav_result.found:
			Log.error("Sheets data not found", {
				"sheets_id": sheets_id,
				"backend_id": get_instance_id(),
				"call_stack": _get_simple_stack_trace()
			}, [Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR])
			return null

		# Use the sheets data as the starting point
		target_data = sheets_nav_result.value

		# Skip the "sheets" part in the navigation path
		for i_idx: int in range(1, p_path.size()):
			navigation_path.append(p_path[i_idx])
	else:
		# Use the path as is for regular navigation
		navigation_path = p_path.duplicate()

	Log.debug("Navigating path with JSONPathNavigator", {
		"original_path": p_path,
		"navigation_path": navigation_path,
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])

	# Add key to path if provided
	var final_path: Array[Variant] = navigation_path.duplicate()
	if not p_key.is_empty():
		final_path.append(p_key)

	# Let JSONPathNavigator handle all navigation - always use the same pattern
	var nav_result: NavigationResult = JSONPathNavigator.navigate(target_data, final_path)

	if nav_result.found:
		var value_info: Dictionary = _get_value_info(nav_result.value)

		Log.info("Successfully navigated to data", {
			"path": p_path,
			"key": p_key,
			"value_info": value_info,
			"backend_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_LOCAL])

		call_deferred("emit_signal", "value_received", {"key": p_key, "value": nav_result.value})
		return nav_result.value
	else:
		Log.error("Failed to navigate to data", {
			"path": p_path,
			"key": p_key,
			"error": nav_result.error_message,
			"context": nav_result.context,
			"backend_id": get_instance_id(),
			"call_stack": _get_simple_stack_trace()
		}, [Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR])

		push_error("Data not found: path=" + str(p_path) + ", key=" + p_key +
			". Error: " + nav_result.error_message + ". Context: " + str(nav_result.context))
		return null

# Helper to get information about a value for logging
func _get_value_info(value: Variant) -> Dictionary:
	var info: Dictionary = {}
	info["type"] = typeof(value)

	if value is Array:
		info["size"] = value.size()
		info["is_array"] = true
	elif value is Dictionary:
		info["size"] = value.keys().size()
		info["is_dictionary"] = true
		info["sample_keys"] = value.keys().slice(0, min(5, value.keys().size()))
	else:
		info["is_value"] = true

	return info

## Helper to get a project setting with fallback
## @param setting_name The name of the project setting
## @param default_value The default value if setting doesn't exist
## @return The setting value or default value
func _get_project_setting(setting_name: String, default_value: Variant) -> Variant:
	if ProjectSettings.has_setting(setting_name):
		var setting_value: Variant = ProjectSettings.get_setting(setting_name)
		return setting_value
	return default_value

# Helper to get a simplified stack trace for debugging
func _get_simple_stack_trace() -> Array[Dictionary]:
	var stack: Array = get_stack()
	var simplified_stack: Array[Dictionary] = []

	for frame_info: Dictionary in stack:
		if frame_info.function != "_get_simple_stack_trace" and frame_info.function != "get_data":
			simplified_stack.append({
				"function": frame_info.function,
				"file": frame_info.source.get_file(),
				"line": frame_info.line
			})

			# Only show a few frames for brevity
			if simplified_stack.size() >= 3:
				break

	return simplified_stack

@warning_ignore("redundant_await")
func set_data(p_path: Array[Variant], p_key: String, _p_data: Variant) -> bool:
	Log.warning("LocalJSONBackend.set_data is read-only implementation", {"path": p_path, "key": p_key}, [Log.TAG_DB, Log.TAG_LOCAL])
	# For test environments, we might want to simulate write operations
	# But in production, local JSON is read-only
	return false

@warning_ignore("redundant_await")
func push_data(p_path: Array[Variant], _p_data: Variant) -> String:
	Log.warning("LocalJSONBackend.push_data is read-only implementation", {"path": p_path}, [Log.TAG_DB, Log.TAG_LOCAL])
	# Read-only implementation
	return "local-read-only-" + str(Time.get_unix_time_from_system())

@warning_ignore("redundant_await")
func remove_data(p_path: Array[Variant], p_key: String) -> bool:
	Log.warning("LocalJSONBackend.remove_data is read-only implementation", {"path": p_path, "key": p_key}, [Log.TAG_DB, Log.TAG_LOCAL])
	# Read-only implementation
	return false

func _load_local_data() -> bool:
	Log.info("Loading local data file", {"file": current_file, "backend_id": get_instance_id()}, [Log.TAG_LOCAL, Log.TAG_DB])

	if not FileAccess.file_exists(current_file):
		Log.error("Local data file does not exist", {"file": current_file, "backend_id": get_instance_id()}, [Log.TAG_LOCAL, Log.TAG_ERROR])
		return false

	var file: FileAccess = FileAccess.open(current_file, FileAccess.READ)
	if not file:
		var error_code: int = FileAccess.get_open_error()
		Log.error("Failed to open local data file", {
			"file": current_file,
			"error_code": error_code,
			"error_description": _get_file_error_string(error_code),
			"backend_id": get_instance_id()
		}, [Log.TAG_LOCAL, Log.TAG_ERROR])
		return false

	Log.debug("File opened successfully, reading content", {"file": current_file, "backend_id": get_instance_id()}, [Log.TAG_LOCAL])

	var json_text: String = file.get_as_text()
	var json_size: int = json_text.length()
	file.close()

	Log.debug("File read complete", {"file": current_file, "size_bytes": json_size, "backend_id": get_instance_id()}, [Log.TAG_LOCAL])

	var json_result: Variant = JSON.parse_string(json_text)
	if json_result == null:
		Log.error("Failed to parse local data JSON", {"file": current_file, "backend_id": get_instance_id()}, [Log.TAG_LOCAL, Log.TAG_ERROR])
		return false

	# Store the entire JSON result
	if json_result is Dictionary:
		local_data = json_result
	else:
		Log.error("JSON result is not a Dictionary", {"file": current_file, "result_type": typeof(json_result), "backend_id": get_instance_id()}, [Log.TAG_LOCAL, Log.TAG_ERROR])
		return false

	# Log extensive data structure info to help with debugging
	var top_level_keys: Array[Variant] = local_data.keys()
	Log.info("Local data file loaded successfully", {
		"file": current_file,
		"top_level_keys": top_level_keys,
		"key_count": top_level_keys.size(),
		"backend_id": get_instance_id()
	}, [Log.TAG_LOCAL, Log.TAG_DB])

	# Log more detailed structure information for debugging
	if top_level_keys.size() > 0:
		var structure_info: Dictionary = {}
		for key_name: Variant in top_level_keys:
			if key_name is String:
				var value_item: Variant = local_data[key_name]
				if value_item is Dictionary:
					var dict_keys: Array = value_item.keys()
					var max_keys: int = min(5, dict_keys.size())
					structure_info[key_name] = {
						"type": "Dictionary",
						"size": dict_keys.size(),
						"keys": dict_keys.slice(0, max_keys) # Show first 5 keys
					}
				elif value_item is Array:
					var array_value: Array = value_item
					structure_info[key_name] = {
						"type": "Array",
						"size": array_value.size()
					}
					# Avoid using ternary operator to prevent INCOMPATIBLE_TERNARY error
					if array_value.size() > 0:
						structure_info[key_name]["sample"] = _get_value_type_info(array_value[0])
					else:
						structure_info[key_name]["sample"] = "empty"
				else:
					structure_info[key_name] = {
						"type": typeof(value_item)
					}

		Log.debug("Data structure details", {"structure": structure_info, "backend_id": get_instance_id()}, [Log.TAG_LOCAL, Log.TAG_DB])

	return true

# Helper to get readable error messages
func _get_file_error_string(error_code: int) -> String:
	match error_code:
		ERR_FILE_NOT_FOUND: return "File not found"
		ERR_FILE_BAD_DRIVE: return "Bad drive"
		ERR_FILE_BAD_PATH: return "Bad path"
		ERR_FILE_NO_PERMISSION: return "No permission"
		ERR_FILE_ALREADY_IN_USE: return "File already in use"
		ERR_FILE_CANT_OPEN: return "Can't open file"
		ERR_FILE_CANT_WRITE: return "Can't write to file"
		ERR_FILE_CANT_READ: return "Can't read from file"
		ERR_FILE_UNRECOGNIZED: return "Unrecognized file"
		ERR_FILE_CORRUPT: return "Corrupt file"
		ERR_FILE_MISSING_DEPENDENCIES: return "Missing dependencies"
		ERR_FILE_EOF: return "End of file"
		_: return "Unknown error " + str(error_code)

# Helper to get type info for a value
func _get_value_type_info(p_value: Variant) -> Dictionary:
	if p_value is Dictionary:
		return {"type": "Dictionary", "keys": p_value.keys()}
	elif p_value is Array:
		return {"type": "Array", "size": p_value.size()}
	else:
		return {"type": typeof(p_value)}
