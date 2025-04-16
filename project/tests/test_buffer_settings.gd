#!/usr/bin/env -S godot --headless --script
# Test script for the buffer settings functionality
# This can be run directly from the command line with:
# godot --headless --script test_buffer_settings.gd

extends SceneTree

func _init():
	print("\n========== BUFFER SETTINGS TEST ==========")
	
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
	
	print("\n--- TEST 1: Default Buffer Settings ---")
	# Check default settings
	print("  Default buffer size: %d" % logger.get_buffer_size())
	print("  Default enable buffer dump: %s" % str(logger.get_enable_buffer_dump()))
	
	# Generate some logs
	for i in range(5):
		logger.info("Test info message %d" % i)
	
	# Trigger an error to dump the buffer
	print("\n  Triggering error to test buffer dump (should show buffer):")
	logger.error("Test error message - should trigger buffer dump")
	
	print("\n--- TEST 2: Custom Buffer Size ---")
	# Change buffer size
	var custom_size = 5
	logger.set_buffer_size(custom_size)
	print("  Buffer size changed to: %d" % logger.get_buffer_size())
	
	# Generate logs to fill the buffer
	for i in range(10):
		logger.info("Test info message with custom buffer size %d" % i)
	
	# Trigger an error to dump the buffer (should only contain the last 5 messages)
	print("\n  Triggering error to test custom buffer size (should show only %d messages):" % custom_size)
	logger.error("Test error message with custom buffer size")
	
	print("\n--- TEST 3: Disable Buffer Dump ---")
	# Disable buffer dump
	logger.set_enable_buffer_dump(false)
	print("  Buffer dump disabled: %s" % str(logger.get_enable_buffer_dump()))
	
	# Generate some logs
	for i in range(3):
		logger.info("Test info message with buffer dump disabled %d" % i)
	
	# Trigger an error (should NOT dump the buffer)
	print("\n  Triggering error with buffer dump disabled (should NOT show buffer):")
	logger.error("Test error message - should NOT trigger buffer dump")
	
	# Re-enable buffer dump for cleanup
	logger.set_enable_buffer_dump(true)
	
	print("\n--- TEST 4: Config Persistence ---")
	# Reset to defaults to clean up after test
	config.set_buffer_size(ConfigManagerClass.DEFAULT_BUFFER_SIZE)
	config.set_enable_buffer_dump(ConfigManagerClass.DEFAULT_ENABLE_BUFFER_DUMP)
	print("  Settings reset to defaults for cleanup")
	
	print("\nTest complete!")
