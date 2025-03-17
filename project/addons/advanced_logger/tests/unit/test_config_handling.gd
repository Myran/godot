@tool
extends Node
class_name TestConfigHandling

# This test validates the configuration handling
# Note: Updated to use ConfigManager directly instead of LoggerSettings

const TEST_CONFIG_PATH = "res://addons/advanced_logger/tests/test_settings.cfg"
var Logger = preload("res://addons/advanced_logger/core/logger.gd")
var ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")

func _ready():
	print("\n=== Running Configuration Handling Tests ===")
	setup_test_environment()
	test_config_constants_consistency()
	test_config_saving()
	test_config_loading()
	test_default_values()
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

# Test that configuration constants are properly defined
func test_config_constants_consistency():
	print("\nTesting configuration constants:")
	
	var tests = [
		{
			"description": "CONFIG_PATH",
			"config_manager": ConfigManager.CONFIG_PATH,
			"expected": "res://addons/advanced_logger/settings.cfg"
		},
		{
			"description": "SECTION_LOGGER",
			"config_manager": ConfigManager.SECTION_LOGGER,
			"expected": "logger"
		},
		{
			"description": "SECTION_FORMAT", 
			"config_manager": ConfigManager.SECTION_FORMAT,
			"expected": "format"
		},
		{
			"description": "KEY_LOG_LEVEL",
			"config_manager": ConfigManager.KEY_LOG_LEVEL,
			"expected": "log_level"
		},
		{
			"description": "KEY_ACTIVE_TAGS",
			"config_manager": ConfigManager.KEY_ACTIVE_TAGS,
			"expected": "active_tags"
		},
		{
			"description": "KEY_IGNORED_TAGS",
			"config_manager": ConfigManager.KEY_IGNORED_TAGS,
			"expected": "ignored_tags"
		},
		{
			"description": "KEY_SHOW_TIMESTAMP",
			"config_manager": ConfigManager.KEY_SHOW_TIMESTAMP,
			"expected": "show_timestamp"
		},
		{
			"description": "KEY_SHOW_TAGS",
			"config_manager": ConfigManager.KEY_SHOW_TAGS,
			"expected": "show_tags"
		},
		{
			"description": "KEY_USE_COLORS",
			"config_manager": ConfigManager.KEY_USE_COLORS,
			"expected": "use_colors"
		}
	]
	
	var results = []
	for test in tests:
		var actual = test.config_manager
		var expected = test.expected
		var passed = actual == expected
		results.append(passed)
		print("- %s | Value: %s | Expected: %s %s" % [
			test.description,
			actual,
			expected,
			"✓" if passed else "✗"
		])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Config constants test: %s" % ("PASSED" if all_passed else "FAILED"))

# Create a test config file
func _create_test_config():
	var config = ConfigFile.new()
	
	# Logger section
	config.set_value(ConfigManager.SECTION_LOGGER, ConfigManager.KEY_LOG_LEVEL, Logger.LogLevel.WARNING)
	config.set_value(ConfigManager.SECTION_LOGGER, ConfigManager.KEY_ACTIVE_TAGS, PackedStringArray(["network", "database"]))
	config.set_value(ConfigManager.SECTION_LOGGER, ConfigManager.KEY_IGNORED_TAGS, PackedStringArray(["debug"]))
	
	# Format section
	config.set_value(ConfigManager.SECTION_FORMAT, ConfigManager.KEY_SHOW_TIMESTAMP, false)
	config.set_value(ConfigManager.SECTION_FORMAT, ConfigManager.KEY_SHOW_TAGS, true)
	config.set_value(ConfigManager.SECTION_FORMAT, ConfigManager.KEY_USE_COLORS, true)
	
	config.save(TEST_CONFIG_PATH)
	return config

# Test configuration saving functionality
func test_config_saving():
	print("\nTesting configuration saving:")
	
	# Create a test config file
	var save_result = _create_test_config()
	
	# Verify the file exists now
	var file = FileAccess.open(TEST_CONFIG_PATH, FileAccess.READ)
	var file_exists = file != null
	
	if file:
		file.close()
	
	print("- Config file created: %s" % ("✓" if file_exists else "✗"))
	print("Config saving test: %s" % ("PASSED" if file_exists else "FAILED"))

# Test configuration loading functionality
func test_config_loading():
	print("\nTesting configuration loading:")
	
	# Create a test config first
	_create_test_config()
	
	# Create a logger instance
	var logger = Logger.new()
	
	# Save original config path
	var original_path = ConfigManager.CONFIG_PATH
	
	# Create a ConfigManager instance for loading
	var config_manager = ConfigManager.get_instance()
	
	# Override config path for testing
	var script = config_manager.get_script()
	script.get_script_constant_map()["CONFIG_PATH"] = TEST_CONFIG_PATH
	
	# Reload config from test path
	var load_result = config_manager._load_config()
	
	# Load settings into logger
	logger._config = config_manager
	logger._load_settings()
	
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
	
	# Restore original config path
	script.get_script_constant_map()["CONFIG_PATH"] = original_path
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Config loading test: %s" % ("PASSED" if all_passed else "FAILED"))

# Test default values when config is missing
func test_default_values():
	print("\nTesting default values:")
	
	# Remove test config if it exists
	var dir = DirAccess.open("res://addons/advanced_logger/tests/")
	if dir && dir.file_exists("test_settings.cfg"):
		dir.remove("test_settings.cfg")
	
	# Create a logger instance
	var logger = Logger.new()
	
	# Save original config path
	var original_path = ConfigManager.CONFIG_PATH
	
	# Create a ConfigManager instance for loading
	var config_manager = ConfigManager.get_instance()
	
	# Override config path for testing
	var script = config_manager.get_script()
	script.get_script_constant_map()["CONFIG_PATH"] = TEST_CONFIG_PATH
	
	# Reload config from test path (which doesn't exist, so defaults should be used)
	var load_result = config_manager._load_config()
	
	# Load settings into logger
	logger._config = config_manager
	logger._load_settings()
	
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
	
	# Restore original config path
	script.get_script_constant_map()["CONFIG_PATH"] = original_path
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Default values test: %s" % ("PASSED" if all_passed else "FAILED"))
