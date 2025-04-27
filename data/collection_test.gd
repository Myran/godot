extends Node

## Test script for the refactored collections
## Add to a scene and run in the editor to test

# References to collections for testing
var card_collection: CardCollection
var level_collection: LevelCollection
var rules_collection: RulesCollection
var item_collection: ItemCollection
var player_collection: PlayerCollection
var event_collection: EventCollection

# Backend for testing
var backend: DataBackend

func _ready() -> void:
	print("Starting Collection Tests")
	print("------------------------")
	
	# Initialize the backend
	backend = LocalJSONBackend.new()
	var init_result: bool = backend.initialize()
	
	if not init_result:
		push_error("Failed to initialize backend")
		return
	
	# Create the collections
	card_collection = CardCollection.new(backend)
	level_collection = LevelCollection.new(backend)
	rules_collection = RulesCollection.new(backend)
	item_collection = ItemCollection.new(backend)
	player_collection = PlayerCollection.new(backend)
	event_collection = EventCollection.new(backend)
	
	# Connect to backend startup signal
	backend.startup_completed.connect(_on_backend_ready)

func _on_backend_ready() -> void:
	print("Backend initialized, starting tests")
	
	# Wait a frame to ensure everything is ready
	await get_tree().process_frame
	
	# Run tests
	await test_card_collection()
	await test_level_collection()
	await test_rules_collection()
	await test_item_collection()
	await test_player_collection()
	await test_event_collection()
	
	print("------------------------")
	print("Collection Tests Complete")

func test_card_collection() -> void:
	print("\nTesting Card Collection:")
	
	# Test get_all
	var cards: Array = await card_collection.get_all()
	print("Retrieved cards: ", cards.size())
	
	if cards.size() > 0:
		var sample_card: Dictionary = cards[0]
		print("Sample card: ", sample_card.get("name", "Unknown"))
		
		# Test get_by_id
		var card_id: String = sample_card.get("id", "")
		if not card_id.is_empty():
			var card: Dictionary = await card_collection.get_by_id(card_id)
			print("Retrieved card by ID: ", card.get("name", "Unknown"))
		
		# Test get_by_type
		var card_type: String = sample_card.get("type", "")
		if not card_type.is_empty():
			var typed_cards: Array = await card_collection.get_by_type(card_type)
			print("Retrieved cards by type (", card_type, "): ", typed_cards.size())
			
		# Test cache
		var cached_cards: Array = await card_collection.get_all(true)
		print("Retrieved cached cards: ", cached_cards.size())
		
		# Test clear cache
		card_collection.clear_cache()
		var fresh_cards: Array = await card_collection.get_all(true)
		print("Retrieved fresh cards after cache clear: ", fresh_cards.size())

func test_level_collection() -> void:
	print("\nTesting Level Collection:")
	
	# Test get_all
	var levels: Array = await level_collection.get_all()
	print("Retrieved levels: ", levels.size())
	
	if levels.size() > 0:
		var sample_level: Dictionary = levels[0]
		print("Sample level: ", sample_level.get("name", "Unknown"))
		
		# Test get_by_number
		var level_number: int = sample_level.get("number", 0)
		if level_number != 0:
			var level: Dictionary = await level_collection.get_by_number(level_number)
			print("Retrieved level by number (", level_number, "): ", level.get("name", "Unknown"))
		
		# Test get_levels_up_to
		var max_level: int = 3
		var early_levels: Array = await level_collection.get_levels_up_to(max_level)
		print("Retrieved levels up to ", max_level, ": ", early_levels.size())
		
		# Test cache
		var cached_levels: Array = await level_collection.get_all(true)
		print("Retrieved cached levels: ", cached_levels.size())
		
		# Test clear cache
		level_collection.clear_cache()
		var fresh_levels: Array = await level_collection.get_all(true)
		print("Retrieved fresh levels after cache clear: ", fresh_levels.size())

func test_rules_collection() -> void:
	print("\nTesting Rules Collection:")
	
	# Test get_rules
	var rules: Dictionary = await rules_collection.get_rules()
	print("Retrieved rules: ", rules.size(), " entries")
	
	if rules.size() > 0:
		# Print a sample rule
		var sample_key: String = rules.keys()[0]
		print("Sample rule: ", sample_key, " = ", rules[sample_key])
		
		# Test get_rule
		var rule_value: Variant = await rules_collection.get_rule(sample_key)
		print("Retrieved rule value for ", sample_key, ": ", rule_value)
		
		# Test get_rule with default
		var nonexistent_key: String = "nonexistent_rule_key"
		var default_value: int = 42
		var default_rule: Variant = await rules_collection.get_rule(nonexistent_key, default_value)
		print("Retrieved default rule value for ", nonexistent_key, ": ", default_rule)

