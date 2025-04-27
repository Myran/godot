extends Node

## A simple test script for JSONPathNavigator functionality
## Run from Godot editor with "Run Current Scene"

# Import required utilities
const JSONPathNavigatorClass = preload("res://data/backends/json_path_navigator.gd")
const NavigationResultClass = preload("res://data/backends/navigation_result.gd")

func _ready() -> void:
	Log.info("Starting JSONPathNavigator tests", {}, ["test"])
	
	# Create a test JSON structure
	var test_data = {
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
	
	Log.info("JSONPathNavigator tests completed", {}, ["test"])

func _test_navigation(json_data: Dictionary, path: Array, description: String) -> void:
	Log.info("Test: " + description, {"path": path}, ["test"])
	
	var result = JSONPathNavigator.navigate(json_data, path)
	
	if result.found:
		Log.info("  ✓ Path found", {
			"result_type": result.result_type,
			"value_type": typeof(result.value),
			"value": result.value
		}, ["test"])
	else:
		Log.warning("  ✗ Path not found", {
			"error": result.error_message,
			"context": result.context
		}, ["test"])

# Test special type conversions
func _test_type_conversions(json_data: Dictionary) -> void:
	Log.info("Testing type conversions", {}, ["test"])
	
	# String conversions
	var string_path = ["config", "version"]
	var string_value = JSONPathNavigator.get_string(json_data, string_path)
	Log.info("  String value", {"path": string_path, "value": string_value}, ["test"])
	
	# Int conversions
	var int_path = ["sheets", "levels_0", 0, "id"]
	var int_value = JSONPathNavigator.get_int(json_data, int_path)
	Log.info("  Int value", {"path": int_path, "value": int_value}, ["test"])
	
	# Bool conversions
	var bool_path = ["config", "debug"]
	var bool_value = JSONPathNavigator.get_bool(json_data, bool_path)
	Log.info("  Bool value", {"path": bool_path, "value": bool_value}, ["test"])
	
	# Dictionary conversions
	var dict_path = ["config", "settings"]
	var dict_value = JSONPathNavigator.get_dictionary(json_data, dict_path)
	Log.info("  Dictionary value", {"path": dict_path, "value": dict_value}, ["test"])
	
	# Array conversions
	var array_path = ["sheets", "cards_0", 0, "abilities"]
	var array_value = JSONPathNavigator.get_array(json_data, array_path)
	Log.info("  Array value", {"path": array_path, "value": array_value}, ["test"])