#!/usr/bin/env -S godot --headless --script
# Test script for level tag filtering in Advanced Logger
extends SceneTree

func _init():
	print("\n========== LEVEL TAG FILTERING TEST ==========")
	
	# Load required classes
	var Logger = load("res://addons/advanced_logger/core/logger.gd")
	if not Logger:
		print("❌ ERROR: Could not load Logger class")
		quit(1)
	
	# Create a logger instance
	var logger = Logger.new()
	if not logger:
		print("❌ ERROR: Could not create Logger instance")
		quit(1)
		
	print("\n----- Testing Level Tag Filtering -----")
	
	# 1. Test basic log level threshold
	logger.set_level(Logger.LogLevel.WARNING)
	print("\nTest 1: Basic level threshold (WARNING)")
	logger.debug("This debug message should NOT be shown")
	logger.info("This info message should NOT be shown")
	logger.warning("This warning message should be shown")
	logger.error("This error message should be shown")
	
	# 2. Test level tag in active tags
	print("\nTest 2: Level tag in active tags (level:debug)")
	logger.clear_tags()
	logger.add_tag("level:debug")
	logger.debug("This debug message should be shown")
	logger.info("This info message should NOT be shown")
	logger.warning("This warning message should NOT be shown")
	
	# 3. Test level tag in ignored tags
	print("\nTest 3: Level tag in ignored tags (level:info)")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_ignored_tag("level:info")
	logger.debug("This debug message should be shown")
	logger.info("This info message should NOT be shown")
	logger.warning("This warning message should be shown")
	
	# 4. Test multiple level tags
	print("\nTest 4: Multiple level tags (level:error, level:critical)")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_tag("level:error")
	logger.add_tag("level:critical")
	logger.debug("This debug message should NOT be shown")
	logger.info("This info message should NOT be shown")
	logger.warning("This warning message should NOT be shown")
	logger.error("This error message should be shown")
	logger.critical("This critical message should be shown")
	
	# 5. Test level tags with regular tags
	print("\nTest 5: Level tags with regular tags")
	logger.clear_tags()
	logger.clear_ignored_tags()
	logger.add_tag("level:warning")
	logger.add_tag("network")
	logger.info("This info message with network tag should NOT be shown", {}, ["network"])
	logger.warning("This warning message with network tag should be shown", {}, ["network"])
	logger.warning("This warning message with database tag should be shown", {}, ["database"])
	
	print("\n========== TEST COMPLETE ==========")
	quit()
