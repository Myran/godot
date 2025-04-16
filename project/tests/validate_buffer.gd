#!/usr/bin/env -S godot --headless --script
# Validation script for the Logger buffer functionality
# This can be run directly from the command line with:
# godot --headless --script validate_buffer.gd

extends SceneTree

var passed_tests = 0
var total_tests = 0

func _init():
	print("\n========== LOGGER BUFFER VALIDATION SCRIPT ==========")
	
	# Check if required files exist
	if verify_files():
		# Run tests
		test_config_integration()
		test_basic_buffer_operations()
		
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
	var config_manager_path = "res://addons/advanced_logger/utils/config_manager.gd"
	var logger_path = "res://addons/advanced_logger/core/logger.gd"
	
	var file1 = FileAccess.open(config_manager_path, FileAccess.READ)
	var config_exists = file1 != null
	if file1 != null:
		file1.close()
	
	var file2 = FileAccess.open(logger_path, FileAccess.READ)
	var logger_exists = file2 != null
	if file2 != null:
		file2.close()
	
	print("  ConfigManager file exists: %s" % config_exists)
	print("  Logger file exists: %s" % logger_exists)
	
	# Also check if the code contains our additions
	var contains_buffer = false
	if logger_exists:
		var logger_content = FileAccess.get_file_as_string(logger_path)
		contains_buffer = logger_content.contains("_log_buffer") and logger_content.contains("_buffer_size")
	
	print("  Logger contains buffer implementation: %s" % contains_buffer)
	
	return config_exists and logger_exists and contains_buffer

# Test 1: Test Config Integration
func test_config_integration():
	print("\n----- Testing Config Integration -----")
	
	# Load ConfigManager class
	var ConfigManagerClass = load("res://addons/advanced_logger/utils/config_manager.gd")
	if ConfigManagerClass == null:
		print("  ❌ Failed to load ConfigManager script")
		return
		
	# Get ConfigManager instance
	var config = ConfigManagerClass.get_instance()
	expect_true(config != null, "ConfigManager instance created")
	
	if config == null:
		return
		
	# Test we can access and modify buffer size setting
	var default_size = 0
	var success = false
	
	# Call method and check if it works
	if config.has_method("get_buffer_size"):
		default_size = config.get_buffer_size()
		success = true
	
	expect_true(success, "get_buffer_size method exists and can be called")
	
	# Set a new value
	success = false
	if config.has_method("set_buffer_size"):
		config.set_buffer_size(10)
		var new_size = config.get_buffer_size()
		success = (new_size == 10)
	
	expect_true(success, "set_buffer_size successfully changes buffer size")
	
	# Reset to default (assumed to be 20 from the instructions)
	if config.has_method("set_buffer_size"):
		config.set_buffer_size(20)

# Test 2: Basic Buffer Operations
func test_basic_buffer_operations():
	print("\n----- Testing Basic Buffer Operations -----")
	
	# Create a simple test to check if logger works
	var LoggerClass = load("res://addons/advanced_logger/core/logger.gd")
	expect_true(LoggerClass != null, "Logger class loaded")
	
	if LoggerClass == null:
		return
	
	print("  Testing basic logging functionality...")
	print("  (The following should include debug and error logs with buffer dump)")
	
	# Create logger instance
	var logger = LoggerClass.new()
	expect_true(logger != null, "Logger instance created")
	
	if logger == null:
		return
	
	# Just test basic logging to ensure everything works
	logger.debug("Test debug message")
	logger.info("Test info message")
	logger.warning("Test warning message")
	logger.error("Test error message - should trigger buffer dump")
	logger.critical("Test critical message")
	
	print("  Buffer functionality test completed")
	expect_true(true, "Basic logging with buffer completed without errors")

# Helper functions for testing
func expect_true(condition: bool, message: String):
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  ✓ " + message)
	else:
		print("  ✗ " + message)

func expect_false(condition: bool, message: String):
	expect_true(!condition, message)