extends Node

## Test script for validating DataSource refactoring implementation
## Tests both new collection-based API and backward compatibility
## Godot resource path: res://project/tests/data_source_test.gd

var tests_passed = 0
var tests_failed = 0

func _ready() -> void:
	# Wait for DataSource to initialize
	await get_node("/root/DataSource").startup_completed
	
	Log.info("Starting DataSource tests", {}, [Log.TAG_DB])
	# Run tests
	await run_all_tests()
	
	# Report results
	print("===== TEST RESULTS =====")
	print("Passed: ", tests_passed)
	print("Failed: ", tests_failed)
	print("========================")
	
	get_tree().quit()
	
func run_all_tests() -> void:
	await test_cards_collection()
	await test_levels_collection()
	await test_items_collection()
	await test_rules_collection()
	await test_events_collection()
	await test_player_collection()
	await test_backwards_compatibility()
	
func test_cards_collection() -> void:
	print("Testing Cards Collection...")
	
	# Test get_all cards
	var cards = await DataSource.cards.get_all()
	assert_test(cards.size() > 0, "Cards collection should return cards")
	
	# Test get card by ID
	if cards.size() > 0:
		var first_card_id = cards[0].id
		var card = await DataSource.cards.get_by_id(first_card_id)
		assert_test(card.id == first_card_id, "Should retrieve correct card by ID")
	
	# Test get card by name
	if cards.size() > 0:
		var first_card_name = cards[0].name
		var card_id = await DataSource.cards.get_id_by_name(first_card_name)
		assert_test(card_id == cards[0].id, "Should retrieve correct card ID by name")
	
	# Test card caching
	var cached_cards = await DataSource.cards.get_all(true)
	assert_test(cached_cards.size() == cards.size(), "Cached cards should match initial fetch")
	
	# Test get cards by type if possible
	if cards.size() > 0 and "type" in cards[0]:
		var card_type = cards[0].type
		var typed_cards = await DataSource.cards.get_by_type(card_type)
		assert_test(typed_cards.size() > 0, "Should retrieve cards by type")

func test_levels_collection() -> void:
	print("Testing Levels Collection...")
	
	# Test get_all levels
	var levels = await DataSource.levels.get_all()
	assert_test(levels.size() > 0, "Levels collection should return levels")
	
	# Test get level by number
	if levels.size() > 0:
		var first_level_id = int(levels[0].id)
		var level = await DataSource.levels.get_by_number(first_level_id)
		assert_test(int(level.id) == first_level_id, "Should retrieve correct level by number")
	
	# Test level caching
	var cached_levels = await DataSource.levels.get_all(true)
	assert_test(cached_levels.size() == levels.size(), "Cached levels should match initial fetch")

func test_items_collection() -> void:
	print("Testing Items Collection...")
	
	# Test get_all items
	var items = await DataSource.items.get_all()
	assert_test(items.size() > 0, "Items collection should return items")
	
	# Test get item by ID
	if items.size() > 0:
		var first_item_id = items[0].id
		var item = await DataSource.items.get_by_id(first_item_id)
		assert_test(item.id == first_item_id, "Should retrieve correct item by ID")
	
	# Test get item by name
	if items.size() > 0:
		var first_item_name = items[0].name
		var item_id = await DataSource.items.get_id_by_name(first_item_name)
		assert_test(item_id == items[0].id, "Should retrieve correct item ID by name")
	
	# Test item caching
	var cached_items = await DataSource.items.get_all(true)
	assert_test(cached_items.size() == items.size(), "Cached items should match initial fetch")

func test_rules_collection() -> void:
	print("Testing Rules Collection...")
	
	# Test get rules data
	var rules = await DataSource.rules.get_rules()
	assert_test(rules.size() > 0, "Rules collection should return rules data")

