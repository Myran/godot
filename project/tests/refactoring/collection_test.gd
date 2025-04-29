extends SceneTree

## Test script for Collections with JSONPathNavigator
## Run with --script parameter from command line

func _init():
	print("Starting Collection Tests")
	print("--------------------------------")
	
	# Run the tests
	test_card_collection()
	test_level_collection()
	test_item_collection()
	test_rules_collection()
	
	print("--------------------------------")
	print("All tests completed")
	quit()

func test_card_collection():
	print("\nTesting CardCollection:")
	
	# Create a LocalJSONBackend with test data
	var backend = create_test_backend()
	
	# Create a CardCollection with the backend
	var card_collection = CardCollection.new(backend, 0)
	
	# Test get_all method
	print("Testing get_all...")
	var all_cards = await card_collection.get_all()
	print("Found ", all_cards.size(), " cards")
	
	# Test get_by_id method
	print("Testing get_by_id...")
	var card = await card_collection.get_by_id("1")
	print("Card found: ", "id" in card and "name" in card)
	
	# Test get_id_by_name method
	print("Testing get_id_by_name...")
	var card_id = await card_collection.get_id_by_name("Test Card 1")
	print("Card ID found: ", card_id)

func test_level_collection():
	print("\nTesting LevelCollection:")
	
	# Create a LocalJSONBackend with test data
	var backend = create_test_backend()
	
	# Create a LevelCollection with the backend
	var level_collection = LevelCollection.new(backend, 0)
	
	# Test get_all method
	print("Testing get_all...")
	var all_levels = await level_collection.get_all()
	print("Found ", all_levels.size(), " levels")
	
	# Test get_by_number method
	print("Testing get_by_number...")
	var level = await level_collection.get_by_number(1)
	print("Level found: ", "id" in level and "name" in level)

func test_item_collection():
	print("\nTesting ItemCollection:")
	
	# Create a LocalJSONBackend with test data
	var backend = create_test_backend()
	
	# Create an ItemCollection with the backend
	var item_collection = ItemCollection.new(backend, 0)
	
	# Test get_all method
	print("Testing get_all...")
	var all_items = await item_collection.get_all()
	print("Found ", all_items.size(), " items")
	
	# Test get_by_id method
	print("Testing get_by_id...")
	var item = await item_collection.get_by_id("1")
	print("Item found: ", "id" in item and "name" in item)
	
	# Test get_by_type method
	print("Testing get_by_type...")
	var consumables = await item_collection.get_by_type("consumable")
	print("Found ", consumables.size(), " consumable items")

func test_rules_collection():
	print("\nTesting RulesCollection:")
	
	# Create a LocalJSONBackend with test data
	var backend = create_test_backend()
	
	# Create a RulesCollection with the backend
	var rules_collection = RulesCollection.new(backend, 0)
	
	# Test get_rules method
	print("Testing get_rules...")
	var rules = await rules_collection.get_rules()
	print("Rules found: ", rules.size() > 0)
	
	# Test get_rule method
	print("Testing get_rule...")
	var difficulty_rule = await rules_collection.get_rule("difficulty")
	print("Difficulty rule: ", difficulty_rule)

# Helper to create a test backend with sample data
func create_test_backend() -> DataBackend:
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
			],
			"items_0": [
				{
					"id": "1",
					"name": "Health Potion",
					"type": "consumable",
					"effect": "heal"
				},
				{
					"id": "2",
					"name": "Sword",
					"type": "weapon",
					"damage": 10
				}
			],
			"rules_0": {
				"difficulty": "normal",
				"starting_gold": 100,
				"max_level": 10
			}
		}
	}
	
	# Create a backend that will return our test data
	var backend = LocalJSONBackend.new("res://resources/test_data.json")
	# We'll mock the get_data method to return our test data
	backend._data = test_data
	
	return backend