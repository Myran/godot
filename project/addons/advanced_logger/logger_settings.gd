@tool
class_name LoggerSettings
extends RefCounted
## Simple utility class for managing Logger settings

# Config constants - must match those in Logger and LoggerDock
const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"
const CONFIG_SECTION_LOGGER: String = "logger"
const CONFIG_SECTION_FORMAT: String = "format"
const CONFIG_KEY_LOG_LEVEL: String = "log_level"
const CONFIG_KEY_ACTIVE_TAGS: String = "active_tags"
const CONFIG_KEY_IGNORED_TAGS: String = "ignored_tags"
const CONFIG_KEY_AVAILABLE_TAGS: String = "available_tags"  # Added new config key
const CONFIG_KEY_SHOW_TIMESTAMP: String = "show_timestamp"
const CONFIG_KEY_SHOW_TAGS: String = "show_tags"
const CONFIG_KEY_USE_COLORS: String = "use_colors"
const CONFIG_KEY_SHOW_SOURCE: String = "show_source"
# Default values - must match Logger and LoggerDock
const DEFAULT_LOG_LEVEL: int = 1  # INFO level
const DEFAULT_SHOW_TIMESTAMP: bool = true
const DEFAULT_SHOW_TAGS: bool = true
const DEFAULT_USE_COLORS: bool = true
const DEFAULT_SHOW_SOURCE: bool = true

# In LoggerSettings.gd, add these methods:

# Project settings path format
const PROJECT_SETTINGS_PREFIX = "addons/advanced_logger/"


# Save to project settings instead of config file
static func save_to_project_settings(logger_instance: Logger) -> Error:
	if not logger_instance:
		push_error("Cannot save settings: logger instance is null")
		return Error.FAILED

	# Save logger settings
	ProjectSettings.set_setting(PROJECT_SETTINGS_PREFIX + "log_level", logger_instance.get_level())
	ProjectSettings.set_setting(
		PROJECT_SETTINGS_PREFIX + "active_tags", logger_instance._active_tags
	)
	ProjectSettings.set_setting(
		PROJECT_SETTINGS_PREFIX + "ignored_tags", logger_instance._ignored_tags
	)
	ProjectSettings.set_setting(
		PROJECT_SETTINGS_PREFIX + "show_timestamp", logger_instance._show_timestamp
	)
	ProjectSettings.set_setting(PROJECT_SETTINGS_PREFIX + "show_tags", logger_instance._show_tags)
	ProjectSettings.set_setting(PROJECT_SETTINGS_PREFIX + "use_colors", logger_instance._use_colors)
	ProjectSettings.set_setting(
		PROJECT_SETTINGS_PREFIX + "show_source", logger_instance._show_source
	)

	return ProjectSettings.save()


# Load from project settings instead of config file
static func load_from_project_settings(logger_instance: Logger) -> Error:
	if not logger_instance:
		push_error("Cannot load settings: logger instance is null")
		return Error.FAILED

	# Load logger settings with defaults
	var level = ProjectSettings.get_setting(
		PROJECT_SETTINGS_PREFIX + "log_level", DEFAULT_LOG_LEVEL
	)
	if level >= 0 and level < Logger.LogLevel.size():
		logger_instance.set_level(level)

	# Clear existing tags
	logger_instance.clear_tags()
	logger_instance.clear_ignored_tags()

	# Load tags
	var active_tags = ProjectSettings.get_setting(PROJECT_SETTINGS_PREFIX + "active_tags", [])
	for tag in active_tags:
		if _is_valid_tag(tag):
			logger_instance.add_tag(tag)

	var ignored_tags = ProjectSettings.get_setting(PROJECT_SETTINGS_PREFIX + "ignored_tags", [])
	for tag in ignored_tags:
		if _is_valid_tag(tag):
			logger_instance.add_ignored_tag(tag)

	var show_source = ProjectSettings.get_setting(
		PROJECT_SETTINGS_PREFIX + "show_source", DEFAULT_SHOW_SOURCE
	)
	logger_instance.set_show_source(show_source)

	# Load format settings
	var show_timestamp = ProjectSettings.get_setting(
		PROJECT_SETTINGS_PREFIX + "show_timestamp", DEFAULT_SHOW_TIMESTAMP
	)
	logger_instance.set_show_timestamp(show_timestamp)

	var show_tags = ProjectSettings.get_setting(
		PROJECT_SETTINGS_PREFIX + "show_tags", DEFAULT_SHOW_TAGS
	)
	logger_instance.set_show_tags(show_tags)

	var use_colors = ProjectSettings.get_setting(
		PROJECT_SETTINGS_PREFIX + "use_colors", DEFAULT_USE_COLORS
	)
	logger_instance.set_use_colors(use_colors)

	return OK