func test_item_collection() -> void:
	print("\nTesting Item Collection:")
	
	# Test get_all
	var items: Array = await item_collection.get_all()
	print("Retrieved items: ", items.size())
	
	if items.size() > 0:
		var sample_item: Dictionary = items[0]
		print("Sample item: ", sample_item.get("name", "Unknown"))
		
		# Test get_by_id
		var item_id: String = sample_item.get("id", "")
		if not item_id.is_empty():
			var item: Dictionary = await item_collection.get_by_id(item_id)
			print("Retrieved item by ID: ", item.get("name", "Unknown"))
		
		# Test get_by_type
		var item_type: String = sample_item.get("type", "")
		if not item_type.is_empty():
			var typed_items: Array = await item_collection.get_by_type(item_type)
			print("Retrieved items by type (", item_type, "): ", typed_items.size())
		
		# Test get_by_rarity
		var item_rarity: String = sample_item.get("rarity", "")
		if not item_rarity.is_empty():
			var rarity_items: Array = await item_collection.get_by_rarity(item_rarity)
			print("Retrieved items by rarity (", item_rarity, "): ", rarity_items.size())
		
		# Test get_by_price_range
		var min_price: int = 10
		var max_price: int = 100
		var price_items: Array = await item_collection.get_by_price_range(min_price, max_price)
		print("Retrieved items by price range (", min_price, "-", max_price, "): ", price_items.size())
		
		# Test cache
		var cached_items: Array = await item_collection.get_all(true)
		print("Retrieved cached items: ", cached_items.size())
		
		# Test clear cache
		item_collection.clear_cache()
		var fresh_items: Array = await item_collection.get_all(true)
		print("Retrieved fresh items after cache clear: ", fresh_items.size())

func test_player_collection() -> void:
	print("\nTesting Player Collection:")
	
	# Test get_default_data
	var default_data: Dictionary = player_collection.get_default_data()
	print("Default player data fields: ", default_data.keys().size())
	
	# Test get_user_data
	var player_data: Dictionary = await player_collection.get_user_data()
	print("Retrieved player data fields: ", player_data.keys().size())
	
	if player_data.size() > 0:
		print("Player name: ", player_data.get("name", "Unknown"))
		
		# Test save_user_data (skip actual saving to avoid modifying real data)
		print("Player data save functionality available")
		
		# Test clear cache
		player_collection.clear_cache()
		var fresh_data: Dictionary = await player_collection.get_user_data()
		print("Retrieved fresh player data after cache clear: ", fresh_data.keys().size())

func test_event_collection() -> void:
	print("\nTesting Event Collection:")
	
	# Test get_all
	var events: Array = await event_collection.get_all()
	print("Retrieved events: ", events.size())
	
	if events.size() > 0:
		var sample_event: Dictionary = events[0]
		print("Sample event: ", sample_event.get("name", "Unknown"))
		
		# Test get_by_id
		var event_id: String = sample_event.get("id", "")
		if not event_id.is_empty():
			var event: Dictionary = await event_collection.get_by_id(event_id)
			print("Retrieved event by ID: ", event.get("name", "Unknown"))
		
		# Test get_by_type
		var event_type: String = sample_event.get("type", "")
		if not event_type.is_empty():
			var typed_events: Array = await event_collection.get_by_type(event_type)
			print("Retrieved events by type (", event_type, "): ", typed_events.size())
		
		# Test get_active_events
		var active_events: Array = await event_collection.get_active_events()
		print("Retrieved active events: ", active_events.size())
		
		# Test get_lineup_data (using first event, which might not have lineups)
		var lineup_data: Dictionary = await event_collection.get_lineup_data(event_id)
		print("Retrieved lineup data entries: ", lineup_data.size())
		
		# Test cache
		var cached_events: Array = await event_collection.get_all(true)
		print("Retrieved cached events: ", cached_events.size())
		
		# Test clear cache
		event_collection.clear_cache()
		var fresh_events: Array = await event_collection.get_all(true)
		print("Retrieved fresh events after cache clear: ", fresh_events.size())
