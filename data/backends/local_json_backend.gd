class_name LocalJSONBackend
extends DataBackend

## Local JSON backend for data retrieval from local JSON files.
## Handles file loading, parsing, and data access with JSONPathNavigator.

# Loaded JSON data
var local_data: Dictionary = {}

# File paths (initialized from ProjectSettings)
var default_db_file: String
var battle_db_file: String
var current_file: String

# Sheet ID for the main data structure
const DEFAULT_SHEETS_ID: String = "1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY"

func _init(file_path: String = "") -> void:
	Log.info("LocalJSONBackend initializing", {
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])
	
	# Load file paths from project settings with fallbacks
	default_db_file = _get_project_setting("gametwo/data/default_db_file", "res://resources/data.json")
	battle_db_file = _get_project_setting("gametwo/data/battle_db_file", "res://resources/gameone-577cb-export.json")
	
	if file_path.is_empty():
		current_file = default_db_file
	else:
		current_file = file_path
		
	Log.debug("LocalJSONBackend file paths", {
		"default_db_file": default_db_file,
		"battle_db_file": battle_db_file,
		"current_file": current_file,
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])

func initialize() -> bool:
	# Check if we should use the battle DB file
	var debug_node = Engine.get_singleton("Debug")
	if debug_node and debug_node.use_local_battle_db:
		current_file = battle_db_file
		Log.debug("Using battle database file", {"file": current_file}, [Log.TAG_LOCAL])
	
	var success = _load_local_data()
	if success:
		call_deferred("emit_signal", "startup_completed")
	return success
	
func is_available() -> bool:
	return not local_data.is_empty()
	
