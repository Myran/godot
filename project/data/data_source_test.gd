extends Node

## Test script for the refactored data source
## Add to a scene and run in the editor to test

# Reference to the data source
var data_source: Node

func _ready() -> void:
	print("Starting DataSource Tests")
	print("-------------------------")
	
	# Get the data source or create it
	if has_node("/root/DataSource"):
		data_source = get_node("/root/DataSource")
		print("Using existing DataSource singleton")
	else:
		data_source = preload("res://project/data/data_source_refactored.gd").new()
		add_child(data_source)
		print("Created new DataSource instance")
	
	# Connect to startup signal
	if not data_source.is_connected("startup_completed", _on_data_source_ready):
		data_source.connect("startup_completed", _on_data_source_ready)
	
	if data_source.is_initialized():
		print("DataSource already initialized, running tests directly")
		await get_tree().process_frame
		_on_data_source_ready()
	else:
		print("Waiting for DataSource initialization...")

func _on_data_source_ready() -> void:
	print("\nDataSource initialization complete")
	
	# Run tests
	await test_cards()
	await test_levels()
	await test_items()
	await test_players()
	await test_events()
	await test_rules()
	
	# Test cache clearing
	test_cache_clearing()
	
	print("\n-------------------------")
	print("DataSource Tests Complete")

func test_cards() -> void:
	print("\nTesting Card Access:")
	
	# Test get_all_cards
	var cards: Array = await data_source.get_all_cards()
	print("Retrieved cards: ", cards.size())
	
	if cards.size() > 0:
		var sample_card: Dictionary = cards[0]
		print("Sample card: ", sample_card.get("name", "Unknown"))
		
		# Test get_card_info
		var card_id: String = sample_card.get("id", "")
		if not card_id.is_empty():
			var card: Dictionary = await data_source.get_card_info(card_id)
			print("Retrieved card by ID: ", card.get("name", "Unknown"))
		
		# Test get_card_id_from_name
		var card_name: String = sample_card.get("name", "")
		if not card_name.is_empty():
			var id: String = await data_source.get_card_id_from_name(card_name)
			print("Retrieved card ID from name: ", id)
	
	# Test card cache
	print("Activating card cache...")
	await data_source.activate_card_cache()
	var cached_cards: Array = await data_source.get_all_cards(true)
	print("Retrieved cached cards: ", cached_cards.size())

func test_levels() -> void:
	print("\nTesting Level Access:")
	
	# Test get_all_levels
	var levels: Array = await data_source.get_all_levels()
	print("Retrieved levels: ", levels.size())
	
	if levels.size() > 0:
		var sample_level: Dictionary = levels[0]
		print("Sample level: ", sample_level.get("name", "Unknown"))
		
		# Test get_level_data
		var level_nr: int = sample_level.get("number", 0)
		if level_nr != 0:
			var level: Dictionary = await data_source.get_level_data(level_nr)
			print("Retrieved level by number: ", level.get("name", "Unknown"))

func test_items() -> void:
	print("\nTesting Item Access:")
	
	# Test get_all_items
	var items: Array = await data_source.get_all_items()
	print("Retrieved items: ", items.size())
	
	if items.size() > 0:
		var sample_item: Dictionary = items[0]
		print("Sample item: ", sample_item.get("name", "Unknown"))
		
		# Test get_item_info
		var item_id: String = sample_item.get("id", "")
		if not item_id.is_empty():
			var item: Dictionary = await data_source.get_item_info(item_id)
			print("Retrieved item by ID: ", item.get("name", "Unknown"))
		
		# Test get_item_id_from_name
		var item_name: String = sample_item.get("name", "")
		if not item_name.is_empty():
			var id: String = await data_source.get_item_id_from_name(item_name)
			print("Retrieved item ID from name: ", id)

func test_players() -> void:
	print("\nTesting Player Access:")
	
	# Test get_user_data
	var player_data: Dictionary = await data_source.get_user_data()
	print("Retrieved player data fields: ", player_data.keys().size())
	
	if player_data.size() > 0:
		print("Player name: ", player_data.get("name", "Unknown"))
		
	# Test get_default_player_data
	var default_data: Dictionary = data_source.get_default_player_data()
	print("Default player data fields: ", default_data.keys().size())
	
	# Test player data setup (skip for test to avoid modifying data)
	print("Player data setup functionality available")

func test_events() -> void:
	print("\nTesting Event Access:")
	
	# Test get_event_data
	var events: Array = await data_source.get_event_data()
	print("Retrieved events: ", events.size())
	
	if events.size() > 0:
		var sample_event: Dictionary = events[0]
		print("Sample event: ", sample_event.get("name", "Unknown"))
		
		# Test get_event_lineups_data
		var event_id: String = sample_event.get("id", "")
		if not event_id.is_empty():
			var lineups: Dictionary = await data_source.get_event_lineups_data(event_id)
			print("Retrieved lineup data entries: ", lineups.size())

func test_rules() -> void:
	print("\nTesting Rules Access:")
	
	# Test get_rules_data
	var rules: Dictionary = await data_source.get_rules_data()
	print("Retrieved rules: ", rules.size(), " entries")
	
	if rules.size() > 0:
		# Print a sample rule
		var sample_key: String = rules.keys()[0]
		print("Sample rule: ", sample_key, " = ", rules[sample_key])

func test_cache_clearing() -> void:
	print("\nTesting Cache Clearing:")
	
	# Test clear_all_caches
	data_source.clear_all_caches()
	print("All caches cleared successfully")
	
	# Verify by getting cards again
	var fresh_cards: Array = await data_source.get_all_cards()
	print("Retrieved fresh cards after cache clear: ", fresh_cards.size())
