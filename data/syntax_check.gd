extends Node

## This file is used to validate our static typing syntax
## by checking if it passes Godot's parser and type checker

# Class variables
var dict_array: Array[Dictionary] = []
var string_array: Array[String] = []
var int_array: Array[int] = []
var variant_array: Array[Variant] = []

var test_string: String = "Hello"
var test_int: int = 42
var test_float: float = 3.14
var test_bool: bool = true
var test_dict: Dictionary = {"key": "value"}
var test_variant: Variant = null

# A function with typed parameters and return value
func add_numbers(a: int, b: int) -> int:
	return a + b

# A function that works with typed arrays
func process_dictionaries(items: Array[Dictionary]) -> int:
	var count: int = 0
	
	for item: Dictionary in items:
		if item.has("count"):
			count += item.count as int
			
	return count

# A function that demonstrates safe casting
func safe_cast_example(data: Variant) -> Dictionary:
	if data is Dictionary:
		return data as Dictionary
	return {}

# A function that uses Array[Variant] for path navigation
func navigate_path(data: Dictionary, path: Array[Variant]) -> Variant:
	var current: Variant = data
	
	for part: Variant in path:
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			return null
			
	return current