## Sets the logger settings from the config file to the logger instance
## Returns OK if successful, FAILED otherwise
static func load_settings(logger_instance: Logger) -> Error:
	if not logger_instance:
		push_error("Cannot load settings: logger instance is null")
		return Error.FAILED

	var config: ConfigFile = ConfigFile.new()
	var load_result: Error = config.load(CONFIG_PATH)

	# Use defaults if file doesn't exist or can't be loaded
	if load_result != OK:
		return OK

	# Validate required sections exist
	if (
		not config.has_section(CONFIG_SECTION_LOGGER)
		or not config.has_section(CONFIG_SECTION_FORMAT)
	):
		push_warning("Config file missing required sections")
		return OK

	if config.has_section_key(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_SOURCE):
		var show_source: bool = config.get_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_SOURCE)
		logger_instance.set_show_source(show_source)

	# Logger general settings
	if config.has_section_key(CONFIG_SECTION_LOGGER, CONFIG_KEY_LOG_LEVEL):
		var level: int = config.get_value(CONFIG_SECTION_LOGGER, CONFIG_KEY_LOG_LEVEL)
		if level >= 0 and level < Logger.LogLevel.size():
			logger_instance.set_level(level)

	# Clear existing tags
	logger_instance.clear_tags()
	logger_instance.clear_ignored_tags()

	# Tag settings
	if config.has_section_key(CONFIG_SECTION_LOGGER, CONFIG_KEY_ACTIVE_TAGS):
		var tags: PackedStringArray = config.get_value(
			CONFIG_SECTION_LOGGER, CONFIG_KEY_ACTIVE_TAGS
		)
		for tag in tags:
			if _is_valid_tag(tag):
				logger_instance.add_tag(tag)

	if config.has_section_key(CONFIG_SECTION_LOGGER, CONFIG_KEY_IGNORED_TAGS):
		var tags: PackedStringArray = config.get_value(
			CONFIG_SECTION_LOGGER, CONFIG_KEY_IGNORED_TAGS
		)
		for tag in tags:
			if _is_valid_tag(tag):
				logger_instance.add_ignored_tag(tag)

	# Format settings
	if config.has_section_key(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_TIMESTAMP):
		var show_timestamp: bool = config.get_value(
			CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_TIMESTAMP
		)
		logger_instance.set_show_timestamp(show_timestamp)

	if config.has_section_key(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_TAGS):
		var show_tags: bool = config.get_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_TAGS)
		logger_instance.set_show_tags(show_tags)

	if config.has_section_key(CONFIG_SECTION_FORMAT, CONFIG_KEY_USE_COLORS):
		var use_colors: bool = config.get_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_USE_COLORS)
		logger_instance.set_use_colors(use_colors)

	return OK


## Checks if a tag is valid
## 
## Tags must be non-empty strings and follow allowed naming conventions.
## - Cannot be empty
## - Must contain only alphanumeric characters, underscores, or hyphens
##
## Returns: true if valid, false otherwise
static func _is_valid_tag(tag: String) -> bool:
	if not (tag is String) or tag.is_empty():
		return false
		
	# Basic check - not empty
	var is_valid = not tag.is_empty()
	
	# Enhanced validation - alphanumeric, underscores, hyphens only
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_-]+$")
	return is_valid and regex.search(tag) != null
