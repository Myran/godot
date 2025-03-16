@tool
class_name LoggerSettings
extends RefCounted
## DEPRECATED: Compatibility wrapper for existing code
##
## This class is maintained only for backward compatibility with existing tests.
## New code should use ConfigManager directly instead.

# Make sure dependencies are preloaded
const TagManager = preload("res://addons/advanced_logger/utils/tag_manager.gd")
const ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")

# Add backward compatibility constants to avoid breaking tests
const CONFIG_PATH = ConfigManager.CONFIG_PATH
const CONFIG_SECTION_LOGGER = ConfigManager.SECTION_LOGGER
const CONFIG_SECTION_FORMAT = ConfigManager.SECTION_FORMAT
const CONFIG_KEY_LOG_LEVEL = ConfigManager.KEY_LOG_LEVEL
const CONFIG_KEY_ACTIVE_TAGS = ConfigManager.KEY_ACTIVE_TAGS
const CONFIG_KEY_IGNORED_TAGS = ConfigManager.KEY_IGNORED_TAGS
const CONFIG_KEY_AVAILABLE_TAGS = ConfigManager.KEY_AVAILABLE_TAGS
const CONFIG_KEY_SHOW_TIMESTAMP = ConfigManager.KEY_SHOW_TIMESTAMP
const CONFIG_KEY_SHOW_TAGS = ConfigManager.KEY_SHOW_TAGS
const CONFIG_KEY_USE_COLORS = ConfigManager.KEY_USE_COLORS
const CONFIG_KEY_SHOW_SOURCE = ConfigManager.KEY_SHOW_SOURCE
const DEFAULT_LOG_LEVEL = ConfigManager.DEFAULT_LOG_LEVEL
const DEFAULT_SHOW_TIMESTAMP = ConfigManager.DEFAULT_SHOW_TIMESTAMP
const DEFAULT_SHOW_TAGS = ConfigManager.DEFAULT_SHOW_TAGS
const DEFAULT_USE_COLORS = ConfigManager.DEFAULT_USE_COLORS
const DEFAULT_SHOW_SOURCE = ConfigManager.DEFAULT_SHOW_SOURCE

## Sets the logger settings from the ConfigManager to the logger instance
## Returns OK if successful, FAILED otherwise
static func load_settings(logger_instance: Logger) -> Error:
	if not logger_instance:
		push_error("Cannot load settings: logger instance is null")
		return Error.FAILED

	var config = ConfigManager.get_instance()

	# Load log level
	var level = config.get_log_level()
	if level >= 0 and level < Logger.LogLevel.size():
		logger_instance.set_level(level)

	# Clear existing tags
	logger_instance.clear_tags()
	logger_instance.clear_ignored_tags()

	# Load tags
	var active_tags = config.get_active_tags()
	for tag in active_tags:
		if TagManager.is_valid_tag(tag):
			logger_instance.add_tag(tag)

	var ignored_tags = config.get_ignored_tags()
	for tag in ignored_tags:
		if TagManager.is_valid_tag(tag):
			logger_instance.add_ignored_tag(tag)

	# Load format settings
	logger_instance.set_show_source(config.get_show_source())
	logger_instance.set_show_timestamp(config.get_show_timestamp())
	logger_instance.set_show_tags(config.get_show_tags())
	logger_instance.set_use_colors(config.get_use_colors())

	return OK

## Saves the logger settings to the config
## Returns OK if successful, FAILED otherwise
static func save_settings(logger_instance: Logger) -> Error:
	if not logger_instance:
		push_error("Cannot save settings: logger instance is null")
		return Error.FAILED

	var config = ConfigManager.get_instance()

	# Save log level
	config.set_log_level(logger_instance.get_level())

	# Save tags
	config.set_active_tags(logger_instance._active_tags)
	config.set_ignored_tags(logger_instance._ignored_tags)

	# Save format settings
	config.set_show_source(logger_instance._show_source)
	config.set_show_timestamp(logger_instance._show_timestamp)
	config.set_show_tags(logger_instance._show_tags)
	config.set_use_colors(logger_instance._use_colors)

	return config.save()

## Checks if a tag is valid
##
## Tags must be non-empty strings and follow allowed naming conventions.
## - Cannot be empty
## - Must contain only alphanumeric characters, underscores, or hyphens
##
## Returns: true if valid, false otherwise
static func _is_valid_tag(tag) -> bool:
	return TagManager.is_valid_tag(tag)
