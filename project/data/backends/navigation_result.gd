class_name NavigationResult
extends RefCounted

enum ResultType { NOT_FOUND, DICTIONARY, ARRAY, VALUE }

var found: bool = false

var value: Variant = null

var path: Array[Variant] = []

var error_message: String = ""

var context: Dictionary = {}

var result_type: ResultType = ResultType.NOT_FOUND


func _init(
	p_found: bool,
	p_value: Variant,
	p_path: Array[Variant],
	p_result_type: ResultType,
	p_error_message: String = "",
	p_context: Dictionary = {}
) -> void:
	found = p_found
	value = p_value
	path = p_path
	result_type = p_result_type
	error_message = p_error_message
	context = p_context


static func new_not_found(
	p_error_message: String, p_path: Array[Variant], p_context: Dictionary = {}
) -> NavigationResult:
	return NavigationResult.new(
		false, null, p_path, ResultType.NOT_FOUND, p_error_message, p_context
	)


static func new_dictionary(dict: Dictionary, p_path: Array[Variant]) -> NavigationResult:
	return NavigationResult.new(true, dict, p_path, ResultType.DICTIONARY)


static func new_array(array: Array, p_path: Array[Variant]) -> NavigationResult:
	return NavigationResult.new(true, array, p_path, ResultType.ARRAY)


static func new_value(value_data: Variant, path_data: Array[Variant]) -> NavigationResult:
	return NavigationResult.new(true, value_data, path_data, ResultType.VALUE)


func is_dictionary() -> bool:
	return found and result_type == ResultType.DICTIONARY and value is Dictionary


func is_array() -> bool:
	return found and result_type == ResultType.ARRAY and value is Array


func is_value() -> bool:
	return found and result_type == ResultType.VALUE


func as_dictionary(default_dict: Dictionary = {}) -> Dictionary:
	if is_dictionary():
		return value
	return default_dict


func as_array(default_array: Array = []) -> Array:
	if is_array():
		return value
	return default_array


func as_string(default_str: String = "") -> String:
	if found:
		if value is String:
			var string_value: String = value
			return string_value
		return str(value)
	return default_str


func as_int(default_int: int = 0) -> int:
	if found:
		if value is int:
			var int_value: int = value
			return int_value
		elif value is float:
			var float_value: float = value
			return int(float_value)
		elif value is String:
			var string_value: String = value
			if string_value.is_valid_int():
				return string_value.to_int()
	return default_int


func as_float(default_float: float = 0.0) -> float:
	if found:
		if value is float:
			var float_value: float = value
			return float_value
		elif value is int:
			var int_value: int = value
			return float(int_value)
		elif value is String:
			var string_value: String = value
			if string_value.is_valid_float():
				return string_value.to_float()
	return default_float


func as_bool(default_bool: bool = false) -> bool:
	if found:
		if value is bool:
			var bool_value: bool = value
			return bool_value
		elif value is int:
			var int_value: int = value
			return int_value != 0
		elif value is String:
			var string_value: String = value
			var lower_str: String = string_value.to_lower()
			if lower_str == "true" or lower_str == "yes" or lower_str == "1":
				return true
			elif lower_str == "false" or lower_str == "no" or lower_str == "0":
				return false
	return default_bool


func get_formatted_string() -> String:
	if found:
		var type_name: String = ""
		match result_type:
			ResultType.DICTIONARY:
				type_name = "Dictionary"
			ResultType.ARRAY:
				type_name = "Array"
			ResultType.VALUE:
				type_name = "Value"
		return "NavigationResult[Found %s at %s: %s]" % [type_name, path, value]
	else:
		return "NavigationResult[Not Found at %s: %s (%s)]" % [path, error_message, context]
