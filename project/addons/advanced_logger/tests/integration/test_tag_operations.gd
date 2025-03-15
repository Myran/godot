@tool
extends Node
class_name TestTagOperations

# This test validates the tag operations functionality
# which is a key area for refactoring

var Logger = preload("res://addons/advanced_logger/logger.gd")
var LoggerDock = preload("res://addons/advanced_logger/logger_dock.gd")

func _ready():
	print("\n=== Running Tag Operations Tests ===")
	test_logger_tag_operations()
	test_tag_category_transitions()
	test_tag_validation_and_filtering()
	print("=== Tag Operations Tests Complete ===\n")

# Test tag operations in the Logger class
func test_logger_tag_operations():
	print("\nTesting Logger tag operations:")
	
	var logger = Logger.new()
	
	# Clear any existing tags
	logger.clear_tags()
	logger.clear_ignored_tags()
	
	# Test adding active tags
	var add_result1 = logger.add_tag("network")
	var add_result2 = logger.add_tag("database")
	var add_result3 = logger.add_tag("") # Should fail
	
	print("- Add valid tag 'network': %s %s" % [
		add_result1 == OK, 
		"✓" if add_result1 == OK else "✗"
	])
	
	print("- Add valid tag 'database': %s %s" % [
		add_result2 == OK, 
		"✓" if add_result2 == OK else "✗"
	])
	
	print("- Add invalid empty tag: %s %s" % [
		add_result3 != OK, 
		"✓" if add_result3 != OK else "✗"
	])
	
	print("- Active tags count after adding: %d (expected 2) %s" % [
		logger._active_tags.size(),
		"✓" if logger._active_tags.size() == 2 else "✗"
	])
	
	# Test adding the same tag again (should not duplicate)
	logger.add_tag("network")
	print("- Active tags count after adding duplicate: %d (expected 2) %s" % [
		logger._active_tags.size(),
		"✓" if logger._active_tags.size() == 2 else "✗"
	])
	
	# Test removing tags
	var remove_result1 = logger.remove_tag("network")
	var remove_result2 = logger.remove_tag("nonexistent")
	
	print("- Remove existing tag 'network': %s %s" % [
		remove_result1 == OK, 
		"✓" if remove_result1 == OK else "✗"
	])
	
	print("- Remove non-existent tag: %s %s" % [
		remove_result2 != OK, 
		"✓" if remove_result2 != OK else "✗"
	])
	
	print("- Active tags count after removal: %d (expected 1) %s" % [
		logger._active_tags.size(),
		"✓" if logger._active_tags.size() == 1 else "✗"
	])
	
	# Test clear tags
	logger.clear_tags()
	print("- Active tags after clear: %d (expected 0) %s" % [
		logger._active_tags.size(),
		"✓" if logger._active_tags.size() == 0 else "✗"
	])
	
	# Test ignored tags functionality
	logger.add_ignored_tag("debug")
	logger.add_ignored_tag("verbose")
	
	print("- Ignored tags count after adding: %d (expected 2) %s" % [
		logger._ignored_tags.size(),
		"✓" if logger._ignored_tags.size() == 2 else "✗"
	])
	
	# Test removing ignored tag
	logger.remove_ignored_tag("debug")
	
	print("- Ignored tags count after removal: %d (expected 1) %s" % [
		logger._ignored_tags.size(),
		"✓" if logger._ignored_tags.size() == 1 else "✗"
	])
	
	# Test clear ignored tags
	logger.clear_ignored_tags()
	print("- Ignored tags after clear: %d (expected 0) %s" % [
		logger._ignored_tags.size(),
		"✓" if logger._ignored_tags.size() == 0 else "✗"
	])

