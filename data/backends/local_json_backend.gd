class_name LocalJSONBackend
extends DataBackend

var local_data: Dictionary = {}
var default_db_file: String = "res://resources/data.json"
var battle_db_file: String = "res://resources/gameone-577cb-export.json"
var current_file: String

func _init(file_path: String = ""):
	Log.info("LocalJSONBackend initializing", {}, [Log.TAG_DB, Log.TAG_LOCAL])
	if file_path.is_empty():
		current_file = default_db_file
	else:
		current_file = file_path

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
	# Where SHEETS is the key "1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY"
	
	# First, check if the first level has the sheets ID
	const SHEETS_ID = "1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY"
	var has_sheets = local_data.has(SHEETS_ID)
	
	Log.debug("Checking for sheets ID", {
		"sheets_id": SHEETS_ID, 
		"has_sheets": has_sheets,
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])
	
	if has_sheets:
		var sheets_data = local_data[SHEETS_ID]
		var sheets_keys = sheets_data.keys()
		
		# Check if the key exists directly in sheets_data
		var key_in_sheets = sheets_data.has(key)
		
		Log.debug("Sheets data info", {
			"key": key, 
			"key_in_sheets": key_in_sheets, 
			"sheets_key_count": sheets_keys.size(),
			"sample_keys": sheets_keys.slice(0, min(5, sheets_keys.size())),
			"backend_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_LOCAL])
		
		if key_in_sheets:
			var result = sheets_data[key]
			var result_type = typeof(result)
			var result_size = result.size() if result is Array else result.keys().size() if result is Dictionary else 0
			
			Log.info("Found key in sheets data", {
				"key": key, 
				"result_type": result_type, 
				"result_size": result_size,
				"backend_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_LOCAL])
			
			call_deferred("emit_signal", "value_received", {"key": key, "value": result})
			return result
		
		# If we're looking for sheets path and we have the sheets data
		if path.size() > 0 and path[0] == "sheets":
			# Error out with clear message about the expected key
			Log.error("Required key missing in sheets data", {
				"key": key, 
				"path": path, 
				"available_keys": sheets_keys.slice(0, min(10, sheets_keys.size())), # Show up to 10 keys
				"total_keys": sheets_keys.size(),
				"backend_id": get_instance_id(),
				"call_stack": _get_simple_stack_trace()
			}, [Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR])
			
			push_error("Required data missing in sheets: " + key + ". Available keys: " + str(sheets_keys.slice(0, min(10, sheets_keys.size()))))
			return null
	
	# Navigate through the path (backward compatibility)
	Log.debug("Beginning path navigation", {
		"path": path, 
		"key": key,
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])
	
	var current_data = local_data
	var navigation_history = []
	
	for i in range(path.size()):
		var path_part = path[i]
		navigation_history.append(path_part)
		
		var path_exists = current_data.has(path_part)
		var sheets_special_case = path_part == "sheets" and current_data.has(SHEETS_ID)
		
		Log.debug("Navigating path part", {
			"path_part": path_part, 
			"path_index": i,
			"path_exists": path_exists,
			"sheets_special_case": sheets_special_case,
			"navigation_history": navigation_history,
			"backend_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_LOCAL])
		
		if path_exists:
			current_data = current_data[path_part]
		elif sheets_special_case:
			# Special case: if path_part is "sheets", use the sheets ID
			Log.debug("Using special case for sheets path", {
				"sheets_id": SHEETS_ID,
				"backend_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_LOCAL])
			current_data = current_data[SHEETS_ID]
		else:
			# Error out with clear info about available keys
			var available_keys = []
			if current_data is Dictionary:
				available_keys = current_data.keys()
				
			Log.error("Path part not found in data", {
				"path": path, 
				"navigation_history": navigation_history,
				"current_path_part": path_part, 
				"available_keys": available_keys.slice(0, min(10, available_keys.size())),
				"total_keys": available_keys.size(),
				"backend_id": get_instance_id(),
				"call_stack": _get_simple_stack_trace()
			}, [Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR])
			
			push_error("Required path missing: " + path_part + " at index " + str(i) + 
				". Available keys: " + str(available_keys.slice(0, min(10, available_keys.size()))))
			return null
	
	Log.debug("Path navigation complete", {
		"path": path, 
		"reached_data_type": typeof(current_data),
		"is_dictionary": current_data is Dictionary,
		"is_array": current_data is Array,
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])
	
	# Once we've navigated to the right place, check for the key
	if key.is_empty():
		Log.info("Empty key requested, returning entire data at path", {
			"path": path,
			"data_type": typeof(current_data),
			"data_size": current_data.size() if current_data is Array else 
						current_data.keys().size() if current_data is Dictionary else 0,
			"backend_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_LOCAL])
		
		call_deferred("emit_signal", "value_received", {"key": key, "value": current_data})
		return current_data
	
	var has_key = current_data.has(key)
	
	Log.debug("Checking for key in current data", {
		"key": key,
		"has_key": has_key,
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])
	
	if has_key:
		var result = current_data[key]
		var result_type = typeof(result)
		var result_size = result.size() if result is Array else result.keys().size() if result is Dictionary else 0
		
		Log.info("Found key in current data", {
			"key": key,
			"path": path,
			"result_type": result_type,
			"result_size": result_size,
			"backend_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_LOCAL])
		
		call_deferred("emit_signal", "value_received", {"key": key, "value": result})
		return result
	
	# If key wasn't found, provide detailed error
	var available_keys = []
	if current_data is Dictionary:
		available_keys = current_data.keys()
		
	Log.error("Key not found after navigating path", {
		"path": path, 
		"key": key, 
		"available_keys": available_keys.slice(0, min(10, available_keys.size())),
		"total_keys": available_keys.size(),
		"backend_id": get_instance_id(),
		"call_stack": _get_simple_stack_trace()
	}, [Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR])
	
	push_error("Required key missing: " + key + " at path " + str(path) + 
		". Available keys: " + str(available_keys.slice(0, min(10, available_keys.size()))))
	return null
	
# Helper to get a simplified stack trace for debugging
func _get_simple_stack_trace() -> Array:
	var stack = get_stack()
	var simplified_stack = []
	
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
