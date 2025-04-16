#!/usr/bin/env -S godot --headless --script
# Test script for strict level tag filtering
# This can be run directly from the command line with:
# godot --headless --script test_level_tag_strict.gd

extends SceneTree

func _init():
	print("\n========== LEVEL TAG STRICT FILTERING TEST ==========")
	
	# Run test
	test_strict_level_tag_filtering()
	
	quit()

func test_strict_level_tag_filtering():
	print("\n----- Testing Strict Level Tag Filtering -----")
	
	# Load Logger class
	var LoggerClass = load("res://addons/advanced_logger/core/logger.gd")
	if LoggerClass == null:
		print("❌ Failed to load Logger class")
		return
		
	# Create logger instance
	var logger = LoggerClass.new()
	if logger == null:
		print("❌ Failed to create logger instance")
		return
	
	# Enable debug logging
	logger.set_debug_filter_logging(true)
	
	# Test with no active tags first (baseline)
	print("\n--- Test 1: No active level tags ---")
	logger.clear_tags()
	logger.clear_ignored_tags()
	
	print("  Logging messages of all levels:")
	logger.debug("Debug message with no active level tags")
	logger.info("Info message with no active level tags")
	logger.warning("Warning message with no active level tags")
	logger.error("Error message with no active level tags")
	logger.critical("Critical message with no active level tags")
	
	# Test with level:debug active
	print("\n--- Test 2: level:debug active ---")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_tag("level:debug")
	
	print("  Logging messages of all levels (only DEBUG should show):")
	logger.debug("Debug message with level:debug active")
	logger.info("Info message with level:debug active - should NOT show")
	logger.warning("Warning message with level:debug active - should NOT show")
	logger.error("Error message with level:debug active - should NOT show")
	logger.critical("Critical message with level:debug active - should NOT show")
	
	# Test with level:info active
	print("\n--- Test 3: level:info active ---")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_tag("level:info")
	
	print("  Logging messages of all levels (only INFO should show):")
	logger.debug("Debug message with level:info active - should NOT show")
	logger.info("Info message with level:info active")
	logger.warning("Warning message with level:info active - should NOT show")
	logger.error("Error message with level:info active - should NOT show")
	logger.critical("Critical message with level:info active - should NOT show")
	
	# Test with multiple level tags active
	print("\n--- Test 4: Multiple level tags active ---")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_tag("level:debug")
	logger.add_tag("level:error")
	
	print("  Logging messages of all levels (only DEBUG and ERROR should show):")
	logger.debug("Debug message with level:debug and level:error active")
	logger.info("Info message with level:debug and level:error active - should NOT show")
	logger.warning("Warning message with level:debug and level:error active - should NOT show")
	logger.error("Error message with level:debug and level:error active")
	logger.critical("Critical message with level:debug and level:error active - should NOT show")
	
	# Test with level:warning ignored
	print("\n--- Test 5: level:warning ignored ---")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_ignored_tag("level:warning")
	
	print("  Logging messages of all levels (all except WARNING should show):")
	logger.debug("Debug message with level:warning ignored")
	logger.info("Info message with level:warning ignored")
	logger.warning("Warning message with level:warning ignored - should NOT show")
	logger.error("Error message with level:warning ignored")
	logger.critical("Critical message with level:warning ignored")
	
	# Disable debug logging
	logger.set_debug_filter_logging(false)
	print("\nTest complete!")
