#!/usr/bin/env -S godot --headless --script
# Test script for the fix to the level tag filtering bug with topic tags
# This can be run directly from the command line with:
# godot --headless --script test_level_tag_fix_with_topic_tags.gd

extends SceneTree

func _init():
	print("\n========== LEVEL TAG FILTERING WITH TOPIC TAGS FIX TEST ==========")
	
	# Test with the log level tag bug fix
	test_level_tag_filtering_with_topics()
	
	quit()

func test_level_tag_filtering_with_topics():
	print("\n----- Testing Level Tag Filtering with Topic Tags Fix -----")
	
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
	
	print("\nAll levels with various tags should show:")
	var database_tags: Array[String] = ["database"]
	var network_tags: Array[String] = ["network"]
	var cache_tags: Array[String] = ["cache"]
	var error_database_tags: Array[String] = ["error", "database"]
	var empty_tags: Array[String] = []
	
	logger.debug("Debug message with database tag", {}, database_tags)
	logger.info("Info message with network tag", {}, network_tags)
	logger.warning("Warning message with cache tag", {}, cache_tags)
	logger.error("Error message with multiple tags", {}, error_database_tags)
	logger.critical("Critical message with no tags", {}, empty_tags)
	
	print("\n--- TEST 2: With INFO as active level tag ---")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_tag("level:info")
	
	print("\nINFO and higher levels should show regardless of tags:")
	logger.debug("Debug message with database tag - should NOT show", {}, database_tags)
	logger.info("Info message with network tag - should show", {}, network_tags)
	logger.warning("Warning message with cache tag - should show", {}, cache_tags)
	logger.error("Error message with multiple tags - should show", {}, error_database_tags)
	logger.critical("Critical message with no tags - should show", {}, empty_tags)
	
	print("\n--- TEST 3: With ERROR as active level tag and database as active tag ---")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_tag("level:error")
	logger.add_tag("database")
	
	print("\nOnly ERROR and higher with database tag should show:")
	logger.debug("Debug message with database tag - should NOT show (level too low)", {}, database_tags)
	logger.info("Info message with network tag - should NOT show (wrong tag)", {}, network_tags)
	logger.info("Info message with database tag - should NOT show (level too low)", {}, database_tags)
	logger.warning("Warning message with cache tag - should NOT show (wrong tag)", {}, cache_tags)
	logger.warning("Warning message with database tag - should NOT show (level too low)", {}, database_tags)
	logger.error("Error message with network tag - should NOT show (wrong tag)", {}, network_tags)
	logger.error("Error message with database tag - should show", {}, database_tags)
	logger.critical("Critical message with no tags - should NOT show (no database tag)", {}, empty_tags)
	logger.critical("Critical message with database tag - should show", {}, database_tags)
	
	print("\n--- TEST 4: With WARNING as ignored level tag and database as ignored tag ---")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_ignored_tag("level:warning")
	logger.add_ignored_tag("database")
	
	print("\nAll levels except WARNING and messages with database tag should show:")
	logger.debug("Debug message - should NOT show (level too low)", {}, empty_tags)
	logger.info("Info message - should show", {}, empty_tags)
	logger.info("Info with database tag - should NOT show", {}, database_tags)
	logger.warning("Warning message - should NOT show", {}, empty_tags)
	logger.warning("Warning with network tag - should NOT show", {}, network_tags)
	logger.error("Error message - should show", {}, empty_tags)
	logger.error("Error with database tag - should NOT show", {}, database_tags)
	logger.critical("Critical message - should show", {}, empty_tags)
	
	# Disable debug logging
	logger.set_debug_filter_logging(false)
	print("\nTest complete!")