# Test tag category transitions in LoggerDock
func test_tag_category_transitions():
	print("\nTesting tag category transitions:")
	
	var dock = LoggerDock.new()
	
	# Mock the UI components to avoid Godot scene dependencies
	dock._available_tags_list = ItemList.new()
	dock._tags_list = ItemList.new()
	dock._ignored_tags_list = ItemList.new()
	
	# Set up initial state
	dock._available_tags = ["network", "database", "cache", "performance"]
	dock._active_tags = []
	dock._ignored_tags = []
	
	# Test handling tag drag from Available to Active
	dock._handle_tag_drag("network", dock.SOURCE_AVAILABLE, dock.SOURCE_ACTIVE)
	
	print("- Move tag from Available → Active: %s %s" % [
		dock._active_tags.has("network"),
		"✓" if dock._active_tags.has("network") else "✗"
	])
	
	# Test handling tag drag from Available to Ignored
	dock._handle_tag_drag("database", dock.SOURCE_AVAILABLE, dock.SOURCE_IGNORED)
	
	print("- Move tag from Available → Ignored: %s %s" % [
		dock._ignored_tags.has("database"),
		"✓" if dock._ignored_tags.has("database") else "✗"
	])
	
	# Test handling tag drag from Active to Ignored
	dock._handle_tag_drag("network", dock.SOURCE_ACTIVE, dock.SOURCE_IGNORED)
	
	print("- Move tag from Active → Ignored: %s %s" % [
		!dock._active_tags.has("network") && dock._ignored_tags.has("network"),
		"✓" if !dock._active_tags.has("network") && dock._ignored_tags.has("network") else "✗"
	])
	
	# Test handling tag drag from Ignored to Active
	dock._handle_tag_drag("database", dock.SOURCE_IGNORED, dock.SOURCE_ACTIVE)
	
	print("- Move tag from Ignored → Active: %s %s" % [
		dock._active_tags.has("database") && !dock._ignored_tags.has("database"),
		"✓" if dock._active_tags.has("database") && !dock._ignored_tags.has("database") else "✗"
	])
	
	# Test handling tag drag from Active to Available (removing from Active)
	dock._handle_tag_drag("database", dock.SOURCE_ACTIVE, dock.SOURCE_AVAILABLE)
	
	print("- Move tag from Active → Available: %s %s" % [
		!dock._active_tags.has("database"),
		"✓" if !dock._active_tags.has("database") else "✗"
	])
	
	# Test handling tag drag from Ignored to Available (removing from Ignored)
	dock._handle_tag_drag("network", dock.SOURCE_IGNORED, dock.SOURCE_AVAILABLE)
	
	print("- Move tag from Ignored → Available: %s %s" % [
		!dock._ignored_tags.has("network"),
		"✓" if !dock._ignored_tags.has("network") else "✗"
	])

# Test tag validation and filtering integration
func test_tag_validation_and_filtering():
	print("\nTesting tag validation and filtering integration:")
	
	var logger = Logger.new()
	
	# Configure test tags
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_tag("network")
	logger.add_tag("database")
	logger.add_ignored_tag("debug")
	
	# Test cases
	var test_cases = [
		{
			"description": "Message with active tag",
			"message": "Database connected",
			"tags": ["database"],
			"expected": true
		},
		{
			"description": "Message with ignored tag",
			"message": "Debug information",
			"tags": ["debug"],
			"expected": false
		},
		{
			"description": "Message with mixed tags (active + ignored)",
			"message": "Debug database connection",
			"tags": ["database", "debug"],
			"expected": false
		},
		{
			"description": "Message with no matching active tags",
			"message": "Performance metrics",
			"tags": ["performance"],
			"expected": false
		},
		{
			"description": "Message with no tags",
			"message": "Generic message",
			"tags": [],
			"expected": false
		}
	]
	
	var results = []
	for case in test_cases:
		# Test if the message would be shown based on its tags
		var should_show = logger._should_show_tags(case.tags)
		var passed = should_show == case.expected
		
		results.append(passed)
		print("- %s: %s %s" % [
			case.description,
			"Would show" if should_show else "Would hide",
			"✓" if passed else "✗"
		])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Tag validation and filtering integration test: %s" % ("PASSED" if all_passed else "FAILED"))