func get_data(path: Array, key: String) -> Variant:
	if not is_available():
		Log.error("Local data not available", {"backend_id": get_instance_id()}, [Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR])
		return null
		
	Log.debug("Getting local data", {
		"path": path, 
		"key": key, 
		"call_stack": _get_simple_stack_trace(),
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])
	
	# Special handling for our specific JSON structure
	# The structure is: {"1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY": {...}}
	# Where SHEETS is the key in the JSON structure
	
	# Get sheets ID from project settings or use default
	var sheets_id: String = _get_project_setting("gametwo/data/sheets_id", DEFAULT_SHEETS_ID)
	
	# Handle special case for sheets directly
	var sheets_data: Dictionary = {}
	if local_data.has(sheets_id):
		sheets_data = local_data[sheets_id]
		
		Log.debug("Found sheets ID in data", {
			"sheets_id": sheets_id,
			"backend_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_LOCAL])
		
		# Special case: direct key lookup in sheets data
		if sheets_data.has(key):
			var result: Variant = sheets_data[key]
			var result_info: Dictionary = _get_value_info(result)
			
			Log.info("Found key directly in sheets data", {
				"key": key,
				"result_info": result_info,
				"backend_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_LOCAL])
			
			call_deferred("emit_signal", "value_received", {"key": key, "value": result})
			return result
	
	# Use JSONPathNavigator for reliable path navigation
	var navigation_path: Array = []
	var target_data: Variant = local_data
	
	# Handle special case for sheets path
	if path.size() > 0 and path[0] == "sheets":
		# If the path starts with "sheets", use the sheets data as the base
		var sheets_id: String = _get_project_setting("gametwo/data/sheets_id", DEFAULT_SHEETS_ID)
		if local_data.has(sheets_id):
			target_data = local_data[sheets_id]
			# Skip the "sheets" part in the navigation path
			navigation_path = path.slice(1, path.size())
		else:
			Log.error("Sheets data not found", {
				"sheets_id": sheets_id,
				"backend_id": get_instance_id(), 
				"call_stack": _get_simple_stack_trace()
			}, [Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR])
			return null
	else:
		# Use the path as is for regular navigation
		navigation_path = path.duplicate()
	
	Log.debug("Navigating path with JSONPathNavigator", {
		"original_path": path,
		"navigation_path": navigation_path,
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])
	
	var result: NavigationResult
	
	if key.is_empty():
		# If key is empty, navigate to the path and return the data at that location
		result = JSONPathNavigator.navigate(target_data, navigation_path)
	else:
		# If a key is specified, navigate to the path and then look for the key
		var full_path: Array = navigation_path.duplicate()
		full_path.append(key)
		result = JSONPathNavigator.navigate(target_data, full_path)
	
	if result.found:
		var value_info: Dictionary = _get_value_info(result.value)
		
		Log.info("Successfully navigated to data", {
			"path": path,
			"key": key,
			"value_info": value_info,
			"backend_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_LOCAL])
		
		call_deferred("emit_signal", "value_received", {"key": key, "value": result.value})
		return result.value
	else:
		Log.error("Failed to navigate to data", {
			"path": path,
			"key": key,
			"error": result.error_message,
			"context": result.context,
			"backend_id": get_instance_id(),
			"call_stack": _get_simple_stack_trace()
		}, [Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR])
		
		push_error("Data not found: path=" + str(path) + ", key=" + key + 
			". Error: " + result.error_message + ". Context: " + str(result.context))
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
		return ProjectSettings.get_setting(setting_name)
	return default_value
	
# Helper to get a simplified stack trace for debugging
func _get_simple_stack_trace() -> Array:
	var stack: Array = get_stack()
	var simplified_stack: Array = []
	
	for frame in stack:
		if frame.function != "_get_simple_stack_trace" and frame.function != "get_data":
			simplified_stack.append({
				"function": frame.function,
				"file": frame.source.get_file(),
				"line": frame.line
			})
			
			# Only show a few frames for brevity
			if simplified_stack.size() >= 3:
				break
	
	return simplified_stack
	
func set_data(path: Array, key: String, data: Variant) -> bool:
	Log.warning("LocalJSONBackend.set_data is read-only implementation", {"path": path, "key": key}, [Log.TAG_DB, Log.TAG_LOCAL])
	# For test environments, we might want to simulate write operations
	# But in production, local JSON is read-only
	return false
	
func push_data(path: Array, data: Variant) -> String:
	Log.warning("LocalJSONBackend.push_data is read-only implementation", {"path": path}, [Log.TAG_DB, Log.TAG_LOCAL])
	# Read-only implementation
	return "local-read-only-" + str(Time.get_unix_time_from_system())
	
func remove_data(path: Array, key: String) -> bool:
	Log.warning("LocalJSONBackend.remove_data is read-only implementation", {"path": path, "key": key}, [Log.TAG_DB, Log.TAG_LOCAL])
	# Read-only implementation
	return false
	
func _load_local_data() -> bool:
	Log.info("Loading local data file", {"file": current_file, "backend_id": get_instance_id()}, [Log.TAG_LOCAL, Log.TAG_DB])
	
	if not FileAccess.file_exists(current_file):
		Log.error("Local data file does not exist", {"file": current_file, "backend_id": get_instance_id()}, [Log.TAG_LOCAL, Log.TAG_ERROR])
		return false
		
	var file = FileAccess.open(current_file, FileAccess.READ)
	if not file:
		var error_code = FileAccess.get_open_error()
		Log.error("Failed to open local data file", {
			"file": current_file, 
			"error_code": error_code, 
			"error_description": _get_file_error_string(error_code),
			"backend_id": get_instance_id()
		}, [Log.TAG_LOCAL, Log.TAG_ERROR])
		return false
		
	Log.debug("File opened successfully, reading content", {"file": current_file, "backend_id": get_instance_id()}, [Log.TAG_LOCAL])
	
	var json_text = file.get_as_text()
	var json_size = json_text.length()
	file.close()
	
	Log.debug("File read complete", {"file": current_file, "size_bytes": json_size, "backend_id": get_instance_id()}, [Log.TAG_LOCAL])
	
	var json_result = JSON.parse_string(json_text)
	if json_result == null:
		Log.error("Failed to parse local data JSON", {"file": current_file, "backend_id": get_instance_id()}, [Log.TAG_LOCAL, Log.TAG_ERROR])
		return false
	
	# Store the entire JSON result
	local_data = json_result
	
	# Log extensive data structure info to help with debugging
	var top_level_keys = local_data.keys()
	Log.info("Local data file loaded successfully", {
		"file": current_file, 
		"top_level_keys": top_level_keys,
		"key_count": top_level_keys.size(),
		"backend_id": get_instance_id()
	}, [Log.TAG_LOCAL, Log.TAG_DB])
	
	# Log more detailed structure information for debugging
	if top_level_keys.size() > 0:
		var structure_info = {}
		for key in top_level_keys:
			var value = local_data[key]
			if value is Dictionary:
				structure_info[key] = {
					"type": "Dictionary", 
					"size": value.keys().size(),
					"keys": value.keys().slice(0, min(5, value.keys().size())) # Show first 5 keys
				}
			elif value is Array:
				structure_info[key] = {
					"type": "Array", 
					"size": value.size(),
					"sample": _get_value_type_info(value[0]) if value.size() > 0 else "empty"
				}
			else:
				structure_info[key] = {
					"type": typeof(value)
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
func _get_value_type_info(value) -> Dictionary:
	if value is Dictionary:
		return {"type": "Dictionary", "keys": value.keys()}
	elif value is Array:
		return {"type": "Array", "size": value.size()}
	else:
		return {"type": typeof(value)}
