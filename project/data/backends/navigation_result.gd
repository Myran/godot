class_name NavigationResult
extends RefCounted

## A class to encapsulate the result of a JSON structure navigation.
## Provides type-safe access to the navigation result.

## Whether the navigation was successful
var found: bool = false

## The value found at the path (can be any type)
var value: Variant = null

## The path that was navigated
var path: Array = []

## Error message if navigation failed
var error_message: String = ""

## Additional context information for debugging
var context: Dictionary = {}

## Result type constants
enum ResultType {
	NOT_FOUND,
	DICTIONARY,
	ARRAY,
	VALUE
}

## The type of result
var result_type: ResultType = ResultType.NOT_FOUND

## Create a new NavigationResult
## @param found Whether the navigation was successful
## @param value The value found at the path
## @param path The path that was navigated
## @param result_type The type of result
## @param error_message Error message if navigation failed
## @param context Additional context information for debugging
func _init(
	p_found: bool,
	p_value: Variant,
	p_path: Array,
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

## Create a "not found" result
## @param error_message Error message describing why the path was not found
## @param path The path that was navigated
## @param context Additional context information for debugging
## @return A NavigationResult representing a failed navigation
static func new_not_found(
	error_message: String,
	path: Array,
	context: Dictionary = {}
) -> NavigationResult:
	return NavigationResult.new(
		false,
		null,
		path,
		ResultType.NOT_FOUND,
		error_message,
		context
	)

## Create a dictionary result
## @param dict The dictionary that was found
## @param path The path that was navigated
## @return A NavigationResult containing a dictionary
static func new_dictionary(dict: Dictionary, path: Array) -> NavigationResult:
	return NavigationResult.new(
		true,
		dict,
		path,
		ResultType.DICTIONARY
	)

## Create an array result
## @param array The array that was found
## @param path The path that was navigated
## @return A NavigationResult containing an array
static func new_array(array: Array, path: Array) -> NavigationResult:
	return NavigationResult.new(
		true,
		array,
		path,
		ResultType.ARRAY
	)

## Create a value result
## @param value The value that was found
## @param path The path that was navigated
## @return A NavigationResult containing a value
static func new_value(value: Variant, path: Array) -> NavigationResult:
	return NavigationResult.new(
		true,
		value,
		path,
		ResultType.VALUE
	)

## Check if the result is a dictionary
## @return True if the result is a dictionary
func is_dictionary() -> bool:
	return found and result_type == ResultType.DICTIONARY and value is Dictionary

## Check if the result is an array
## @return True if the result is an array
func is_array() -> bool:
	return found and result_type == ResultType.ARRAY and value is Array

## Check if the result is a value (not a dictionary or array)
## @return True if the result is a value
func is_value() -> bool:
	return found and result_type == ResultType.VALUE

## Get the result as a dictionary
## @param default_dict Dictionary to return if the result is not a dictionary
## @return The result as a dictionary or the default dictionary
func as_dictionary(default_dict: Dictionary = {}) -> Dictionary:
	if is_dictionary():
		return value
	return default_dict

## Get the result as an array
## @param default_array Array to return if the result is not an array
## @return The result as an array or the default array
func as_array(default_array: Array = []) -> Array:
	if is_array():
		return value
	return default_array

## Get the result as a string
## @param default_str String to return if the result is not a string
## @return The result as a string or the default string
func as_string(default_str: String = "") -> String:
	if found:
		if value is String:
			return value
		else:
			# Try to convert to string if possible
			return str(value)
	return default_str

## Get the result as an integer
## @param default_int Integer to return if the result is not an integer
## @return The result as an integer or the default integer
func as_int(default_int: int = 0) -> int:
	if found:
		if value is int:
			return value
		elif value is float:
			return int(value)
		elif value is String and value.is_valid_int():
			return value.to_int()
	return default_int

## Get the result as a float
## @param default_float Float to return if the result is not a float
## @return The result as a float or the default float
func as_float(default_float: float = 0.0) -> float:
	if found:
		if value is float or value is int:
			return float(value)
		elif value is String and value.is_valid_float():
			return value.to_float()
	return default_float

## Get the result as a boolean
## @param default_bool Boolean to return if the result is not a boolean
## @return The result as a boolean or the default boolean
func as_bool(default_bool: bool = false) -> bool:
	if found:
		if value is bool:
			return value
		elif value is int:
			return value != 0
		elif value is String:
			var lower_str: String = value.to_lower()
			if lower_str == "true" or lower_str == "yes" or lower_str == "1":
				return true
			elif lower_str == "false" or lower_str == "no" or lower_str == "0":
				return false
	return default_bool

## Get a human-readable representation of the result
## @return A string representation of the result
func to_string() -> String:
	if found:
		var type_name := ""
		match result_type:
			ResultType.DICTIONARY: type_name = "Dictionary"
			ResultType.ARRAY: type_name = "Array"
			ResultType.VALUE: type_name = "Value"
		
		return "NavigationResult[Found %s at %s: %s]" % [type_name, path, value]
	else:
		return "NavigationResult[Not Found at %s: %s (%s)]" % [path, error_message, context]