func test_events_collection() -> void:
	print("Testing Events Collection...")
	
	# Test get all events
	var events = await DataSource.events.get_all()
	assert_test(events.size() > 0, "Events collection should return events")
	
	# Test event lineup functions if possible, but only if Firebase is available
	if DataSource.is_firebase_available() and events.size() > 0:
		var event_id = events[0].id
		
		# Create test lineup
		var test_lineup = {"test": "data", "timestamp": Time.get_unix_time_from_system()}
		var lineup_id = await DataSource.events.save_lineup_data(event_id, test_lineup)
		assert_test(not lineup_id.is_empty(), "Should create lineup and return ID")
		
		# Get lineup data
		var lineups = await DataSource.events.get_lineup_data(event_id)
		assert_test(lineups.size() > 0, "Should retrieve lineup data")
		
		# Update lineup
		test_lineup.updated = true
		var update_result = await DataSource.events.save_lineup_data(event_id, test_lineup, 1, {}, 3, lineup_id)
		assert_test(update_result == lineup_id, "Should update existing lineup")
		
		# Remove lineup data
		var remove_result = await DataSource.events.remove_event_lineups(event_id)
		assert_test(remove_result, "Should remove event lineups")

func test_player_collection() -> void:
	print("Testing Player Collection...")
	
	# Test get default player data
	var default_data = DataSource.players.get_default_data()
	assert_test(default_data.size() > 0, "Should return default player data")
	
	# Test user data functions if possible
	if DataSource.is_firebase_available():
		# Get current user data
		var user_data = await DataSource.players.get_user_data()
		
		# Prepare test data
		var test_data = default_data.duplicate()
		test_data.test_value = "test_" + str(Time.get_unix_time_from_system())
		
		# Save user data
		var save_result = await DataSource.players.save_user_data(test_data)
		assert_test(save_result, "Should save user data")
		
		# Get updated user data
		var updated_data = await DataSource.players.get_user_data()
		assert_test("test_value" in updated_data and updated_data.test_value == test_data.test_value, "Should retrieve updated user data")

func test_backwards_compatibility() -> void:
	print("Testing Backwards Compatibility...")
	
	# Test card compatibility methods
	var cards_direct = await DataSource.cards.get_all()
	var cards_compat = await DataSource.get_all_cards()
	assert_test(cards_direct.size() == cards_compat.size(), "get_all_cards compatibility method should return same data")
	
	if cards_direct.size() > 0:
		var card_id = cards_direct[0].id
		var card_direct = await DataSource.cards.get_by_id(card_id)
		var card_compat = await DataSource.get_card_info(card_id)
		assert_test(card_direct.id == card_compat.id, "get_card_info compatibility method should return same data")
	
	# Test level compatibility methods
	var levels_direct = await DataSource.levels.get_all()
	var levels_compat = await DataSource.get_all_levels()
	assert_test(levels_direct.size() == levels_compat.size(), "get_all_levels compatibility method should return same data")
	
	if levels_direct.size() > 0:
		var level_id = int(levels_direct[0].id)
		var level_direct = await DataSource.levels.get_by_number(level_id)
		var level_compat = await DataSource.get_level_data(level_id)
		assert_test(int(level_direct.id) == int(level_compat.id), "get_level_data compatibility method should return same data")
	
	# Test item compatibility methods
	var items_direct = await DataSource.items.get_all()
	var items_compat = await DataSource.get_all_items()
	assert_test(items_direct.size() == items_compat.size(), "get_all_items compatibility method should return same data")
	
	# Test rules compatibility methods
	var rules_direct = await DataSource.rules.get_rules()
	var rules_compat = await DataSource.get_rules_data()
	assert_test(rules_direct.size() == rules_compat.size(), "get_rules_data compatibility method should return same data")
	
	# Test event compatibility methods
	var events_direct = await DataSource.events.get_all()
	var events_compat = await DataSource.get_event_data()
	assert_test(events_direct.size() == events_compat.size(), "get_event_data compatibility method should return same data")
	
	# Test cache activation
	DataSource.activate_card_cache()
	var cached_cards = await DataSource.cards.get_all(true)
	assert_test(cached_cards.size() > 0, "Card cache activation should work")
	
	# Test cache clearing
	DataSource.clear_card_cache()
	DataSource.clear_level_cache()
	DataSource.clear_item_cache()
	
func assert_test(condition: bool, message: String) -> void:
	if condition:
		tests_passed += 1
		print("✓ PASS: ", message)
	else:
		tests_failed += 1
		print("✗ FAIL: ", message)
		# Log the failure with more detailed information
		Log.error("Test failed", {"message": message}, [Log.TAG_DB, Log.TAG_ERROR])