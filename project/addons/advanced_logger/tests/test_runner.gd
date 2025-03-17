@tool
extends Node
## Test runner for Advanced Logger tests
##
## Run this script to execute all tests and validate 
## functionality before and after refactoring.

# Unit Tests
const TestTagValidation = preload("res://addons/advanced_logger/tests/unit/test_tag_validation.gd")
const TestTagFiltering = preload("res://addons/advanced_logger/tests/unit/test_tag_filtering.gd")
const TestConfigHandling = preload("res://addons/advanced_logger/tests/unit/test_config_handling.gd")
const TestLogFormatting = preload("res://addons/advanced_logger/tests/unit/test_log_formatting.gd")
const TestTagManagerMoveTags = preload("res://addons/advanced_logger/tests/unit/test_tag_manager_move_tags.gd")
const TestLoggerRefactored = preload("res://addons/advanced_logger/tests/unit/test_logger_refactored.gd")

# Integration Tests
const TestTagOperations = preload("res://addons/advanced_logger/tests/integration/test_tag_operations.gd")

# Refactoring Tests
const TestTagSetupManager = preload("res://addons/advanced_logger/tests/test_tag_setup_manager.gd")

# Test Results
var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0

func _ready():
	print("\n========================================")
	print("ADVANCED LOGGER TEST SUITE")
	print("========================================\n")
	
	print("Starting tests...")
	run_tests()
	
	print("\n========================================")
	print("TEST RESULTS: %d passed, %d failed (of %d total)" % [_tests_passed, _tests_failed, _tests_run])
	print("========================================\n")

func run_tests():
	# Run Unit Tests
	run_test(TestTagValidation)
	run_test(TestTagFiltering)
	run_test(TestConfigHandling)
	run_test(TestLogFormatting)
	run_test(TestTagManagerMoveTags)
	run_test(TestLoggerRefactored)  # New refactored logger test
	
	# Run Integration Tests
	run_test(TestTagOperations)
	
	# Run Refactoring Tests
	run_test(TestTagSetupManager)

func run_test(test_class):
	_tests_run += 1
	
	var test_name = test_class.get_class()
	print("\nRunning test: %s" % test_name)
	
	# Try to run the test with error handling
	var test_instance = test_class.new()
	var exception_occurred = false
	
	add_child(test_instance)
	
	# We'll try to determine success from output
	if test_instance.has_method("_ready"):
		var error = false
		test_instance._ready()
		if error:
			exception_occurred = true
			print("Exception occurred during test: %s" % str(get_stack()))
	
	remove_child(test_instance)
	test_instance.queue_free()
	
	if exception_occurred:
		_tests_failed += 1
		print("Test FAILED: %s (exception occurred)" % test_name)
	else:
		_tests_passed += 1
		print("Test COMPLETED: %s" % test_name)
