@tool
extends Node
class_name TestConfigHandling

# This test validates the configuration handling
# which is a key area for refactoring

const TEST_CONFIG_PATH = "res://addons/advanced_logger/tests/test_settings.cfg"
var Logger = preload("res://addons/advanced_logger/logger.gd")
var LoggerSettings = preload("res://addons/advanced_logger/logger_settings.gd")

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

# Test that configuration constants are consistent across files
func test_config_constants_consistency():
	print("\nTesting configuration constants consistency:")
	
	var tests = [
		{
			"description": "CONFIG_PATH",
			"logger": Logger.CONFIG_PATH, 
			"settings": LoggerSettings.CONFIG_PATH,
			"expected": true
		},
		{
			"description": "CONFIG_SECTION_LOGGER",
			"logger": Logger.CONFIG_SECTION_LOGGER, 
			"settings": LoggerSettings.CONFIG_SECTION_LOGGER,
			"expected": true
		},
		{
			"description": "CONFIG_SECTION_FORMAT",
			"logger": Logger.CONFIG_SECTION_FORMAT, 
			"settings": LoggerSettings.CONFIG_SECTION_FORMAT,
			"expected": true
		},
		{
			"description": "CONFIG_KEY_LOG_LEVEL",
			"logger": Logger.CONFIG_KEY_LOG_LEVEL, 
			"settings": LoggerSettings.CONFIG_KEY_LOG_LEVEL,
			"expected": true
		},
		{
			"description": "CONFIG_KEY_ACTIVE_TAGS",
			"logger": Logger.CONFIG_KEY_ACTIVE_TAGS, 
			"settings": LoggerSettings.CONFIG_KEY_ACTIVE_TAGS,
			"expected": true
		},
		{
			"description": "CONFIG_KEY_IGNORED_TAGS",
			"logger": Logger.CONFIG_KEY_IGNORED_TAGS, 
			"settings": LoggerSettings.CONFIG_KEY_IGNORED_TAGS,
			"expected": true
		},
		{
			"description": "CONFIG_KEY_SHOW_TIMESTAMP",
			"logger": Logger.CONFIG_KEY_SHOW_TIMESTAMP, 
			"settings": LoggerSettings.CONFIG_KEY_SHOW_TIMESTAMP,
			"expected": true
		},
		{
			"description": "CONFIG_KEY_SHOW_TAGS",
			"logger": Logger.CONFIG_KEY_SHOW_TAGS, 
			"settings": LoggerSettings.CONFIG_KEY_SHOW_TAGS,
			"expected": true
		},
		{
			"description": "CONFIG_KEY_USE_COLORS",
			"logger": Logger.CONFIG_KEY_USE_COLORS, 
			"settings": LoggerSettings.CONFIG_KEY_USE_COLORS,
			"expected": true
		}
	]
	
	var results = []
	for test in tests:
		var equal = test.logger == test.settings
		var passed = equal == test.expected
		results.append(passed)
		print("- %s | Equal: %s | Expected: %s %s" % [
			test.description,
			equal,
			test.expected,
			"✓" if passed else "✗"
		])
	
	var all_passed = true
	for result in results:
		if result == false:
			all_passed = false
			break
	print("Config constants consistency test: %s" % ("PASSED" if all_passed else "FAILED"))

# Create a test config file
func _create_test_config():
	var config = ConfigFile.new()
	
	# Logger section
	config.set_value(Logger.CONFIG_SECTION_LOGGER, Logger.CONFIG_KEY_LOG_LEVEL, Logger.LogLevel.WARNING)
	config.set_value(Logger.CONFIG_SECTION_LOGGER, Logger.CONFIG_KEY_ACTIVE_TAGS, PackedStringArray(["network", "database"]))
	config.set_value(Logger.CONFIG_SECTION_LOGGER, Logger.CONFIG_KEY_IGNORED_TAGS, PackedStringArray(["debug"]))
	
	# Format section
	config.set_value(Logger.CONFIG_SECTION_FORMAT, Logger.CONFIG_KEY_SHOW_TIMESTAMP, false)
	config.set_value(Logger.CONFIG_SECTION_FORMAT, Logger.CONFIG_KEY_SHOW_TAGS, true)
	config.set_value(Logger.CONFIG_SECTION_FORMAT, Logger.CONFIG_KEY_USE_COLORS, true)
	
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
	var original_path = Logger.CONFIG_PATH
	
	# Hack to load our test config (with reflection)
	var script = logger.get_script()
	script.get_script_constant_map()["CONFIG_PATH"] = TEST_CONFIG_PATH
	
	# Manually load the settings
	var load_result = LoggerSettings.load_settings(logger)
	
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
	var original_path = Logger.CONFIG_PATH
	
	# Hack to use our test config path (with reflection)
	var script = logger.get_script()
	script.get_script_constant_map()["CONFIG_PATH"] = TEST_CONFIG_PATH
	
	# Manually load settings (should use defaults)
	LoggerSettings.load_settings(logger)
	
	# Check the logger state matches the defaults
	var tests = [
		{
			"description": "Log level",
			"value": logger._current_level,
			"expected": Logger.DEFAULT_LOG_LEVEL
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
			"expected": Logger.DEFAULT_SHOW_TIMESTAMP
		},
		{
			"description": "Show tags",
			"value": logger._show_tags,
			"expected": Logger.DEFAULT_SHOW_TAGS
		},
		{
			"description": "Use colors",
			"value": logger._use_colors,
			"expected": Logger.DEFAULT_USE_COLORS
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
