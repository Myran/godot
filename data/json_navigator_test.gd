extends Node

## A simple test script for JSONPathNavigator functionality
## Run from Godot editor with "Run Current Scene"

# Import required utilities
const JSONPathNavigatorClass = preload("res://data/backends/json_path_navigator.gd")
const NavigationResultClass = preload("res://data/backends/navigation_result.gd")

func _ready() -> void:
	print("Starting JSONPathNavigator tests")

	# Create a test JSON structure
	var test_data: Dictionary = {
		"sheets": {
			"cards_0": [
				{
					"id": "1",
					"name": "Test Card 1",
					"type": "unit",
					"abilities": ["heal", "attack"]
				},
				{
					"id": "2",
					"name": "Test Card 2",
					"type": "spell",
					"abilities": ["damage"]
				}
			],
			"levels_0": [
				{
					"id": 1,
					"name": "Level 1",
					"difficulty": "easy"
				},
				{
					"id": 2,
					"name": "Level 2",
					"difficulty": "medium"
				}
			]
		},
		"config": {
			"version": "1.0",
			"debug": true,
			"settings": {
				"sound": true,
				"music": false
			}
		}
	}

	# Test navigating to different parts of the structure
	_test_navigation(test_data, ["sheets", "cards_0"], "Testing cards_0 path")
	_test_navigation(test_data, ["sheets", "cards_0", 0], "Testing card index 0")
	_test_navigation(test_data, ["sheets", "cards_0", 0, "name"], "Testing card name")
	_test_navigation(test_data, ["sheets", "cards_0", 0, "abilities"], "Testing card abilities")
	_test_navigation(test_data, ["sheets", "cards_0", 0, "abilities", 0], "Testing ability index 0")
	_test_navigation(test_data, ["config", "settings", "sound"], "Testing config setting")

	# Test negative cases
	_test_navigation(test_data, ["sheets", "cards_1"], "Testing non-existent path")
	_test_navigation(test_data, ["sheets", "cards_0", 5], "Testing out of bounds index")
	_test_navigation(test_data, ["sheets", "cards_0", 0, "non_existent"], "Testing non-existent field")
	
	# Test type conversions
	_test_type_conversions(test_data)

	print("JSONPathNavigator tests completed")
	
	# For headless mode
	if OS.has_feature("headless"):
		get_tree().quit()

func _test_navigation(json_data: Dictionary, path: Array, description: String) -> void:
	print("Test: " + description + ", path: " + str(path))

	var result = JSONPathNavigatorClass.navigate(json_data, path)

	if result.found:
		print("  ✓ Path found, result_type: " + str(result.result_type) + 
			 ", value_type: " + str(typeof(result.value)) + 
			 ", value: " + str(result.value))
	else:
		print("  ✗ Path not found, error: " + result.error_message)

# Test special type conversions
func _test_type_conversions(json_data: Dictionary) -> void:
	print("Testing type conversions")

	# String conversions
	var string_path = ["config", "version"]
	var string_value = JSONPathNavigatorClass.get_string(json_data, string_path)
	print("  String value - path: " + str(string_path) + ", value: " + string_value)

	# Int conversions
	var int_path = ["sheets", "levels_0", 0, "id"]
	var int_value = JSONPathNavigatorClass.get_int(json_data, int_path)
	print("  Int value - path: " + str(int_path) + ", value: " + str(int_value))

	# Bool conversions
	var bool_path = ["config", "debug"]
	var bool_value = JSONPathNavigatorClass.get_bool(json_data, bool_path)
	print("  Bool value - path: " + str(bool_path) + ", value: " + str(bool_value))

	# Dictionary conversions
	var dict_path = ["config", "settings"]
	var dict_value = JSONPathNavigatorClass.get_dictionary(json_data, dict_path)
	print("  Dictionary value - path: " + str(dict_path) + ", value: " + str(dict_value))

	# Array conversions
	var array_path = ["sheets", "cards_0", 0, "abilities"]
	var array_value = JSONPathNavigatorClass.get_array(json_data, array_path)
	print("  Array value - path: " + str(array_path) + ", value: " + str(array_value))