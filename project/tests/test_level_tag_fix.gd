#!/usr/bin/env -S godot --headless --script
# Test script for the fix to the level tag filtering bug
# This can be run directly from the command line with:
# godot --headless --script test_level_tag_fix.gd

extends SceneTree

func _init():
	print("\n========== LEVEL TAG FILTERING FIX TEST ==========")
	
	# Test with the log level tag bug fix
	test_level_tag_filtering()
	
	quit()

func test_level_tag_filtering():
	print("\n----- Testing Level Tag Filtering Fix -----")
	
	# Load Logger class and create instance
	var LoggerClass = load("res://addons/advanced_logger/core/logger.gd")
	if LoggerClass == null:
		print("  ❌ Failed to load Logger script")
		return
		
	var logger = LoggerClass.new()
	if logger == null:
		print("  ❌ Failed to create logger instance")
		return
	
	# Enable debug logging to see filtering decisions
	logger.set_debug_filter_logging(true)
	
	print("\n--- TEST 1: Default behavior (no level tag filters) ---")
	logger.clear_tags()
	logger.clear_ignored_tags()
	
	print("\nAll levels should show:")
	logger.debug("Debug message - should show with default settings")
	logger.info("Info message - should show with default settings")
	logger.warning("Warning message - should show with default settings")
	logger.error("Error message - should show with default settings")
	logger.critical("Critical message - should show with default settings")
	
	print("\n--- TEST 2: With INFO as active level tag ---")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_tag("level:info")
	
	print("\nINFO and higher levels should show:")
	logger.debug("Debug message - should NOT show with level:info active")
	logger.info("Info message - should show with level:info active")
	logger.warning("Warning message - should show with level:info active")
	logger.error("Error message - should show with level:info active")
	logger.critical("Critical message - should show with level:info active")
	
	print("\n--- TEST 3: With ERROR as active level tag ---")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_tag("level:error")
	
	print("\nERROR and higher levels should show:")
	logger.debug("Debug message - should NOT show with level:error active")
	logger.info("Info message - should NOT show with level:error active")
	logger.warning("Warning message - should NOT show with level:error active")
	logger.error("Error message - should show with level:error active")
	logger.critical("Critical message - should show with level:error active")
	
	print("\n--- TEST 4: With WARNING as ignored level tag ---")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_ignored_tag("level:warning")
	
	print("\nAll levels except WARNING should show:")
	logger.debug("Debug message - should show with level:warning ignored")
	logger.info("Info message - should show with level:warning ignored")
	logger.warning("Warning message - should NOT show with level:warning ignored")
	logger.error("Error message - should show with level:warning ignored")
	logger.critical("Critical message - should show with level:warning ignored")
	
	# Disable debug logging
	logger.set_debug_filter_logging(false)
	print("\nTest complete!")
