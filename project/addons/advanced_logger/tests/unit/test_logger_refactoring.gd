@tool
extends Node
class_name TestLoggerRefactoring

# This test validates that the refactored Logger methods still work correctly

var Logger = preload("res://addons/advanced_logger/core/logger.gd")

func _ready():
	print("\n=== Running Logger Refactoring Tests ===")
	test_message_validation()
	test_level_filtering()
	test_source_info_extraction()
	test_tag_management_helpers()
	test_format_setting_updates()
	print("=== Logger Refactoring Tests Complete ===\n")

# Test message validation functionality
func test_message_validation():
	print("\nTesting message validation:")
	
	var logger = Logger.new()
	
	# Using direct method call to test internal method
	var valid_result = logger._validate_message("Valid message")
	print("- Valid message: %s %s" % [valid_result, "✓" if valid_result else "✗"])
	
	var invalid_result = logger._validate_message("")
	print("- Empty message: %s %s" % [!invalid_result, "✓" if !invalid_result else "✗"])
	
	print("Message validation test: %s" % ("PASSED" if valid_result && !invalid_result else "FAILED"))

# Test log level filtering
func test_level_filtering():
	print("\nTesting log level filtering:")
	
	var logger = Logger.new()
	logger._current_level = Logger.LogLevel.WARNING
	
	var tests = [
		{"level": Logger.LogLevel.DEBUG, "expected": false},
		{"level": Logger.LogLevel.INFO, "expected": false},
		{"level": Logger.LogLevel.WARNING, "expected": true},
		{"level": Logger.LogLevel.ERROR, "expected": true},
		{"level": Logger.LogLevel.CRITICAL, "expected": true}
	]
	
	var results = []
	for test in tests:
		var should_show = logger._should_show_level(test.level)
		var passed = should_show == test.expected
		results.append(passed)
		print("- Level %s: %s %s" % [
			Logger.LogLevel.keys()[test.level],
			should_show,
			"✓" if passed else "✗"
		])
	
	# Also test level validation
	var valid_level = logger._is_valid_level(Logger.LogLevel.INFO)
	var invalid_level = logger._is_valid_level(-1)
	var invalid_level2 = logger._is_valid_level(10)
	
	print("- Valid level: %s %s" % [valid_level, "✓" if valid_level else "✗"])
	print("- Below range level: %s %s" % [!invalid_level, "✓" if !invalid_level else "✗"])
	print("- Above range level: %s %s" % [!invalid_level2, "✓" if !invalid_level2 else "✗"])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
			
	all_passed = all_passed && valid_level && !invalid_level && !invalid_level2
	print("Level filtering test: %s" % ("PASSED" if all_passed else "FAILED"))

# Test source info extraction
func test_source_info_extraction():
	print("\nTesting source info extraction:")
	
	var logger = Logger.new()
	
	# Test default source info
	var default_info = logger._create_default_source_info()
	var has_default_values = default_info.has("file") && default_info.has("line") && default_info.has("function")
	print("- Default source info has required keys: %s %s" % [
		has_default_values,
		"✓" if has_default_values else "✗"
	])
	
	# Test find non-logger frame with empty stack
	var empty_stack = []
	var empty_result = logger._find_non_logger_frame(empty_stack)
	print("- Empty stack handled: %s %s" % [
		empty_result.is_empty(),
		"✓" if empty_result.is_empty() else "✗"
	])
	
	# Test stack frame extraction
	var frame = {
		"source": "test_file.gd",
		"line": 42,
		"function": "test_func"
	}
	var source_info = logger._create_default_source_info()
	logger._update_source_info_from_frame(source_info, frame)
	
	var extraction_correct = source_info.file == "test_file.gd" && source_info.line == 42 && source_info.function == "test_func"
	print("- Frame extraction: %s %s" % [
		extraction_correct,
		"✓" if extraction_correct else "✗"
	])
	
	print("Source info extraction test: %s" % ("PASSED" if has_default_values && empty_result.is_empty() && extraction_correct else "FAILED"))

# Test tag management helper methods
func test_tag_management_helpers():
	print("\nTesting tag management helpers:")
	
	var logger = Logger.new()
	logger._active_tags.clear()
	logger._ignored_tags.clear()
	
	# Test available tags list creation
	var available_tags = logger._create_available_tags_list("test_tag")
	var available_has_tag = available_tags.has("test_tag")
	print("- Available tags list creation: %s %s" % [
		available_has_tag,
		"✓" if available_has_tag else "✗"
	])
	
	# Test tag movement between categories
	logger._active_tags.append("active_tag")
	logger._ignored_tags.append("ignored_tag")
	
	var move_result = logger._move_tag_between_categories("active_tag", "active", "ignored")
	var move_successful = move_result == OK && !logger._active_tags.has("active_tag") && logger._ignored_tags.has("active_tag")
	print("- Move tag between categories: %s %s" % [
		move_successful,
		"✓" if move_successful else "✗"
	])
	
	# Test adding tag to category
	logger._active_tags.clear()
	logger._ignored_tags.clear()
	
	var add_result = logger._add_tag_to_category("test_tag", "active")
	var add_successful = add_result == OK && logger._active_tags.has("test_tag")
	print("- Add tag to category: %s %s" % [
		add_successful,
		"✓" if add_successful else "✗"
	])
	
	print("Tag management helpers test: %s" % ("PASSED" if available_has_tag && move_successful && add_successful else "FAILED"))

# Test format setting update methods
func test_format_setting_updates():
	print("\nTesting format setting updates:")
	
	var logger = Logger.new()
	
	# Mock the config manager to track updates
	var last_updated_key = ""
	var last_updated_value = null
	
	logger._config = {
		"set_value": func(section, key, value):
			last_updated_key = key
			last_updated_value = value
	}
	
	# Test timestamp update
	logger._update_format_setting("show_timestamp", true)
	var timestamp_update_correct = last_updated_key == "show_timestamp" && last_updated_value == true
	print("- Timestamp update: %s %s" % [
		timestamp_update_correct,
		"✓" if timestamp_update_correct else "✗"
	])
	
	# Test tags update
	logger._update_format_setting("show_tags", false)
	var tags_update_correct = last_updated_key == "show_tags" && last_updated_value == false
	print("- Tags update: %s %s" % [
		tags_update_correct,
		"✓" if tags_update_correct else "✗"
	])
	
	print("Format setting updates test: %s" % ("PASSED" if timestamp_update_correct && tags_update_correct else "FAILED"))
