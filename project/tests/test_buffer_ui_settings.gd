#!/usr/bin/env -S godot --headless --script
# Test script for the buffer UI settings
# This can be run directly from the command line with:
# godot --headless --script test_buffer_ui_settings.gd

extends SceneTree

func _init():
	print("\n========== BUFFER UI SETTINGS TEST ==========")
	
	# Test UI settings
	test_buffer_ui_settings()
	
	quit()

func test_buffer_ui_settings():
	print("\n----- Testing Buffer UI Settings -----")
	
	# Load required classes
	var ConfigManagerClass = load("res://addons/advanced_logger/utils/config_manager.gd")
	var SettingsTabControllerClass = load("res://addons/advanced_logger/ui/settings_tab_controller.gd")
	
	if ConfigManagerClass == null or SettingsTabControllerClass == null:
		print("❌ Failed to load required classes")
		return
	
	# Get config instance
	var config = ConfigManagerClass.get_instance()
	
	# Save original settings to restore later
	var original_size = config.get_buffer_size()
	var original_dump_enabled = config.get_enable_buffer_dump()
	print("  Original buffer size: %d" % original_size)
	print("  Original buffer dump enabled: %s" % str(original_dump_enabled))
	
	# Create mock UI elements
	var buffer_size_spin = SpinBox.new()
	var enable_buffer_dump_check = CheckBox.new()
	
	# Set initial values
	buffer_size_spin.value = original_size
	enable_buffer_dump_check.button_pressed = original_dump_enabled
	
	# Create settings controller (without parent dock)
	var tag_list_controller = null # We don't need this for testing
	var parent_dock = null # We don't need this for testing
	var settings_controller = SettingsTabControllerClass.new(config, tag_list_controller, parent_dock)
	
	# Simulate UI changes
	var test_size = 4
	var test_dump_enabled = !original_dump_enabled
	
	print("\n--- Simulating UI Changes ---")
	print("  Changing buffer size to: %d" % test_size)
	buffer_size_spin.value = test_size
	settings_controller._on_buffer_size_changed(test_size)
	
	print("  Changing buffer dump enabled to: %s" % str(test_dump_enabled))
	enable_buffer_dump_check.button_pressed = test_dump_enabled
	settings_controller._on_enable_buffer_dump_toggled(test_dump_enabled)
	
	# Check if config values were updated
	print("\n--- Verifying Config Changes ---")
	print("  Config buffer size after UI change: %d (should be %d)" % [config.get_buffer_size(), test_size])
	print("  Config buffer dump enabled after UI change: %s (should be %s)" % [str(config.get_enable_buffer_dump()), str(test_dump_enabled)])
	
	# Create a new logger to verify settings are applied
	var LoggerClass = load("res://addons/advanced_logger/core/logger.gd")
	var logger = LoggerClass.new()
	print("  New logger buffer size: %d (should be %d)" % [logger.get_buffer_size(), test_size])
	print("  New logger buffer dump enabled: %s (should be %s)" % [str(logger.get_enable_buffer_dump()), str(test_dump_enabled)])
	
	# Test buffer capacity
	print("\n--- Testing Buffer Capacity ---")
	for i in range(10):
		logger.info("Test message %d" % i)
	print("  Buffer size after adding messages: %d (should be %d)" % [logger._log_buffer.size(), test_size])
	
	# Clean up UI elements
	buffer_size_spin.queue_free()
	enable_buffer_dump_check.queue_free()
	
	# Restore original settings
	config.set_buffer_size(original_size)
	config.set_enable_buffer_dump(original_dump_enabled)
	print("\n  Settings restored to original values")
	
	print("\nBuffer UI settings test complete!")
