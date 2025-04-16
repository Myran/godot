#!/usr/bin/env -S godot --headless --script
# Thorough test script for the buffer functionality
# This can be run directly from the command line with:
# godot --headless --script test_buffer_thorough.gd

extends SceneTree

func _init():
	print("\n========== THOROUGH BUFFER TEST ==========")
	
	# Run multiple test cases
	test_buffer_internal_mechanics()
	test_buffer_capacity_limits()
	test_buffer_persistence()
	
	quit()

# Test 1: Internal buffer mechanics
func test_buffer_internal_mechanics():
	print("\n----- Testing Buffer Internal Mechanics -----")
	
	# Load required classes
	var LoggerClass = load("res://addons/advanced_logger/core/logger.gd")
	if LoggerClass == null:
		print("❌ Failed to load Logger class")
		return
		
	# Create test logger
	var logger = LoggerClass.new()
	
	# Test _add_to_buffer directly
	print("\n--- Testing _add_to_buffer Method ---")
	var test_entry = {
		"level": LoggerClass.LogLevel.INFO,
		"message": "Test message",
		"context": {},
		"tags": [],
		"source_info": {"file": "test.gd", "line": 10, "function": "test"}
	}
	
	# First clear the buffer
	logger._log_buffer.clear()
	print("  Initial buffer size: %d" % logger._log_buffer.size())
	
	# Add an entry
	logger._add_to_buffer(test_entry)
	print("  Buffer size after adding 1 entry: %d" % logger._log_buffer.size())
	
	# Test _trim_buffer directly
	print("\n--- Testing _trim_buffer Method ---")
	var original_buffer_size = logger._buffer_size
	
	# Add multiple entries to fill buffer
	for i in range(30):
		var entry = test_entry.duplicate(true)
		entry.message = "Test message %d" % i
		logger._add_to_buffer(entry)
	
	print("  Buffer size after adding 30 more entries: %d (should be %d)" % [logger._log_buffer.size(), original_buffer_size])
	
	# Set buffer size to a smaller value
	var new_size = 5
	logger._buffer_size = new_size
	print("  Changed internal _buffer_size to: %d" % logger._buffer_size)
	
	# Call trim directly
	logger._trim_buffer()
	print("  Buffer size after trim: %d (should be %d)" % [logger._log_buffer.size(), new_size])
	
	# Reset buffer size
	logger._buffer_size = original_buffer_size
	
	print("\nBuffer internal mechanics test complete!")

# Test 2: Buffer capacity limits
func test_buffer_capacity_limits():
	print("\n----- Testing Buffer Capacity Limits -----")
	
	# Load required classes
	var LoggerClass = load("res://addons/advanced_logger/core/logger.gd")
	var ConfigManagerClass = load("res://addons/advanced_logger/utils/config_manager.gd")
	if LoggerClass == null or ConfigManagerClass == null:
		print("❌ Failed to load required classes")
		return
		
	# Get config instance
	var config = ConfigManagerClass.get_instance()
	
	# Create test logger instances
	var logger1 = LoggerClass.new()
	var logger2 = LoggerClass.new()
	
	# Get original buffer size from config
	var original_size = config.get_buffer_size()
	print("  Original buffer size from config: %d" % original_size)
	
	# Set a new buffer size with direct call
	var test_size_1 = 3
	logger1.set_buffer_size(test_size_1)
	print("  Logger1 buffer size set to: %d" % logger1.get_buffer_size())
	
	# Set a different buffer size through config
	var test_size_2 = 7
	config.set_buffer_size(test_size_2)
	print("  Config buffer size set to: %d" % config.get_buffer_size())
	print("  Logger1 buffer size after config change: %d (should still be %d)" % [logger1.get_buffer_size(), test_size_1])
	print("  Logger2 buffer size after config change: %d (should be %d)" % [logger2.get_buffer_size(), test_size_2])
	
	# Force logger2 to reload settings
	logger2._load_settings()
	print("  Logger2 buffer size after reload: %d" % logger2.get_buffer_size())
	
	# Fill both buffers
	print("\n--- Filling buffers for both loggers ---")
	print("  Adding 10 messages to logger1 (buffer size: %d)" % logger1.get_buffer_size())
	for i in range(10):
		logger1.info("Logger1 test message %d" % i)
	
	print("  Adding 10 messages to logger2 (buffer size: %d)" % logger2.get_buffer_size())
	for i in range(10):
		logger2.info("Logger2 test message %d" % i)
		
	print("  Logger1 buffer size: %d (should be %d)" % [logger1._log_buffer.size(), test_size_1])
	print("  Logger2 buffer size: %d (should be %d)" % [logger2._log_buffer.size(), test_size_2])
	
	# Trigger error to dump both buffers
	print("\n--- Dumping both buffers ---")
	logger1.error("Logger1 error message")
	logger2.error("Logger2 error message")
	
	# Reset to original buffer size
	config.set_buffer_size(original_size)
	print("\n  Reset buffer size to original: %d" % config.get_buffer_size())
	
	print("\nBuffer capacity limits test complete!")

# Test 3: Buffer persistence
func test_buffer_persistence():
	print("\n----- Testing Buffer Persistence -----")
	
	# Load required classes
	var LoggerClass = load("res://addons/advanced_logger/core/logger.gd")
	var ConfigManagerClass = load("res://addons/advanced_logger/utils/config_manager.gd")
	if LoggerClass == null or ConfigManagerClass == null:
		print("❌ Failed to load required classes")
		return
		
	# Get config instance
	var config = ConfigManagerClass.get_instance()
	
	# Record original settings
	var original_size = config.get_buffer_size()
	var original_enable_dump = config.get_enable_buffer_dump()
	print("  Original buffer size: %d" % original_size)
	print("  Original buffer dump enabled: %s" % str(original_enable_dump))
	
	# Change settings temporarily
	var test_size = 4
	var test_dump_enabled = !original_enable_dump
	config.set_buffer_size(test_size)
	config.set_enable_buffer_dump(test_dump_enabled)
	print("  Changed buffer size to: %d" % config.get_buffer_size())
	print("  Changed buffer dump enabled to: %s" % str(config.get_enable_buffer_dump()))
	
	# Create a new logger to pick up these settings
	var logger = LoggerClass.new()
	print("  New logger buffer size: %d (should be %d)" % [logger.get_buffer_size(), test_size])
	print("  New logger buffer dump enabled: %s (should be %s)" % [str(logger.get_enable_buffer_dump()), str(test_dump_enabled)])
	
	# Add messages to fill buffer
	for i in range(10):
		logger.info("Test message %d" % i)
	
	print("  Buffer size after adding messages: %d (should be %d)" % [logger._log_buffer.size(), test_size])
	
	# Trigger an error to see if buffer is dumped
	print("\n--- Testing buffer dump with enabled=%s ---" % str(test_dump_enabled))
	logger.error("Test error message")
	
	# Reset to original settings
	config.set_buffer_size(original_size)
	config.set_enable_buffer_dump(original_enable_dump)
	print("\n  Reset to original settings: size=%d, dump_enabled=%s" % [original_size, str(original_enable_dump)])
	
	print("\nBuffer persistence test complete!")
