@tool
extends Node
class_name TestLoggerRefactored

# This test validates the refactored logger functionality
# specifically targeting methods that were split in Priority 4

var Logger = preload("res://addons/advanced_logger/core/logger.gd")

func _ready():
	print("\n=== Running Refactored Logger Tests ===")
	test_level_filtering()
	test_source_info_extraction()
	test_tag_management()
	test_validate_log_level()
	print("=== Refactored Logger Tests Complete ===\n")

# Create a Logger instance for testing
func create_logger_instance() -> Logger:
	var logger = Logger.new()
	# Reset state to make sure we're working with a clean instance
	logger._active_tags.clear()
	logger._ignored_tags.clear()
	return logger

# Test the level filtering logic
func test_level_filtering():
	print("\nTesting log level filtering:")
	
	var logger = create_logger_instance()
	logger._current_level = Logger.LogLevel.WARNING
	
	var test_cases = [
		{
			"level": Logger.LogLevel.DEBUG,
			"expected": true,
			"description": "DEBUG below WARNING (should filter)"
		},
		{
			"level": Logger.LogLevel.INFO,
			"expected": true, 
			"description": "INFO below WARNING (should filter)"
		},
		{
			"level": Logger.LogLevel.WARNING,
			"expected": false,
			"description": "WARNING matches threshold (should not filter)"
		},
		{
			"level": Logger.LogLevel.ERROR,
			"expected": false,
			"description": "ERROR above WARNING (should not filter)"
		},
		{
			"level": Logger.LogLevel.CRITICAL,
			"expected": false,
			"description": "CRITICAL above WARNING (should not filter)"
		}
	]
	
	var results = []
	for case in test_cases:
		var should_filter = logger._should_filter_by_level(case.level)
		var passed = should_filter == case.expected
		results.append(passed)
		print("- %s: Should filter=%s, Expected=%s %s" % [
			case.description,
			should_filter,
			case.expected,
			"✓" if passed else "✗"
		])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Level filtering test: %s" % ("PASSED" if all_passed else "FAILED"))

# Test source info extraction from stack
func test_source_info_extraction():
	print("\nTesting source info extraction:")
	
	var logger = create_logger_instance()
	
	# Create a synthetic stack for testing
	var test_stack = [
		{
			"file": "logger.gd",
			"line": 10,
			"function": "debug",
			"source": "res://addons/advanced_logger/core/logger.gd"
		},
		{
			"file": "logger.gd",
			"line": 50,
			"function": "_log",
			"source": "res://addons/advanced_logger/core/logger.gd"
		},
		{
			"file": "user_script.gd",
			"line": 25,
			"function": "some_function",
			"source": "res://user_script.gd"
		}
	]
	
	var result = logger._find_first_non_logger_frame(test_stack)
	
	var correct_file = result.get("file") == "res://user_script.gd"
	var correct_line = result.get("line") == 25
	var correct_function = result.get("function") == "some_function"
	
	print("- Extracted correct file: %s %s" % [
		correct_file,
		"✓" if correct_file else "✗"
	])
	
	print("- Extracted correct line: %s %s" % [
		correct_line,
		"✓" if correct_line else "✗"
	])
	
	print("- Extracted correct function: %s %s" % [
		correct_function,
		"✓" if correct_function else "✗"
	])
	
	# Test with empty stack
	var empty_result = logger._find_first_non_logger_frame([])
	var has_defaults = empty_result.get("file") == "unknown" && empty_result.get("line") == 0
	
	print("- Handles empty stack gracefully: %s %s" % [
		has_defaults,
		"✓" if has_defaults else "✗"
	])
	
	print("Source info extraction test: %s" % ("PASSED" if correct_file && correct_line && correct_function && has_defaults else "FAILED"))

# Test integrated tag management
func test_tag_management():
	print("\nTesting tag management:")
	
	var logger = create_logger_instance()
	
	# Test adding tags using the _manage_tag helper
	var result1 = logger._manage_tag("network", Logger.TAG_CATEGORY_ACTIVE)
	var result2 = logger._manage_tag("debug", Logger.TAG_CATEGORY_IGNORED)
	
	print("- Add tag to active list: %s %s" % [
		result1 == OK && logger._active_tags.has("network"),
		"✓" if result1 == OK && logger._active_tags.has("network") else "✗"
	])
	
	print("- Add tag to ignored list: %s %s" % [
		result2 == OK && logger._ignored_tags.has("debug"),
		"✓" if result2 == OK && logger._ignored_tags.has("debug") else "✗"
	])
	
	# Test moving tags between categories
	var result3 = logger._move_tag_between_categories("network", 
		Logger.TAG_CATEGORY_ACTIVE, Logger.TAG_CATEGORY_IGNORED)
	
	print("- Move tag from active to ignored: %s %s" % [
		result3 == OK && !logger._active_tags.has("network") && logger._ignored_tags.has("network"),
		"✓" if result3 == OK && !logger._active_tags.has("network") && logger._ignored_tags.has("network") else "✗"
	])
	
	# Test _create_available_tags_list
	var available_tags = logger._create_available_tags_list("new_tag")
	
	print("- Create available tags list: %s %s" % [
		available_tags.has("network") && available_tags.has("debug") && available_tags.has("new_tag"),
		"✓" if available_tags.has("network") && available_tags.has("debug") && available_tags.has("new_tag") else "✗"
	])
	
	print("Tag management test: %s" % ("PASSED" if result1 == OK && result2 == OK && result3 == OK else "FAILED"))

# Test log level validation
func test_validate_log_level():
	print("\nTesting log level validation:")
	
	var logger = create_logger_instance()
	
	var valid_levels = [
		Logger.LogLevel.DEBUG,
		Logger.LogLevel.INFO,
		Logger.LogLevel.WARNING,
		Logger.LogLevel.ERROR,
		Logger.LogLevel.CRITICAL
	]
	
	var invalid_levels = [
		-1,
		5,
		100
	]
	
	var results = []
	
	# Test valid levels
	for level in valid_levels:
		var is_valid = logger._is_valid_log_level(level)
		results.append(is_valid)
		print("- Level %d should be valid: %s %s" % [
			level,
			is_valid,
			"✓" if is_valid else "✗"
		])
	
	# Test invalid levels
	for level in invalid_levels:
		var is_valid = logger._is_valid_log_level(level)
		results.append(!is_valid)
		print("- Level %d should be invalid: %s %s" % [
			level,
			!is_valid,
			"✓" if !is_valid else "✗"
		])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	
	print("Log level validation test: %s" % ("PASSED" if all_passed else "FAILED"))
