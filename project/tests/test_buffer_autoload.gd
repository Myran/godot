#!/usr/bin/env -S godot --headless --script
# Test script to check buffer settings with AutoLoad logger
# This can be run directly from the command line with:
# godot --headless --script test_buffer_autoload.gd

extends SceneTree

func _init():
	print("\n========== BUFFER AUTOLOAD TEST ==========")
	
	# Test with a custom logger registered as AutoLoad
	test_autoload_logger()
	
	quit()

func test_autoload_logger():
	print("\n----- Testing AutoLoad Logger Buffer -----")
	
	# Load the ConfigManager class
	var ConfigManagerClass = load("res://addons/advanced_logger/utils/config_manager.gd")
	if ConfigManagerClass == null:
		print("  ❌ Failed to load ConfigManager class")
		return
		
	# Load Logger class to create a test instance
	var LoggerClass = load("res://addons/advanced_logger/core/logger.gd")
	if LoggerClass == null:
		print("  ❌ Failed to load Logger class")
		return
	
	var config = ConfigManagerClass.get_instance()
	var test_logger = LoggerClass.new()
	
	print("\n--- Setting Buffer Size Using Config ---")
	var original_size = config.get_buffer_size()
	print("  Original config buffer size: %d" % original_size)
	print("  Test logger buffer size: %d" % test_logger.get_buffer_size())
	
	# Try modifying the buffer size
	var new_size = 5
	print("\n  Changing buffer size to: %d" % new_size)
	config.set_buffer_size(new_size)
	print("  Config buffer size after change: %d" % config.get_buffer_size())
	
	# Check if logger instance was updated
	print("  Test logger buffer size after config change: %d" % test_logger.get_buffer_size())
	
	# Force reload settings
	test_logger._load_settings()
	print("  Test logger buffer size after reload: %d" % test_logger.get_buffer_size())
	
	# Fill buffer with test messages
	print("\n--- Testing Buffer Size Limit ---")
	for i in range(10):
		test_logger.info("Test message %d" % i)
	print("  Current buffer size: %d (should be %d)" % [test_logger._log_buffer.size(), new_size])
	
	# Trigger error to dump buffer
	print("\n--- Dumping Buffer ---")
	test_logger.error("Test error to trigger buffer dump")
	
	# Restore original buffer size for cleanup
	print("\n--- Restoring Original Settings ---")
	config.set_buffer_size(original_size)
	print("  Buffer size restored to: %d" % config.get_buffer_size())
	
	print("\nTest complete!")
