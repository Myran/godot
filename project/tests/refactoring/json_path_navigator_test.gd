extends SceneTree

## Test script for JSONPathNavigator functionality
## Run with --script parameter from command line

func _init():
	print("Starting JSONPathNavigator Tests")
	print("--------------------------------")
	
	# Run the tests
	test_json_path_navigator()
	
	print("--------------------------------")
	print("All tests completed")
	quit()

func test_json_path_navigator():
	# Create a test data structure
	var test_data: Dictionary = {
		"players": [
			{
				"id": "player1",
				"name": "John",
				"stats": {
					"health": 100,
					"level": 5,
					"skills": ["jump", "run", "swim"]
				}
			},
			{
				"id": "player2",
				"name": "Alice",
				"stats": {
					"health": 120,
					"level": 7,
					"skills": ["fly", "climb", "dash"]
				}
			}
		],
		"settings": {
			"difficulty": "hard",
			"sound": true,
			"graphics": {
				"resolution": "1080p",
				"effects": ["bloom", "motion_blur"]
			}
		},
		"version": 2.1,
		"releases": [1.0, 1.5, 2.0, 2.1]
	}
	
	test_basic_navigation(test_data)
	test_array_navigation(test_data)
	test_nested_navigation(test_data)
	test_typed_getters(test_data)
	test_not_found_cases(test_data)

## Test basic navigation
func test_basic_navigation(test_data: Dictionary) -> void:
	print("\nTesting Basic Navigation:")
	
	# Test getting a direct property
	var version_result = JSONPathNavigator.navigate(test_data, ["version"])
	print("Version found: ", version_result.found, " - Value: ", version_result.value)
	
	# Test getting a dictionary
	var settings_result = JSONPathNavigator.navigate(test_data, ["settings"])
	print("Settings found: ", settings_result.found, " - Is dictionary: ", settings_result.is_dictionary())
	
	# Test getting an array
	var releases_result = JSONPathNavigator.navigate(test_data, ["releases"])
	print("Releases found: ", releases_result.found, " - Is array: ", releases_result.is_array())
	print("Releases content: ", releases_result.as_array())

## Test array navigation
func test_array_navigation(test_data: Dictionary) -> void:
	print("\nTesting Array Navigation:")
	
	# Test accessing array elements
	var player1_result = JSONPathNavigator.navigate(test_data, ["players", 0])
	print("Player 1 found: ", player1_result.found, " - Name: ", player1_result.as_dictionary().get("name", ""))
	
	# Test accessing properties within array elements
	var player2_name_result = JSONPathNavigator.navigate(test_data, ["players", 1, "name"])
	print("Player 2 name found: ", player2_name_result.found, " - Value: ", player2_name_result.value)
	
	# Test string index to access array element
	var player_string_index = JSONPathNavigator.navigate(test_data, ["players", "1", "name"])
	print("Player with string index found: ", player_string_index.found, " - Value: ", player_string_index.value)

## Test nested navigation
func test_nested_navigation(test_data: Dictionary) -> void:
	print("\nTesting Nested Navigation:")
	
	# Test deeply nested property
	var resolution_result = JSONPathNavigator.navigate(test_data, ["settings", "graphics", "resolution"])
	print("Resolution found: ", resolution_result.found, " - Value: ", resolution_result.value)
	
	# Test deeply nested array
	var effects_result = JSONPathNavigator.navigate(test_data, ["settings", "graphics", "effects"])
	print("Effects found: ", effects_result.found, " - Is array: ", effects_result.is_array())
	
	# Test deeply nested array element
	var effect1_result = JSONPathNavigator.navigate(test_data, ["settings", "graphics", "effects", 0])
	print("First effect found: ", effect1_result.found, " - Value: ", effect1_result.value)
	
	# Test player skills (deeply nested)
	var skills_result = JSONPathNavigator.navigate(test_data, ["players", 1, "stats", "skills", 2])
	print("Player 2 third skill found: ", skills_result.found, " - Value: ", skills_result.value)

## Test typed getters
func test_typed_getters(test_data: Dictionary) -> void:
	print("\nTesting Typed Getters:")
	
	# Test get_int
	var level_int: int = JSONPathNavigator.get_int(test_data, ["players", 0, "stats", "level"])
	print("Level as int: ", level_int)
	
	# Test get_float
	var version_float: float = JSONPathNavigator.get_float(test_data, ["version"])
	print("Version as float: ", version_float)
	
	# Test get_string
	var difficulty_string: String = JSONPathNavigator.get_string(test_data, ["settings", "difficulty"])
	print("Difficulty as string: ", difficulty_string)
	
	# Test get_bool
	var sound_bool: bool = JSONPathNavigator.get_bool(test_data, ["settings", "sound"])
	print("Sound as bool: ", sound_bool)
	
	# Test get_dictionary
	var stats_dict: Dictionary = JSONPathNavigator.get_dictionary(test_data, ["players", 1, "stats"])
	print("Stats as dictionary: ", stats_dict)
	
	# Test get_array
	var skills_array: Array = JSONPathNavigator.get_array(test_data, ["players", 0, "stats", "skills"])
	print("Skills as array: ", skills_array)

## Test not found cases
func test_not_found_cases(test_data: Dictionary) -> void:
	print("\nTesting Not Found Cases:")
	
	# Test non-existent property
	var missing_result = JSONPathNavigator.navigate(test_data, ["missing"])
	print("Missing property found: ", missing_result.found, " - Error: ", missing_result.error_message)
	
	# Test out of bounds array index
	var out_of_bounds = JSONPathNavigator.navigate(test_data, ["players", 5])
	print("Out of bounds found: ", out_of_bounds.found, " - Error: ", out_of_bounds.error_message)
	
	# Test invalid path type
	var invalid_path = JSONPathNavigator.navigate(test_data, ["version", "subversion"])
	print("Invalid path found: ", invalid_path.found, " - Error: ", invalid_path.error_message)
	
	# Test with default values
	var missing_with_default: int = JSONPathNavigator.get_int(test_data, ["missing_count"], 99)
	print("Missing count with default: ", missing_with_default)
	
	var missing_path_with_default: String = JSONPathNavigator.get_string(test_data, ["settings", "missing", "path"], "default_value")
	print("Missing path with default: ", missing_path_with_default)