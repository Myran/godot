class_name JSONPathNavigator
extends RefCounted


static func navigate(
	json_data: Variant, path: Array, _default_value: Variant = null
) -> NavigationResult:
	if json_data == null:
		return NavigationResult.new_not_found("JSON data is null", path)

	var current_data: Variant = json_data
	var current_path: Array[Variant] = []

	for i: int in range(path.size()):
		var path_part: Variant = path[i]
		current_path.append(path_part)

		if current_data is Dictionary:
			var dict_data: Dictionary = current_data
			if dict_data.has(path_part):
				current_data = dict_data[path_part]
			else:
				return NavigationResult.new_not_found(
					"Path part not found in dictionary",
					current_path,
					_get_available_keys(dict_data)
				)
		elif current_data is Array:
			var index: int = -1
			if path_part is int:
				index = path_part
			elif path_part is String:
				var path_string: String = path_part
				if path_string.is_valid_int():
					index = path_string.to_int()

			var array_data: Array = current_data
			if index >= 0 and index < array_data.size():
				current_data = array_data[index]
			else:
				return NavigationResult.new_not_found(
					"Array index out of bounds or not a valid index",
					current_path,
					{"array_size": current_data.size(), "requested_index": path_part}
				)
		else:
			return NavigationResult.new_not_found(
				"Cannot navigate further: reached a leaf node",
				current_path,
				{"node_type": typeof(current_data)}
			)

	return _create_result_for_type(current_data, path)


static func _create_result_for_type(data: Variant, path: Array) -> NavigationResult:
	if data is Dictionary:
		var dict_data: Dictionary = data
		return NavigationResult.new_dictionary(dict_data, path)
	if data is Array:
		var array_data: Array = data
		return NavigationResult.new_array(array_data, path)
	return NavigationResult.new_value(data, path)


static func _get_available_keys(data: Dictionary) -> Dictionary:
	var available_keys: Array = data.keys()
	var max_keys: int = min(10, available_keys.size())
	return {
		"available_keys": available_keys.slice(0, max_keys), "total_keys": available_keys.size()
	}


static func get_value(
	json_data: Variant, path: Array[Variant], default_value: Variant = null
) -> Variant:
	var result: NavigationResult = navigate(json_data, path)
	if result.found:
		return result.value
	return default_value


static func path_exists(json_data: Variant, path: Array[Variant]) -> bool:
	return navigate(json_data, path).found


static func get_dictionary(
	json_data: Variant, path: Array[Variant], default_dict: Dictionary = {}
) -> Dictionary:
	var result: NavigationResult = navigate(json_data, path)
	if result.found and result.is_dictionary():
		return result.as_dictionary()
	return default_dict


static func get_array(json_data: Variant, path: Array[Variant], default_array: Array = []) -> Array:
	var result: NavigationResult = navigate(json_data, path)
	if result.found and result.is_array():
		return result.as_array()
	return default_array


static func get_string(
	json_data: Variant, path: Array[Variant], default_str: String = ""
) -> String:
	var result: NavigationResult = navigate(json_data, path)
	if result.found:
		if result.value is String:
			return result.value
		return str(result.value)
	return default_str


static func get_int(json_data: Variant, path: Array[Variant], default_int: int = 0) -> int:
	var result: NavigationResult = navigate(json_data, path)
	if result.found:
		if result.value is int:
			var int_value: int = result.value
			return int_value
		if result.value is float:
			var float_value: float = result.value
			return int(float_value)
		if result.value is String:
			var string_value: String = result.value
			if string_value.is_valid_int():
				return string_value.to_int()
	return default_int


static func get_float(
	json_data: Variant, path: Array[Variant], default_float: float = 0.0
) -> float:
	var result: NavigationResult = navigate(json_data, path)
	if result.found:
		if result.value is float:
			var float_value: float = result.value
			return float_value
		if result.value is int:
			var int_value: int = result.value
			return float(int_value)
		if result.value is String:
			var string_value: String = result.value
			if string_value.is_valid_float():
				return string_value.to_float()
	return default_float


static func get_bool(json_data: Variant, path: Array[Variant], default_bool: bool = false) -> bool:
	var result: NavigationResult = navigate(json_data, path)
	if result.found:
		if result.value is bool:
			var bool_value: bool = result.value
			return bool_value
		if result.value is int:
			var int_value: int = result.value
			return int_value != 0
		if result.value is String:
			var string_value: String = result.value
			var lower_str: String = string_value.to_lower()
			if lower_str == "true" or lower_str == "yes" or lower_str == "1":
				return true
			if lower_str == "false" or lower_str == "no" or lower_str == "0":
				return false
	return default_bool
