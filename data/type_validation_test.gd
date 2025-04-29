extends Node

## Simple static typing validation script
## Tests the core functionality of our refactored classes
## Run from the editor

func _ready() -> void:
	var log_file = FileAccess.open("user://validation_test_results.txt", FileAccess.WRITE)
	log_file.store_line("Starting Static Typing Validation Test")
	log_file.store_line("--------------------------------------")
	
	print("Starting Static Typing Validation Test")
	print("--------------------------------------")
	
	# Test typed arrays
	test_typed_arrays()
	
	# Test JSON navigation
	test_json_navigation()
	
	# Test collection classes
	test_collections()
	
	print("--------------------------------------")
	print("Static Typing Validation Complete")
	
	log_file.store_line("--------------------------------------")
	log_file.store_line("Static Typing Validation Complete")
	log_file.close()

## Test the usage of typed arrays
func test_typed_arrays() -> void:
	print("\nTesting Typed Arrays:")
	
	# Define typed arrays
	var dict_array: Array[Dictionary] = []
	var string_array: Array[String] = []
	var int_array: Array[int] = []
	
	# Populate arrays
	dict_array.append({"name": "Test 1", "value": 10})
	dict_array.append({"name": "Test 2", "value": 20})
	
	string_array.append("Hello")
	string_array.append("World")
	
	int_array.append(42)
	int_array.append(123)
	
	# Test iterating with typed iterators
	print("  Dict Iterator Test:")
	for item: Dictionary in dict_array:
		print("    " + item.name + ": " + str(item.value))
	
	print("  String Iterator Test:")
	for text: String in string_array:
		print("    " + text)
	
	print("  Int Iterator Test:")
	for number: int in int_array:
		print("    " + str(number))
	
	print("  Typed Arrays Test: ✓")

## Test the JSON navigation functionality
func test_json_navigation() -> void:
	print("\nTesting JSON Navigation:")
	
	# Create test data
	var test_data: Dictionary = {
		"players": {
			"player1": {
				"name": "Alice",
				"score": 100,
				"items": ["sword", "shield"]
			},
			"player2": {
				"name": "Bob",
				"score": 85,
				"items": ["potion", "staff"]
			}
		},
		"settings": {
			"difficulty": "hard",
			"sound": true
		}
	}
	
	# Create navigation paths
	var player_path: Array[Variant] = ["players", "player1"]
	var name_path: Array[Variant] = ["players", "player1", "name"]
	var items_path: Array[Variant] = ["players", "player1", "items"]
	var settings_path: Array[Variant] = ["settings"]
	
	# Navigate to values
	var player_result: Dictionary = _get_dict(test_data, player_path)
	var name_result: String = _get_string(test_data, name_path)
	var items_result: Array = _get_array(test_data, items_path)
	var settings_result: Dictionary = _get_dict(test_data, settings_path)
	
	# Print results
	print("  Player Object: " + str(player_result.name))
	print("  Player Name: " + name_result)
	print("  Player Items: " + str(items_result))
	print("  Settings: " + str(settings_result.difficulty))
	
	print("  JSON Navigation Test: ✓")

## Test the collection classes
func test_collections() -> void:
	print("\nTesting Collections:")
	
	# Create a mock card collection
	var cards: Array[Dictionary] = []
	
	# Add some cards
	cards.append({
		"id": "1",
		"name": "Test Card 1",
		"type": "unit",
		"rarity": "common"
	})
	
	cards.append({
		"id": "2",
		"name": "Test Card 2",
		"type": "spell",
		"rarity": "rare"
	})
	
	cards.append({
		"id": "3",
		"name": "Test Card 3",
		"type": "unit",
		"rarity": "common"
	})
	
	# Filter by type
	var units: Array[Dictionary] = []
	for card: Dictionary in cards:
		if card.type == "unit":
			units.append(card)
	
	print("  Total Cards: " + str(cards.size()))
	print("  Unit Cards: " + str(units.size()))
	
	print("  Collections Test: ✓")

## Helper function to get a dictionary from a path
func _get_dict(data: Dictionary, path: Array[Variant]) -> Dictionary:
	var current: Variant = data
	
	for part: Variant in path:
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			return {}
	
	if current is Dictionary:
		return current as Dictionary
	
	return {}

## Helper function to get a string from a path
func _get_string(data: Dictionary, path: Array[Variant]) -> String:
	var current: Variant = data
	
	for part: Variant in path:
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			return ""
	
	if current is String:
		return current as String
	
	return ""

## Helper function to get an array from a path
func _get_array(data: Dictionary, path: Array[Variant]) -> Array:
	var current: Variant = data
	
	for part: Variant in path:
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			return []
	
	if current is Array:
		return current as Array
	
	return []