@tool
extends Node

var ConfigManager = preload("res://addons/advanced_logger/config_manager.gd")
var Logger = preload("res://addons/advanced_logger/logger.gd")

func _ready():
	print("\n=== Running Refactoring Test ===")
	test_config_manager()
	test_logger_integration()
	print("=== Refactoring Test Complete ===\n")

func test_config_manager():
	print("\nTesting ConfigManager:")
	
	# Get the ConfigManager instance
	var config = ConfigManager.get_instance()
	
	# Test setting a value
	config.set_log_level(Logger.LogLevel.WARNING)
	var level = config.get_log_level()
	
	print("- Set log level to WARNING: %s %s" % [
		level == Logger.LogLevel.WARNING, 
		"✓" if level == Logger.LogLevel.WARNING else "✗"
	])
	
	# Test tag operations
	config.set_active_tags(["network", "database"])
	var tags = config.get_active_tags()
	
	print("- Set active tags: %s %s" % [
		tags.size() == 2 && tags.has("network") && tags.has("database"),
		"✓" if tags.size() == 2 && tags.has("network") && tags.has("database") else "✗"
	])
	
	# Test config saving
	var save_result = config.save()
	print("- Save config: %s %s" % [
		save_result == OK,
		"✓" if save_result == OK else "✗"
	])
	
func test_logger_integration():
	print("\nTesting Logger integration with ConfigManager:")
	
	# First set some config values
	var config = ConfigManager.get_instance()
	config.set_log_level(Logger.LogLevel.ERROR)
	config.set_active_tags(["test_tag"])
	config.set_ignored_tags(["debug"])
	config.set_show_timestamp(false)
	config.set_show_tags(false)
	config.save()
	
	# Now create a logger that should load these settings
	var logger = Logger.new()
	
	# Check if logger loaded the correct settings
	print("- Log level loaded correctly: %s %s" % [
		logger._current_level == Logger.LogLevel.ERROR,
		"✓" if logger._current_level == Logger.LogLevel.ERROR else "✗"
	])
	
	print("- Active tags loaded correctly: %s %s" % [
		logger._active_tags.size() == 1 && logger._active_tags.has("test_tag"),
		"✓" if logger._active_tags.size() == 1 && logger._active_tags.has("test_tag") else "✗"
	])
	
	print("- Ignored tags loaded correctly: %s %s" % [
		logger._ignored_tags.size() == 1 && logger._ignored_tags.has("debug"),
		"✓" if logger._ignored_tags.size() == 1 && logger._ignored_tags.has("debug") else "✗"
	])
