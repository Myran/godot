@tool
extends Node
class_name TestConfigHandlingNew

# This test validates the updated configuration handling system

const TEST_CONFIG_PATH = "res://addons/advanced_logger/tests/test_settings.cfg"
var Logger = preload("res://addons/advanced_logger/logger.gd")
var LoggerSettings = preload("res://addons/advanced_logger/logger_settings.gd")
var ConfigManager = preload("res://addons/advanced_logger/config_manager.gd")

func _ready():
	print("\n=== Running Configuration Handling Tests (Updated) ===")
	setup_test_environment()
	test_config_manager_singleton()
	test_config_saving()
	test_config_loading()
	test_default_values()
	test_config_notification()
	cleanup_test_environment()
	print("=== Configuration Handling Tests Complete ===\n")

func setup_test_environment():
	# Clean up any existing test config
	var dir = DirAccess.open("res://addons/advanced_logger/tests/")
	if dir && dir.file_exists("test_settings.cfg"):
		dir.remove("test_settings.cfg")

func cleanup_test_environment():
	# Remove test config
	var dir = DirAccess.open("res://addons/advanced_logger/tests/")
	if dir && dir.file_exists("test_settings.cfg"):
		dir.remove("test_settings.cfg")

# Test that the ConfigManager singleton works correctly
func test_config_manager_singleton():
	print("\nTesting ConfigManager singleton functionality:")
	
	var config1 = ConfigManager.get_instance()
	var config2 = ConfigManager.get_instance()
	
	var is_same_instance = config1 == config2
	print("- Singleton returns same instance: %s %s" % [
		is_same_instance,
		"✓" if is_same_instance else "✗"
	])
	
	print("ConfigManager singleton test: %s" % ("PASSED" if is_same_instance else "FAILED"))

# Create a test config file
func _create_test_config():
	var config = ConfigManager.get_instance()
	
	# Logger section
	config.set_value(ConfigManager.SECTION_LOGGER, ConfigManager.KEY_LOG_LEVEL, Logger.LogLevel.WARNING)
	config.set_value(ConfigManager.SECTION_LOGGER, ConfigManager.KEY_ACTIVE_TAGS, ["network", "database"])
	config.set_value(ConfigManager.SECTION_LOGGER, ConfigManager.KEY_IGNORED_TAGS, ["debug"])
	
	# Format section
	config.set_value(ConfigManager.SECTION_FORMAT, ConfigManager.KEY_SHOW_TIMESTAMP, false)
	config.set_value(ConfigManager.SECTION_FORMAT, ConfigManager.KEY_SHOW_TAGS, true)
	config.set_value(ConfigManager.SECTION_FORMAT, ConfigManager.KEY_USE_COLORS, true)
	
	# Use the ConfigManager.CONFIG_PATH
	config.save()
	return config

# Test configuration saving functionality
func test_config_saving():
	print("\nTesting configuration saving:")
	
	# Create a test config file
	var config = _create_test_config()
	
	# Verify the file exists now
	var file = FileAccess.open(ConfigManager.CONFIG_PATH, FileAccess.READ)
	var file_exists = file != null
	
	if file:
		file.close()
	
	print("- Config file created: %s" % ("✓" if file_exists else "✗"))
	print("Config saving test: %s" % ("PASSED" if file_exists else "FAILED"))

