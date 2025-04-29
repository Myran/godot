class_name JSONPathNavigator
extends RefCounted

## A utility class for safely navigating nested JSON structures.
## Provides consistent error handling and type safety.

## Navigate a JSON structure using a path array.
## @param json_data The JSON structure to navigate (can be Dictionary or Array)
## @param path Array of path components to navigate through
## @param _default_value Optional default value to return if path is not found (unused)
## @return NavigationResult object containing the result
static func navigate(json_data: Variant, path: Array, _default_value: Variant = null) -> NavigationResult:
	if json_data == null:
		return NavigationResult.new_not_found("JSON data is null", path)
		
	var current_data: Variant = json_data
	var current_path: Array = []
	
	for i: int in range(path.size()):
		var path_part: Variant = path[i]
		current_path.append(path_part)
		
		# Handle different container types
		if current_data is Dictionary:
			if current_data.has(path_part):
				current_data = current_data[path_part]
			else:
				return NavigationResult.new_not_found(
					"Path part not found in dictionary",
					current_path,
					_get_available_keys(current_data as Dictionary)
				)
		elif current_data is Array:
			# If path_part is an integer or can be converted to an integer
			var index: int = -1
			if path_part is int:
				index = path_part
			elif path_part is String and path_part.is_valid_int():
				index = path_part.to_int()
				
			if index >= 0 and index < current_data.size():
				current_data = current_data[index]
			else:
				return NavigationResult.new_not_found(
					"Array index out of bounds or not a valid index",
					current_path,
					{"array_size": current_data.size(), "requested_index": path_part}
				)
		else:
			# We've reached a leaf node before the end of the path
			return NavigationResult.new_not_found(
				"Cannot navigate further: reached a leaf node",
				current_path,
				{"node_type": typeof(current_data)}
			)
	
	# Successfully navigated the entire path
	return _create_result_for_type(current_data, path)

## Create a NavigationResult based on the type of data found
## @param data The data to wrap in a NavigationResult
## @param path The path that was navigated
## @return NavigationResult object with appropriate type
static func _create_result_for_type(data: Variant, path: Array) -> NavigationResult:
	if data is Dictionary:
		return NavigationResult.new_dictionary(data as Dictionary, path)
	elif data is Array:
		return NavigationResult.new_array(data as Array, path)
	else:
		return NavigationResult.new_value(data, path)

## Get a formatted list of available keys from a dictionary
## @param data Dictionary to extract keys from
## @return Dictionary with key information for error reporting
static func _get_available_keys(data: Dictionary) -> Dictionary:
	var available_keys: Array = data.keys()
	return {
		"available_keys": available_keys.slice(0, min(10, available_keys.size()) as int),
		"total_keys": available_keys.size()
	}

## Get a value by navigating a path, returning a default if not found
## @param json_data The JSON structure to navigate
## @param path Array of path components to navigate through
## @param default_value Value to return if path is not found
## @return The found value or the default value
static func get_value(json_data: Variant, path: Array, default_value: Variant = null) -> Variant:
	var result: NavigationResult = navigate(json_data, path)
	if result.found:
		return result.value
	return default_value

## Check if a path exists in the JSON structure
## @param json_data The JSON structure to navigate
## @param path Array of path components to check
## @return True if the path exists, false otherwise
static func path_exists(json_data: Variant, path: Array) -> bool:
	return navigate(json_data, path).found

## Get a dictionary at the specified path
## @param json_data The JSON structure to navigate
## @param path Array of path components to navigate through
## @param default_dict Dictionary to return if path is not found or not a dictionary
## @return Dictionary at the specified path or default dictionary
static func get_dictionary(json_data: Variant, path: Array, default_dict: Dictionary = {}) -> Dictionary:
	var result: NavigationResult = navigate(json_data, path)
	if result.found and result.is_dictionary():
		return result.as_dictionary()
	return default_dict

## Get an array at the specified path
## @param json_data The JSON structure to navigate
## @param path Array of path components to navigate through
## @param default_array Array to return if path is not found or not an array
## @return Array at the specified path or default array
static func get_array(json_data: Variant, path: Array, default_array: Array = []) -> Array:
	var result: NavigationResult = navigate(json_data, path)
	if result.found and result.is_array():
		return result.as_array()
	return default_array

## Get a string at the specified path
## @param json_data The JSON structure to navigate
## @param path Array of path components to navigate through
## @param default_str String to return if path is not found or not a string
## @return String at the specified path or default string
static func get_string(json_data: Variant, path: Array, default_str: String = "") -> String:
	var result: NavigationResult = navigate(json_data, path)
	if result.found:
		if result.value is String:
			return result.value as String
		else:
			# Try to convert to string if possible
			return str(result.value)
	return default_str

## Get an integer at the specified path
## @param json_data The JSON structure to navigate
## @param path Array of path components to navigate through
## @param default_int Integer to return if path is not found or not an integer
## @return Integer at the specified path or default integer
static func get_int(json_data: Variant, path: Array, default_int: int = 0) -> int:
	var result: NavigationResult = navigate(json_data, path)
	if result.found:
		if result.value is int:
			return result.value as int
		elif result.value is float:
			return int(result.value as float)
		elif result.value is String and (result.value as String).is_valid_int():
			return (result.value as String).to_int()
	return default_int

## Get a float at the specified path
## @param json_data The JSON structure to navigate
## @param path Array of path components to navigate through
## @param default_float Float to return if path is not found or not a float
## @return Float at the specified path or default float
static func get_float(json_data: Variant, path: Array, default_float: float = 0.0) -> float:
	var result: NavigationResult = navigate(json_data, path)
	if result.found:
		if result.value is float:
			return result.value as float
		elif result.value is int:
			return float(result.value as int)
		elif result.value is String and (result.value as String).is_valid_float():
			return (result.value as String).to_float()
	return default_float

## Get a boolean at the specified path
## @param json_data The JSON structure to navigate
## @param path Array of path components to navigate through
## @param default_bool Boolean to return if path is not found or not a boolean
## @return Boolean at the specified path or default boolean
static func get_bool(json_data: Variant, path: Array, default_bool: bool = false) -> bool:
	var result: NavigationResult = navigate(json_data, path)
	if result.found:
		if result.value is bool:
			return result.value as bool
		elif result.value is int:
			return (result.value as int) != 0
		elif result.value is String:
			var lower_str: String = (result.value as String).to_lower()
			if lower_str == "true" or lower_str == "yes" or lower_str == "1":
				return true
			elif lower_str == "false" or lower_str == "no" or lower_str == "0":
				return false
	return default_bool
