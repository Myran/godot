@tool
extends Node
class_name TestTagFiltering

# This test validates the tag filtering functionality
# which is currently implemented in the Logger._should_show_tags method

var Logger = preload("res://addons/advanced_logger/logger.gd")

func _ready():
	print("\n=== Running Tag Filtering Tests ===")
	test_empty_active_tags()
	test_active_tags_filtering()
	test_ignored_tags_filtering()
	test_combined_filtering()
	test_empty_message_tags()
	print("=== Tag Filtering Tests Complete ===\n")

# Create a Logger instance for testing
func create_logger_instance() -> Logger:
	var logger = Logger.new()
	# Reset state to make sure we're working with a clean instance
	logger._active_tags.clear()
	logger._ignored_tags.clear()
	return logger

# Test that when no active tags are set, all logs are shown (except ignored)
func test_empty_active_tags():
	print("\nTesting empty active tags (should show all logs):")
	
	var logger = create_logger_instance()
	
	var test_cases = [
		{"tags": [], "expected": true, "description": "Empty tags array"},
		{"tags": ["network"], "expected": true, "description": "Single tag"},
		{"tags": ["database", "cache"], "expected": true, "description": "Multiple tags"}
	]
	
	var results = []
	for case in test_cases:
		var should_show = logger._should_show_tags(case.tags)
		var passed = should_show == case.expected
		results.append(passed)
		print("- %s | Should show: %s | Expected: %s %s" % [
			case.description,
			should_show,
			case.expected,
			"✓" if passed else "✗"
		])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Empty active tags test: %s" % ("PASSED" if all_passed else "FAILED"))

# Test active tag filtering
func test_active_tags_filtering():
	print("\nTesting active tags filtering:")
	
	var logger = create_logger_instance()
	logger._active_tags.append("network")
	logger._active_tags.append("database")
	
	var test_cases = [
		{"tags": [], "expected": false, "description": "Empty tags array (no match)"},
		{"tags": ["network"], "expected": true, "description": "Single tag match"},
		{"tags": ["database"], "expected": true, "description": "Single tag match (other)"},
		{"tags": ["cache"], "expected": false, "description": "Single tag no match"},
		{"tags": ["network", "cache"], "expected": true, "description": "Multiple tags with one match"},
		{"tags": ["database", "network"], "expected": true, "description": "Multiple tags with all matching"},
		{"tags": ["cache", "performance"], "expected": false, "description": "Multiple tags with no matches"}
	]
	
	var results = []
	for case in test_cases:
		var should_show = logger._should_show_tags(case.tags)
		var passed = should_show == case.expected
		results.append(passed)
		print("- %s | Should show: %s | Expected: %s %s" % [
			case.description,
			should_show,
			case.expected,
			"✓" if passed else "✗"
		])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Active tags test: %s" % ("PASSED" if all_passed else "FAILED"))

# Test ignored tags filtering
func test_ignored_tags_filtering():
	print("\nTesting ignored tags filtering:")
	
	var logger = create_logger_instance()
	logger._ignored_tags.append("debug")
	logger._ignored_tags.append("verbose")
	
	var test_cases = [
		{"tags": [], "expected": true, "description": "Empty tags array (nothing to ignore)"},
		{"tags": ["network"], "expected": true, "description": "Single tag (not ignored)"},
		{"tags": ["debug"], "expected": false, "description": "Single tag (ignored)"},
		{"tags": ["network", "debug"], "expected": false, "description": "Multiple tags with one ignored"},
		{"tags": ["debug", "verbose"], "expected": false, "description": "Multiple tags, all ignored"},
		{"tags": ["cache", "network"], "expected": true, "description": "Multiple tags, none ignored"}
	]
	
	var results = []
	for case in test_cases:
		var should_show = logger._should_show_tags(case.tags)
		var passed = should_show == case.expected
		results.append(passed)
		print("- %s | Should show: %s | Expected: %s %s" % [
			case.description,
			should_show,
			case.expected,
			"✓" if passed else "✗"
		])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Ignored tags test: %s" % ("PASSED" if all_passed else "FAILED"))

# Test combined active and ignored tags filtering
func test_combined_filtering():
	print("\nTesting combined active and ignored tags filtering:")
	
	var logger = create_logger_instance()
	logger._active_tags.append("network")
	logger._active_tags.append("database")
	logger._ignored_tags.append("debug")
	logger._ignored_tags.append("verbose")
	
	var test_cases = [
		{"tags": [], "expected": false, "description": "Empty tags (no active match)"},
		{"tags": ["network"], "expected": true, "description": "Single active tag match"},
		{"tags": ["debug"], "expected": false, "description": "Single ignored tag match"},
		{"tags": ["network", "debug"], "expected": false, "description": "Active match but also ignored"},
		{"tags": ["database", "cache"], "expected": true, "description": "Active match with non-ignored tag"},
		{"tags": ["other"], "expected": false, "description": "No match in either list"}
	]
	
	var results = []
	for case in test_cases:
		var should_show = logger._should_show_tags(case.tags)
		var passed = should_show == case.expected
		results.append(passed)
		print("- %s | Should show: %s | Expected: %s %s" % [
			case.description,
			should_show,
			case.expected,
			"✓" if passed else "✗"
		])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Combined filtering test: %s" % ("PASSED" if all_passed else "FAILED"))

# Test when log message has no tags
func test_empty_message_tags():
	print("\nTesting empty message tags handling:")
	
	var logger1 = create_logger_instance()
	
	# With empty active tags (baseline)
	var result1 = logger1._should_show_tags([])
	print("- Empty message tags, empty active tags | Should show: %s | Expected: true %s" % [
		result1, 
		"✓" if result1 else "✗"
	])
	
	var logger2 = create_logger_instance()
	logger2._active_tags.append("network")
	logger2._active_tags.append("database")
	
	# With non-empty active tags (filter out if no match)
	var result2 = logger2._should_show_tags([])
	print("- Empty message tags, with active tags | Should show: %s | Expected: false %s" % [
		result2, 
		"✓" if result2 == false else "✗"
	])
	
	print("Empty message tags test: %s" % ("PASSED" if result1 == true && result2 == false else "FAILED"))
