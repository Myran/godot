#!/usr/bin/env -S godot --headless --script
# Debug test script for the buffer settings functionality
# This can be run directly from the command line with:
# godot --headless --script test_buffer_settings_debug.gd

extends SceneTree

func _init():
	print("\n========== BUFFER SETTINGS DEBUG TEST ==========")
	
	# Test buffer settings
	test_buffer_settings()
	
	quit()

func test_buffer_settings():
	print("\n----- Testing Buffer Settings -----")
	
	# Load ConfigManager and Logger classes
	var ConfigManagerClass = load("res://addons/advanced_logger/utils/config_manager.gd")
	var LoggerClass = load("res://addons/advanced_logger/core/logger.gd")
	if ConfigManagerClass == null or LoggerClass == null:
		print("  ❌ Failed to load required classes")
		return
		
	# Get config instance and create logger instance
	var config = ConfigManagerClass.get_instance()
	var logger = LoggerClass.new()
	
	if config == null or logger == null:
		print("  ❌ Failed to create required instances")
		return
	
	print("\n--- DEBUG INFO ---")
	print("  Original Config Buffer Size: %d" % config.get_buffer_size())
	print("  Original Logger Buffer Size: %d" % logger.get_buffer_size())
	print("  Original Logger Internal _buffer_size: %d" % logger._buffer_size)
	print("  Original Logger Buffer Array Size: %d" % logger._log_buffer.size())
	
	# Set a specific size through config
	print("\n--- Setting Buffer Size Through Config ---")
	var new_size = 3
	config.set_buffer_size(new_size)
	print("  Config Buffer Size After Change: %d" % config.get_buffer_size())
	print("  Logger Buffer Size After Config Change: %d" % logger.get_buffer_size())
	print("  Logger Internal _buffer_size After Config Change: %d" % logger._buffer_size)
	
	# Force the logger to reload settings
	print("\n--- Force Logger to Reload Settings ---")
	logger._load_settings()
	print("  Logger Buffer Size After Reload: %d" % logger.get_buffer_size())
	print("  Logger Internal _buffer_size After Reload: %d" % logger._buffer_size)
	
	# Check if _on_config_changed is being called
	print("\n--- Emitting config_changed Signal ---")
	config.config_changed.emit(ConfigManagerClass.SECTION_LOGGER, ConfigManagerClass.KEY_BUFFER_SIZE, new_size)
	print("  Logger Buffer Size After Signal: %d" % logger.get_buffer_size())
	print("  Logger Internal _buffer_size After Signal: %d" % logger._buffer_size)
	
	# Set the size directly on the logger
	print("\n--- Setting Size Directly on Logger ---")
	logger.set_buffer_size(new_size)
	print("  Logger Buffer Size After Direct Set: %d" % logger.get_buffer_size())
	print("  Logger Internal _buffer_size After Direct Set: %d" % logger._buffer_size)
	
	# Fill buffer and check size
	print("\n--- Filling Buffer and Checking Size ---")
	for i in range(10):
		logger.info("Test message %d" % i)
	print("  Logger Buffer Array Size After Filling: %d" % logger._log_buffer.size())
	
	# Trigger an error to dump buffer
	print("\n--- Triggering Error to Dump Buffer ---")
	logger.error("Test error message")
	
	print("\nTest complete!")
