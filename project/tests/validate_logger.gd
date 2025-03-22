#!/usr/bin/env -S godot --headless --script
# Validation script for the Logger functionality
# This can be run directly from the command line with:
# godot --headless --script validate_logger.gd

extends SceneTree

const TEST_TAGS = ["test1", "test2", "debug", "network", "ui"]
var passed_tests = 0
var total_tests = 0

func _init():
	print("\n========== LOGGER VALIDATION SCRIPT ==========")
	
	# Check if required files exist
	if verify_files():
		# Run tests
		test_tag_validation()
		test_config_save_load()
		test_tag_filtering()
		
		# Print results
		if passed_tests == total_tests:
			print("\n✅ ALL TESTS PASSED: %d/%d" % [passed_tests, total_tests])
		else:
			print("\n❌ SOME TESTS FAILED: %d/%d passed" % [passed_tests, total_tests])
	else:
		print("\n❌ TEST SKIPPED: Required files not found")
	
	quit()
	
# Verify that required files exist
func verify_files() -> bool:
	print("\n----- Verifying Required Files -----")
	var logger_settings_path = "res://addons/advanced_logger/logger_settings.gd"
	var logger_path = "res://addons/advanced_logger/core/logger.gd"
	
	var file = FileAccess.open(logger_settings_path, FileAccess.READ)
	var settings_exists = file != null
	if file != null:
		file.close()
	
	var file2 = FileAccess.open(logger_path, FileAccess.READ)
	var logger_exists = file2 != null
	if file2 != null:
		file2.close()
	
	print("  Logger settings file exists: %s" % settings_exists)
	print("  Logger file exists: %s" % logger_exists)
	
	return settings_exists and logger_exists

# Test 1: Tag validation logic
func test_tag_validation():
	print("\n----- Testing Tag Validation -----")
	
	# Import the TagManager to test tag validation
	var TagManagerClass = load("res://addons/advanced_logger/utils/tag_manager.gd")
	if TagManagerClass == null:
		print("  ❌ Failed to load TagManager script")
		return
	
	# Valid tags
	expect_true(TagManagerClass.is_valid_tag("test"), "Simple tag validation")
	expect_true(TagManagerClass.is_valid_tag("test_tag"), "Tag with underscore")
	expect_true(TagManagerClass.is_valid_tag("test-tag"), "Tag with hyphen")
	expect_true(TagManagerClass.is_valid_tag("test123"), "Tag with numbers")
	
	# Level tags
	expect_true(TagManagerClass.is_valid_tag("level:debug"), "Level tag validation (with colon)")
	expect_true(TagManagerClass.is_level_tag("level:debug"), "Level tag recognition")
	expect_false(TagManagerClass.is_level_tag("debug"), "Regular tag not recognized as level tag")
	expect_false(TagManagerClass.is_valid_tag("level:"), "Empty level tag")
	
	# Invalid tags
	expect_false(TagManagerClass.is_valid_tag(""), "Empty tag")
	expect_false(TagManagerClass.is_valid_tag("test tag"), "Tag with space")
	expect_false(TagManagerClass.is_valid_tag("test.tag"), "Tag with period")
	expect_false(TagManagerClass.is_valid_tag("test!tag"), "Tag with special char")

# Test 2: Config save and load operations
func test_config_save_load():
	print("\n----- Testing Config Save/Load -----")
	
	# Create a temporary config file
	var config_path = "user://test_settings.cfg" # Use user:// instead of res:// for write access
	var config = ConfigFile.new()
	
	# Set some test values
	config.set_value("logger", "log_level", 1)
	config.set_value("logger", "active_tags", PackedStringArray(["test1", "test2"]))
	config.set_value("logger", "ignored_tags", PackedStringArray(["debug"]))
	config.set_value("logger", "available_tags", PackedStringArray(TEST_TAGS))
	
	# Save the config
	var save_result = config.save(config_path)
	expect_true(save_result == OK, "Config file saved")
	
	# Load the config
	var config2 = ConfigFile.new()
	var load_result = config2.load(config_path)
	expect_true(load_result == OK, "Config file loaded")
	
	# Check values
	expect_true(config2.get_value("logger", "log_level") == 1, "Config value preserved: log_level")
	
	var active_tags = config2.get_value("logger", "active_tags")
	expect_true(active_tags.size() == 2, "Active tags count correct")
	expect_true(active_tags[0] == "test1", "First active tag preserved")
	
	# Clean up - remove test config
	var dir = DirAccess.open("res://addons/advanced_logger/")
	if dir:
		dir.remove(config_path.get_file())

# Test 3: Tag filtering logic
func test_tag_filtering():
	print("\n----- Testing Tag Filtering Logic -----")
	
	# Create simulated logger instance to test filtering logic
	var Logger = load("res://addons/advanced_logger/core/logger.gd")
	if Logger == null:
		print("  ❌ Failed to load Logger script")
		return
	Logger = Logger.new()
	
	# Create properly typed arrays
	var empty_array: Array[String] = []
	var test1_array: Array[String] = ["test1"]
	var test2_array: Array[String] = ["test2"]
	var test1_test2_array: Array[String] = ["test1", "test2"]
	var debug_array: Array[String] = ["debug"]
	var test1_debug_array: Array[String] = ["test1", "debug"]
	
	# Case 1: No active tags, no ignored tags
	Logger.clear_tags()
	Logger.clear_ignored_tags()
	expect_true(Logger._should_show_tags(test1_array), "Show with no active or ignored tags")
	
	# Case 2: With active tags
	Logger.add_tag("test1")
	expect_true(Logger._should_show_tags(test1_array), "Show tag matching active tag")
	expect_false(Logger._should_show_tags(test2_array), "Hide tag not matching active tag")
	expect_true(Logger._should_show_tags(test1_test2_array), "Show message with one matching active tag")
	
	# Case 3: With ignored tags
	Logger.clear_tags()
	Logger.add_ignored_tag("debug")
	expect_true(Logger._should_show_tags(test1_array), "Show non-ignored tag")
	expect_false(Logger._should_show_tags(debug_array), "Hide ignored tag")
	expect_false(Logger._should_show_tags(test1_debug_array), "Hide message with one ignored tag")

# Helper functions
func expect_true(condition: bool, message: String):
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  ✓ " + message)
	else:
		print("  ✗ " + message)

func expect_false(condition: bool, message: String):
	expect_true(!condition, message)
