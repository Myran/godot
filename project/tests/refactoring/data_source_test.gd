extends SceneTree

## Test script for DataSource refactored implementation
## Run with --script parameter from command line

func _init():
	print("Starting DataSource Tests")
	print("--------------------------------")
	
	# Run the tests
	test_data_source()
	
	print("--------------------------------")
	print("All tests completed")
	quit()

func test_data_source():
	print("\nTesting DataSource Refactored Implementation:")
	
	# Create a DataSource instance with the refactored implementation
	var data_source = create_test_data_source()
	
	# Test initialization
	print("Testing initialization...")
	print("Collections initialized: ", data_source.cards != null and data_source.levels != null and 
		data_source.items != null and data_source.players != null and 
		data_source.events != null and data_source.rules != null)
	
	# Test legacy methods
	print("\nTesting legacy compatibility methods:")
	
	print("Testing get_all_cards...")
	var cards = await data_source.get_all_cards()
	print("Found ", cards.size(), " cards")
	
	print("Testing get_card_info...")
	var card = await data_source.get_card_info("1")
	print("Card found: ", "id" in card and "name" in card)
	
	print("Testing get_card_id_from_name...")
	var card_id = await data_source.get_card_id_from_name("Test Card 1")
	print("Card ID found: ", card_id)
	
	print("Testing get_all_levels...")
	var levels = await data_source.get_all_levels()
	print("Found ", levels.size(), " levels")
	
	print("Testing get_level_data...")
	var level = await data_source.get_level_data(1)
	print("Level found: ", "id" in level and "name" in level)
	
	print("Testing get_all_items...")
	var items = await data_source.get_all_items()
	print("Found ", items.size(), " items")
	
	print("Testing get_item_info...")
	var item = await data_source.get_item_info("1")
	print("Item found: ", "id" in item and "name" in item)
	
	print("Testing get_rules_data...")
	var rules = await data_source.get_rules_data()
	print("Rules found: ", rules.size() > 0)
	
	print("\nTesting cache functionality:")
	
	# Activate and test card cache
	print("Testing activate_card_cache...")
	await data_source.activate_card_cache()
	print("Card cache activated")
	
	# Clear caches and test
	print("Testing clear_all_caches...")
	data_source.clear_all_caches()
	print("All caches cleared")

# Helper to create a test DataSource
func create_test_data_source():
	# Create the data source
	var data_source = preload("res://data/data_source_refactored.gd").new()
	
	# Create test data
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
			},
			"event_data_0": [
				{
					"id": "event1",
					"name": "Test Event 1",
					"type": "tournament"
				},
				{
					"id": "event2",
					"name": "Test Event 2",
					"type": "quest"
				}
			]
		}
	}
	
	# Inject test data into data source
	# We'll need to replace _backend with a mock backend that returns our test data
	var mock_backend = LocalJSONBackend.new("res://resources/test_data.json")
	mock_backend._data = test_data
	
	# Replace the backend and initialize collections
	data_source._backend = mock_backend
	data_source._initialize_collections()
	
	return data_source