# Test configuration loading functionality
func test_config_loading():
	print("\nTesting configuration loading:")
	
	# Create a test config first with specific values
	var config = ConfigManager.get_instance()
	config.set_log_level(Logger.LogLevel.WARNING)
	config.set_active_tags(["network", "database"])
	config.set_ignored_tags(["debug"])
	config.set_show_timestamp(false)
	config.set_show_tags(true)
	config.set_use_colors(true)
	config.save()
	
	# Create a logger instance which should load from config
	var logger = Logger.new()
	
	# Check the logger state matches what we saved
	var tests = [
		{
			"description": "Log level",
			"value": logger._current_level,
			"expected": Logger.LogLevel.WARNING
		},
		{
			"description": "Active tags",
			"value": logger._active_tags.size(),
			"expected": 2
		},
		{
			"description": "Ignored tags",
			"value": logger._ignored_tags.size(),
			"expected": 1
		},
		{
			"description": "Show timestamp",
			"value": logger._show_timestamp,
			"expected": false
		},
		{
			"description": "Show tags",
			"value": logger._show_tags,
			"expected": true
		},
		{
			"description": "Use colors",
			"value": logger._use_colors,
			"expected": true
		}
	]
	
	var results = []
	for test in tests:
		var passed = test.value == test.expected
		results.append(passed)
		print("- %s | Value: %s | Expected: %s %s" % [
			test.description,
			test.value,
			test.expected,
			"✓" if passed else "✗"
		])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Config loading test: %s" % ("PASSED" if all_passed else "FAILED"))

# Test default values when config is missing
func test_default_values():
	print("\nTesting default values:")
	
	# Remove config file
	var dir = DirAccess.open("res://addons/advanced_logger/")
	if dir && dir.file_exists("settings.cfg"):
		dir.remove("settings.cfg")
	
	# Create a logger instance which should use defaults
	var logger = Logger.new()
	
	# Check the logger state matches the defaults
	var tests = [
		{
			"description": "Log level",
			"value": logger._current_level,
			"expected": ConfigManager.DEFAULT_LOG_LEVEL
		},
		{
			"description": "Active tags",
			"value": logger._active_tags.is_empty(),
			"expected": true
		},
		{
			"description": "Ignored tags",
			"value": logger._ignored_tags.is_empty(),
			"expected": true
		},
		{
			"description": "Show timestamp",
			"value": logger._show_timestamp,
			"expected": ConfigManager.DEFAULT_SHOW_TIMESTAMP
		},
		{
			"description": "Show tags",
			"value": logger._show_tags,
			"expected": ConfigManager.DEFAULT_SHOW_TAGS
		},
		{
			"description": "Use colors",
			"value": logger._use_colors,
			"expected": ConfigManager.DEFAULT_USE_COLORS
		}
	]
	
	var results = []
	for test in tests:
		var passed = test.value == test.expected
		results.append(passed)
		print("- %s | Value: %s | Expected: %s %s" % [
			test.description,
			test.value,
			test.expected,
			"✓" if passed else "✗"
		])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Default values test: %s" % ("PASSED" if all_passed else "FAILED"))

# Test config change notification
func test_config_notification():
	print("\nTesting config change notification:")
	
	var config = ConfigManager.get_instance()
	var notification_received = false
	var notified_section = ""
	var notified_key = ""
	var notified_value = null
	
	# Connect to the signal
	var callable = func(section, key, value):
		notification_received = true
		notified_section = section
		notified_key = key
		notified_value = value
	
	config.config_changed.connect(callable)
	
	# Make a change
	config.set_log_level(Logger.LogLevel.DEBUG)
	
	# Check if notification was received
	var tests = [
		{
			"description": "Notification received",
			"value": notification_received,
			"expected": true
		},
		{
			"description": "Correct section",
			"value": notified_section,
			"expected": ConfigManager.SECTION_LOGGER
		},
		{
			"description": "Correct key",
			"value": notified_key,
			"expected": ConfigManager.KEY_LOG_LEVEL
		},
		{
			"description": "Correct value",
			"value": notified_value,
			"expected": Logger.LogLevel.DEBUG
		}
	]
	
	var results = []
	for test in tests:
		var passed = test.value == test.expected
		results.append(passed)
		print("- %s | Value: %s | Expected: %s %s" % [
			test.description,
			test.value,
			test.expected,
			"✓" if passed else "✗"
		])
	
	# Disconnect the signal
	config.config_changed.disconnect(callable)
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Config notification test: %s" % ("PASSED" if all_passed else "FAILED"))
