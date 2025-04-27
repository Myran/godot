class_name LocalJSONBackend
extends DataBackend

# Import class references directly
const JSONPathNavigatorClass = preload("res://data/backends/json_path_navigator.gd") 
const NavigationResultClass = preload("res://data/backends/navigation_result.gd")

var local_data: Dictionary = {}
var default_db_file: String = "res://resources/data.json"
var battle_db_file: String = "res://resources/gameone-577cb-export.json"
var current_file: String = ""

func _init(file_path: String = "") -> void:
	Log.info("LocalJSONBackend initializing", {}, [Log.TAG_DB, Log.TAG_LOCAL])
	if file_path.is_empty():
		current_file = default_db_file
	else:
		current_file = file_path

func initialize() -> bool:
	# Check if we should use the battle DB file
	var debug_node: Node = debug
	if debug_node and debug_node.use_local_battle_db:
		current_file = battle_db_file
		Log.debug("Using battle database file", {"file": current_file}, [Log.TAG_LOCAL])

	var success: bool = _load_local_data()
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

	# Use JSONPathNavigator for robust JSON structure handling
	
	# Special handling for our specific JSON structure
	# The structure is: {"1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY": {...}}
	
	# Define the sheets ID as a constant
	const SHEETS_ID: String = "1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY"
	var has_sheets: bool = local_data.has(SHEETS_ID)

	Log.debug("Checking for sheets ID", {
		"sheets_id": SHEETS_ID,
		"has_sheets": has_sheets,
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])

	# Determine the proper navigation path based on the input path and key
	var navigation_path: Array = []
	
	# Special case: If the path starts with "sheets", we need to use the SHEETS_ID
	if path.size() > 0 and path[0] == "sheets":
		# Start with the sheets ID
		navigation_path.append(SHEETS_ID)
		
		# Add the rest of the path (skipping the first "sheets" element)
		for i in range(1, path.size()):
			navigation_path.append(path[i])
	else:
		# For other paths, use them directly
		navigation_path = path.duplicate()
	
	Log.debug("Prepared navigation path", {
		"original_path": path,
		"navigation_path": navigation_path,
		"key": key,
		"backend_id": get_instance_id()
	}, [Log.TAG_DB, Log.TAG_LOCAL])
	
	# Use JSONPathNavigator to navigate to the path
	var result: NavigationResult
	
	if navigation_path.is_empty():
		# Special case for empty path
		if key.is_empty():
			# Return the entire data
			result = NavigationResult.new_dictionary(local_data, [])
		elif key == SHEETS_ID:
			# Direct lookup for the SHEETS_ID at root level
			if local_data.has(SHEETS_ID):
				result = NavigationResult.new_dictionary(local_data[SHEETS_ID], [SHEETS_ID])
			else:
				result = NavigationResult.new_not_found("SHEETS_ID not found at root level", [SHEETS_ID])
		else:
			# Direct lookup for any other key at root level
			result = JSONPathNavigator.navigate(local_data, [key])
	else:
		# First navigate to the specified path
		var path_result = JSONPathNavigator.navigate(local_data, navigation_path)
		
		if not path_result.found:
			Log.error("Path navigation failed", {
				"path": navigation_path,
				"error": path_result.error_message,
				"context": path_result.context,
				"backend_id": get_instance_id()
			}, [Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR])
			return null
			
		# If key is empty, return the data at the path
		if key.is_empty():
			result = path_result
		else:
			# Otherwise, check if we can lookup the key in the path result
			if path_result.is_dictionary():
				var dict_data = path_result.as_dictionary()
				if dict_data.has(key):
					var value = dict_data[key]
					
					# Create appropriate result type based on the value
					if value is Dictionary:
						result = NavigationResult.new_dictionary(value, navigation_path + [key])
					elif value is Array:
						result = NavigationResult.new_array(value, navigation_path + [key])
					else:
						result = NavigationResult.new_value(value, navigation_path + [key])
				else:
					# Key not found in dictionary
					result = NavigationResult.new_not_found(
						"Key not found in dictionary at path",
						navigation_path + [key],
						{
							"available_keys": dict_data.keys().slice(0, min(10, dict_data.keys().size())),
							"total_keys": dict_data.keys().size()
						}
					)
			else:
				# Not a dictionary, can't lookup the key
				result = NavigationResult.new_not_found(
					"Cannot lookup key in non-dictionary result at path",
					navigation_path,
					{"result_type": path_result.result_type}
				)

	# Process the navigation result
	if result.found:
		Log.info("Data found using JSONPathNavigator", {
			"path": path,
			"key": key,
			"result_type": result.result_type,
			"backend_id": get_instance_id()
		}, [Log.TAG_DB, Log.TAG_LOCAL])
		
		var value = result.value
		
		# For backward compatibility, emit the value_received signal
		call_deferred("emit_signal", "value_received", {"key": key, "value": value})
		
		return value
	else:
		# Log detailed error information for debugging
		Log.error("Data not found using JSONPathNavigator", {
			"path": path,
			"key": key,
			"error": result.error_message,
			"context": result.context,
			"backend_id": get_instance_id(),
			"call_stack": _get_simple_stack_trace()
		}, [Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR])
		
		return null

	# End of get_data implementation

# Helper to get a simplified stack trace for debugging
func _get_simple_stack_trace() -> Array:
	var stack: Array = get_stack()
	var simplified_stack: Array = []

	for frame: Dictionary in stack:
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

func set_data(path: Array, key: String, _data: Variant) -> bool:
	Log.warning("LocalJSONBackend.set_data is read-only implementation", {"path": path, "key": key}, [Log.TAG_DB, Log.TAG_LOCAL])
	# For test environments, we might want to simulate write operations
	# But in production, local JSON is read-only
	return false

func push_data(path: Array, _data: Variant) -> String:
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
	local_data = json_result

	# Log extensive data structure info to help with debugging
	var top_level_keys: Array = local_data.keys()
	Log.info("Local data file loaded successfully", {
		"file": current_file,
		"top_level_keys": top_level_keys,
		"key_count": top_level_keys.size(),
		"backend_id": get_instance_id()
	}, [Log.TAG_LOCAL, Log.TAG_DB])

	# Log more detailed structure information for debugging
	if top_level_keys.size() > 0:
		var structure_info: Dictionary = {}
		for structure_key: String in top_level_keys:
			var value: Variant = local_data[structure_key]
			if value is Dictionary:
				# Calculate slice end without complex type conversions
				var key_slice_end = 5
				if value.keys().size() < 5:
					key_slice_end = value.keys().size()

				structure_info[structure_key] = {
					"type": "Dictionary",
					"size": value.keys().size(),
					"keys": value.keys().slice(0, key_slice_end) # Show first 5 keys
				}
			elif value is Array:
				structure_info[structure_key] = {
					"type": "Array",
					"size": value.size(),
					# Avoid ternary by using explicit conditional
					"sample": get_array_sample_info(value)
				}
			else:
				structure_info[structure_key] = {
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

# Helper to get sample info from an array without using ternary operators
func get_array_sample_info(array_value: Array) -> Dictionary:
	if array_value.size() > 0:
		return _get_value_type_info(array_value[0])
	else:
		return {"type": "empty"}

# Helper to get type info for a value
func _get_value_type_info(value: Variant) -> Dictionary:
	if value is Dictionary:
		return {"type": "Dictionary", "keys": value.keys()}
	elif value is Array:
		return {"type": "Array", "size": value.size()}
	else:
		return {"type": typeof(value)}
