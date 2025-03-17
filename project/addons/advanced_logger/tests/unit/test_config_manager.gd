@tool
extends Node
class_name TestConfigManager

# This test validates the enhanced ConfigManager functionality

var ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")
var Logger = preload("res://addons/advanced_logger/core/logger.gd")

func _ready():
	print("\n=== Running ConfigManager Tests ===")
	test_config_instance()
	test_validation()
	test_section_management()
	test_reset_to_defaults()
	test_upgrade_path()
	print("=== ConfigManager Tests Complete ===\n")

# Test getting a ConfigManager instance
func test_config_instance():
	print("\nTesting ConfigManager instance:")
	
	var config1 = ConfigManager.get_instance()
	var config2 = ConfigManager.get_instance()
	
	var singleton_works = config1 == config2
	print("- Singleton pattern works: %s %s" % [
		singleton_works,
		"✓" if singleton_works else "✗"
	])
	
	var instance_valid = config1 != null
	print("- Instance is valid: %s %s" % [
		instance_valid,
		"✓" if instance_valid else "✗"
	])
	
	print("ConfigManager instance test: %s" % ("PASSED" if singleton_works && instance_valid else "FAILED"))

# Test validation functionality
func test_validation():
	print("\nTesting value validation:")
	
	var config = ConfigManager.get_instance()
	
	# Create temporary config for testing
	var original_level = config.get_log_level()
	var original_show_timestamp = config.get_show_timestamp()
	
	# Test log level validation
	config.set_value(ConfigManager.SECTION_LOGGER, ConfigManager.KEY_LOG_LEVEL, "invalid")
	var validated_level = config.get_log_level()
	var level_validated = validated_level == ConfigManager.DEFAULT_LOG_LEVEL
	
	print("- Log level validation: %s %s" % [
		level_validated,
		"✓" if level_validated else "✗"
	])
	
	# Test format setting validation
	config.set_value(ConfigManager.SECTION_FORMAT, ConfigManager.KEY_SHOW_TIMESTAMP, "invalid")
	var validated_timestamp = config.get_show_timestamp()
	var timestamp_validated = validated_timestamp == ConfigManager.DEFAULT_SHOW_TIMESTAMP
	
	print("- Format setting validation: %s %s" % [
		timestamp_validated,
		"✓" if timestamp_validated else "✗"
	])
	
	# Test tag array validation
	config.set_value(ConfigManager.SECTION_LOGGER, ConfigManager.KEY_ACTIVE_TAGS, "not_an_array")
	var validated_tags = config.get_active_tags()
	var tags_validated = validated_tags is Array && validated_tags.is_empty()
	
	print("- Tag array validation: %s %s" % [
		tags_validated,
		"✓" if tags_validated else "✗"
	])
	
	# Restore original settings
	config.set_log_level(original_level)
	config.set_show_timestamp(original_show_timestamp)
	
	print("Validation test: %s" % ("PASSED" if level_validated && timestamp_validated && tags_validated else "FAILED"))

# Test section management
func test_section_management():
	print("\nTesting section management:")
	
	var config = ConfigManager.get_instance()
	
	# Save current state
	var original_level = config.get_log_level()
	var original_tags = config.get_active_tags()
	
	# Test section clearing
	config.set_log_level(Logger.LogLevel.DEBUG)
	config.set_active_tags(["test_tag"])
	
	# Clear the section
	var cleared = config.clear_section(ConfigManager.SECTION_LOGGER)
	
	# Check if values are cleared and defaults are returned
	var level_reset = config.get_log_level() == ConfigManager.DEFAULT_LOG_LEVEL
	var tags_reset = config.get_active_tags().is_empty()
	
	print("- Section cleared: %s %s" % [
		cleared,
		"✓" if cleared else "✗"
	])
	
	print("- Log level reset to default: %s %s" % [
		level_reset,
		"✓" if level_reset else "✗"
	])
	
	print("- Tags reset to empty: %s %s" % [
		tags_reset,
		"✓" if tags_reset else "✗"
	])
	
	# Restore original values
	config.set_log_level(original_level)
	config.set_active_tags(original_tags)
	
	print("Section management test: %s" % ("PASSED" if cleared && level_reset && tags_reset else "FAILED"))

# Test reset to defaults
func test_reset_to_defaults():
	print("\nTesting reset to defaults:")
	
	var config = ConfigManager.get_instance()
	
	# Save current state
	var original_level = config.get_log_level()
	var original_show_timestamp = config.get_show_timestamp()
	var original_active_tags = config.get_active_tags()
	var original_ignored_tags = config.get_ignored_tags()
	
	# Make some changes
	config.set_log_level(Logger.LogLevel.CRITICAL)
	config.set_show_timestamp(false)
	config.set_active_tags(["test_tag1", "test_tag2"])
	config.set_ignored_tags(["ignore_tag"])
	
	# Reset to defaults
	var reset_result = config.reset_to_defaults()
	
	# Check if values were reset
	var level_reset = config.get_log_level() == ConfigManager.DEFAULT_LOG_LEVEL
	var timestamp_reset = config.get_show_timestamp() == ConfigManager.DEFAULT_SHOW_TIMESTAMP
	var active_tags_reset = config.get_active_tags().is_empty()
	var ignored_tags_reset = config.get_ignored_tags().is_empty()
	
	print("- Reset successful: %s %s" % [
		reset_result == OK,
		"✓" if reset_result == OK else "✗"
	])
	
	print("- Log level reset: %s %s" % [
		level_reset,
		"✓" if level_reset else "✗"
	])
	
	print("- Format settings reset: %s %s" % [
		timestamp_reset,
		"✓" if timestamp_reset else "✗"
	])
	
	print("- Tags reset: %s %s" % [
		active_tags_reset && ignored_tags_reset,
		"✓" if active_tags_reset && ignored_tags_reset else "✗"
	])
	
	# Restore original values
	config.set_log_level(original_level)
	config.set_show_timestamp(original_show_timestamp)
	config.set_active_tags(original_active_tags)
	config.set_ignored_tags(original_ignored_tags)
	
	print("Reset to defaults test: %s" % ("PASSED" if level_reset && timestamp_reset && active_tags_reset && ignored_tags_reset else "FAILED"))

# Test configuration upgrade path
func test_upgrade_path():
	print("\nTesting configuration upgrade path:")
	
	var config = ConfigManager.get_instance()
	
	# Check if version is present
	var has_version = config.has_value("meta", "version")
	print("- Config has version marker: %s %s" % [
		has_version,
		"✓" if has_version else "✗"
	])
	
	if has_version:
		var version = config.get_value("meta", "version")
		print("- Config version: %d" % version)
	
	# Check for 'setups' section (should have been migrated)
	var has_old_setups = config.has_value("setups", "default")
	var has_new_setups = config.has_value(ConfigManager.SECTION_SETUPS, "default")
	
	print("- Old 'setups' section not used: %s %s" % [
		!has_old_setups,
		"✓" if !has_old_setups else "✗"
	])
	
	print("- New 'tag_setups' section used: %s %s" % [
		has_new_setups,
		"✓" if has_new_setups else "✗"
	])
	
	print("Upgrade path test: %s" % ("PASSED" if has_version && !has_old_setups && has_new_setups else "NEEDS MANUAL VERIFICATION"))
