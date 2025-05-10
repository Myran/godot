@tool
class_name ConfigManager
extends RefCounted
## Centralized configuration manager for Advanced Logger
##
## Provides a single source of truth for configuration constants, values,
## and operations. Eliminates duplication across multiple files and
## provides a notification system for configuration changes.
##
## This is the primary access point for all configuration operations.
## Other classes should use this manager instead of directly accessing
## configuration files or using deprecated alternatives.
##
## Example usage:
## ```gdscript
## # Get the ConfigManager instance
## var config = ConfigManager.get_instance()
##
## # Get configuration values
## var level = config.get_log_level()
## var active_tags = config.get_active_tags()
##
## # Set configuration values
## config.set_log_level(Logger.LogLevel.INFO)
## config.set_show_timestamp(true)
##
## # Save changes
## config.save()
## ```

signal config_changed(section: String, key: String, value: Variant)

## Configuration file constants
## These are the centralized constants for all configuration operations.
## Using these constants instead of hardcoded strings ensures consistency
## across the codebase and simplifies future changes.

# Configuration file path
const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"

# Configuration section names
const SECTION_LOGGER: String = "logger"  ## Section for logger settings (log level, tags)
const SECTION_FORMAT: String = "format"  ## Section for formatting settings (timestamp, colors)
const SECTION_SETUPS: String = "tag_setups"  ## Section for tag setups/presets

# Configuration keys
const KEY_LOG_LEVEL: String = "log_level"  ## Key for log level setting
const KEY_ACTIVE_TAGS: String = "active_tags"  ## Key for active (filter) tags
const KEY_IGNORED_TAGS: String = "ignored_tags"  ## Key for ignored tags
const KEY_AVAILABLE_TAGS: String = "available_tags"  ## Key for all available tags
const KEY_SHOW_TIMESTAMP: String = "show_timestamp"  ## Key for timestamp display setting
const KEY_SHOW_TAGS: String = "show_tags"  ## Key for tags display setting
const KEY_USE_COLORS: String = "use_colors"  ## Key for color usage setting
const KEY_SHOW_SOURCE: String = "show_source"  ## Key for source info display setting
const KEY_BUFFER_SIZE: String = "buffer_size"  ## Key for buffer size setting
const KEY_ENABLE_BUFFER_DUMP: String = "enable_buffer_dump"  ## Key for buffer dump toggle
const KEY_SHOW_EDITOR_DEBUG: String = "show_editor_debug"  ## Key for showing editor debug prints toggle

# Default values used when config file is missing or incomplete
const DEFAULT_LOG_LEVEL: int = 1  ## Default log level (INFO)
const DEFAULT_SHOW_TIMESTAMP: bool = true  ## Default timestamp display (on)
const DEFAULT_SHOW_TAGS: bool = true  ## Default tags display (on)
const DEFAULT_USE_COLORS: bool = true  ## Default color usage (on)
const DEFAULT_SHOW_SOURCE: bool = true  ## Default source info display (on)
const DEFAULT_BUFFER_SIZE: int = 20    ## Default buffer size
const DEFAULT_ENABLE_BUFFER_DUMP: bool = true  ## Default buffer dump setting (enabled)
const DEFAULT_SHOW_EDITOR_DEBUG: bool = false  ## Default editor debug prints (disabled)

## Singleton pattern implementation
## This ensures that only one instance of ConfigManager exists throughout the application.
## Always use get_instance() to access the ConfigManager instead of creating a new instance.

static var _instance: ConfigManager = null
# Config file instance
var _config: ConfigFile = ConfigFile.new()
var _config_loaded: bool = false




## Get the singleton instance of ConfigManager
## This is the main access point for the ConfigManager.
## Returns: The shared ConfigManager instance
static func get_instance() -> ConfigManager:
	if _instance == null:
		_instance = ConfigManager.new()
	return _instance

## Cleanup function to properly free the singleton instance
static func cleanup() -> void:
	if _instance != null:
		# Clean up instance properly
		_instance.cleanup_instance()

		# Force free the instance if possible
		if is_instance_valid(_instance):
			if _instance._config:
				# Clear the ConfigFile instance
				_instance._config = null

			# Clear cached instance first
			var temp_instance = _instance
			_instance = null

			# Free the instance if it inherits from Object
			if temp_instance is Object and not temp_instance is RefCounted:
				temp_instance.free()
		else:
			_instance = null

func _init() -> void:
	_load_config()

## Loads the configuration file and handles version upgrades
## Returns: Error code from the load operation
func _load_config() -> Error:
	# On Android, try loading with different methods
	var result = Error.FAILED

	# First try the standard load
	result = _config.load(CONFIG_PATH)

	# If that fails on Android, try using FileAccess
	if result != OK and OS.get_name() == "Android":
		if FileAccess.file_exists(CONFIG_PATH):
			var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				result = _config.parse(content)
				file.close()
		else:
			# On Android, create default config if file doesn't exist
			_create_default_config()
			result = OK

	_config_loaded = result == OK or result == ERR_FILE_NOT_FOUND

	# Handle configuration version upgrades
	if result == OK:
		_upgrade_config_if_needed()

	return result

## Creates a default configuration in memory for Android
func _create_default_config() -> void:
	# Set default logger settings
	_config.set_value(SECTION_LOGGER, KEY_LOG_LEVEL, DEFAULT_LOG_LEVEL)
	_config.set_value(SECTION_LOGGER, KEY_ACTIVE_TAGS, [])
	_config.set_value(SECTION_LOGGER, KEY_IGNORED_TAGS, [])
	_config.set_value(SECTION_LOGGER, KEY_AVAILABLE_TAGS, [])
	_config.set_value(SECTION_LOGGER, KEY_BUFFER_SIZE, DEFAULT_BUFFER_SIZE)
	_config.set_value(SECTION_LOGGER, KEY_ENABLE_BUFFER_DUMP, DEFAULT_ENABLE_BUFFER_DUMP)

	# Set default format settings
	_config.set_value(SECTION_FORMAT, KEY_SHOW_TIMESTAMP, DEFAULT_SHOW_TIMESTAMP)
	_config.set_value(SECTION_FORMAT, KEY_SHOW_TAGS, DEFAULT_SHOW_TAGS)
	_config.set_value(SECTION_FORMAT, KEY_USE_COLORS, DEFAULT_USE_COLORS)
	_config.set_value(SECTION_FORMAT, KEY_SHOW_SOURCE, DEFAULT_SHOW_SOURCE)
	_config.set_value(SECTION_FORMAT, KEY_SHOW_EDITOR_DEBUG, DEFAULT_SHOW_EDITOR_DEBUG)

	# Set version marker
	_config.set_value("meta", "version", 1)

## Upgrades configuration format if needed
## This ensures backward compatibility with older config formats
func _upgrade_config_if_needed() -> void:
	# Check if config has a version marker
	if not _config.has_section_key("meta", "version"):
		# This is a pre-versioned config, upgrade to version 1

		# Migrate any old 'setups' section to 'tag_setups' if needed
		if _config.has_section("setups") and not _config.has_section(SECTION_SETUPS):
			var keys = _config.get_section_keys("setups")
			for key in keys:
				var value = _config.get_value("setups", key)
				_config.set_value(SECTION_SETUPS, key, value)

		# Add version marker
		_config.set_value("meta", "version", 1)

		# Save updated config
		save()
		print_rich("[color=#%s]Config upgraded to version 1[/color]" % LoggerColors.INFO_HTML)

## Gets a value from the configuration with fallback to default
## Parameters:
## - section: Configuration section name
## - key: Configuration key
## - default_value: Default value if key doesn't exist
##
## Returns: The stored value or default if not found
func get_value(section: String, key: String, default_value: Variant = null) -> Variant:
	if not _config_loaded:
		_load_config()

	return _config.get_value(section, key, default_value)

## Sets a value in the configuration and notifies listeners
## Parameters:
## - section: Configuration section name
## - key: Configuration key
## - value: Value to store
##
## Validates input values where appropriate and performs type checking
func set_value(section: String, key: String, value: Variant) -> void:
	if not _config_loaded:
		_load_config()

	# Validate certain known values before storing
	if section == SECTION_LOGGER and key == KEY_LOG_LEVEL:
		# Validate log level is within bounds
		if not (value is int and value >= 0 and value <= 4):
			push_warning("Invalid log level value: %s. Using default." % str(value))
			value = DEFAULT_LOG_LEVEL

	# Ensure array types are converted properly for certain keys
	if section == SECTION_LOGGER and (key == KEY_ACTIVE_TAGS or key == KEY_IGNORED_TAGS or key == KEY_AVAILABLE_TAGS):
		if not value is Array:
			push_warning("Non-array value for %s.%s. Converting to empty array." % [section, key])
			value = []

	# Format settings should be booleans
	if section == SECTION_FORMAT and (key == KEY_SHOW_TIMESTAMP or key == KEY_SHOW_TAGS or
			key == KEY_USE_COLORS or key == KEY_SHOW_SOURCE):
		if not value is bool:
			push_warning("Non-boolean value for %s.%s. Converting to default." % [section, key])
			# Use appropriate default based on key
			if key == KEY_SHOW_TIMESTAMP:
				value = DEFAULT_SHOW_TIMESTAMP
			elif key == KEY_SHOW_TAGS:
				value = DEFAULT_SHOW_TAGS
			elif key == KEY_USE_COLORS:
				value = DEFAULT_USE_COLORS
			elif key == KEY_SHOW_SOURCE:
				value = DEFAULT_SHOW_SOURCE

	_config.set_value(section, key, value)
	config_changed.emit(section, key, value)

## Saves the configuration to disk
## Returns: Error code from the save operation
func save() -> Error:
	# On Android, we can't save to res://, use user:// instead
	if OS.get_name() == "Android":
		var user_config_path = "user://advanced_logger_settings.cfg"
		return _config.save(user_config_path)

	# On desktop platforms, use standard save
	# Create directories if needed
	var dir_path = CONFIG_PATH.get_base_dir()
	var dir = DirAccess.open("res://")
	if not dir:
		return FileAccess.get_open_error()

	# Create directory path if it doesn't exist
	if not dir.dir_exists(dir_path):
		var current_path = "res://"
		for path_part in dir_path.trim_prefix("res://").split("/"):
			if path_part.is_empty():
				continue

			current_path = current_path.path_join(path_part)
			if not dir.dir_exists(current_path):
				dir.make_dir(current_path)

	return _config.save(CONFIG_PATH)

## Checks if the configuration has a specific key
## Parameters:
## - section: Configuration section name
## - key: Configuration key
##
## Returns: True if the key exists
func has_value(section: String, key: String) -> bool:
	if not _config_loaded:
		_load_config()

	return _config.has_section_key(section, key)

## Clears a section of the configuration
## Parameters:
## - section: Configuration section name to clear
##
## Returns: True if the section was found and cleared
func clear_section(section: String) -> bool:
	if not _config_loaded:
		_load_config()

	if not _config.has_section(section):
		return false

	# Get all keys in the section
	var keys = _config.get_section_keys(section)

	# Remove each key
	for key in keys:
		_config.set_value(section, key, null)

	return true

## Helper methods for common operations

func get_log_level() -> int:
	return get_value(SECTION_LOGGER, KEY_LOG_LEVEL, DEFAULT_LOG_LEVEL)

func set_log_level(level: int) -> void:
	set_value(SECTION_LOGGER, KEY_LOG_LEVEL, level)

func get_active_tags() -> Array[String]:
	var tags = get_value(SECTION_LOGGER, KEY_ACTIVE_TAGS, [])
	if tags is Array:
		var result: Array[String] = []
		for tag in tags:
			if tag is String and not _is_reserved_category_name(tag):
				result.append(tag)
		return result
	return []

func set_active_tags(tags: Array[String]) -> void:
	# Filter out any category names before saving
	var filtered_tags: Array[String] = []
	for tag in tags:
		if not _is_reserved_category_name(tag):
			filtered_tags.append(tag)

	set_value(SECTION_LOGGER, KEY_ACTIVE_TAGS, filtered_tags)

func get_ignored_tags() -> Array[String]:
	var tags = get_value(SECTION_LOGGER, KEY_IGNORED_TAGS, [])
	if tags is Array:
		var result: Array[String] = []
		for tag in tags:
			if tag is String and not _is_reserved_category_name(tag):
				result.append(tag)
		return result
	return []

# Helper function to check if a tag name is a reserved category name
func _is_reserved_category_name(tag: String) -> bool:
	if not tag is String:
		return false

	var lower_tag = tag.to_lower()
	return lower_tag == "available" or lower_tag == "active" or lower_tag == "ignored"

func set_ignored_tags(tags: Array[String]) -> void:
	# Filter out any category names before saving
	var filtered_tags: Array[String] = []
	for tag in tags:
		if not _is_reserved_category_name(tag):
			filtered_tags.append(tag)

	set_value(SECTION_LOGGER, KEY_IGNORED_TAGS, filtered_tags)

func get_available_tags() -> Array[String]:
	var tags = get_value(SECTION_LOGGER, KEY_AVAILABLE_TAGS, [])
	if tags is Array:
		var result: Array[String] = []
		for tag in tags:
			if tag is String and not _is_reserved_category_name(tag):
				result.append(tag)
		return result
	return []

func set_available_tags(tags: Array[String]) -> void:
	# Filter out any category names before saving
	var filtered_tags: Array[String] = []
	for tag in tags:
		if not _is_reserved_category_name(tag):
			filtered_tags.append(tag)

	set_value(SECTION_LOGGER, KEY_AVAILABLE_TAGS, filtered_tags)

func get_show_timestamp() -> bool:
	return get_value(SECTION_FORMAT, KEY_SHOW_TIMESTAMP, DEFAULT_SHOW_TIMESTAMP)

func set_show_timestamp(show: bool) -> void:
	set_value(SECTION_FORMAT, KEY_SHOW_TIMESTAMP, show)

func get_show_tags() -> bool:
	return get_value(SECTION_FORMAT, KEY_SHOW_TAGS, DEFAULT_SHOW_TAGS)

func set_show_tags(show: bool) -> void:
	set_value(SECTION_FORMAT, KEY_SHOW_TAGS, show)

func get_use_colors() -> bool:
	return get_value(SECTION_FORMAT, KEY_USE_COLORS, DEFAULT_USE_COLORS)

func set_use_colors(use: bool) -> void:
	set_value(SECTION_FORMAT, KEY_USE_COLORS, use)

func get_show_source() -> bool:
	return get_value(SECTION_FORMAT, KEY_SHOW_SOURCE, DEFAULT_SHOW_SOURCE)

func set_show_source(show: bool) -> void:
	set_value(SECTION_FORMAT, KEY_SHOW_SOURCE, show)

func get_buffer_size() -> int:
	return get_value(SECTION_LOGGER, KEY_BUFFER_SIZE, DEFAULT_BUFFER_SIZE)

func set_buffer_size(size: int) -> void:
	# Ensure buffer size is reasonable
	set_value(SECTION_LOGGER, KEY_BUFFER_SIZE, max(1, size))

func get_enable_buffer_dump() -> bool:
	return get_value(SECTION_LOGGER, KEY_ENABLE_BUFFER_DUMP, DEFAULT_ENABLE_BUFFER_DUMP)

func set_enable_buffer_dump(enable: bool) -> void:
	set_value(SECTION_LOGGER, KEY_ENABLE_BUFFER_DUMP, enable)

func get_show_editor_debug() -> bool:
	return get_value(SECTION_FORMAT, KEY_SHOW_EDITOR_DEBUG, DEFAULT_SHOW_EDITOR_DEBUG)

func set_show_editor_debug(show: bool) -> void:
	set_value(SECTION_FORMAT, KEY_SHOW_EDITOR_DEBUG, show)

## Gets a tag setup by name
## Parameters:
## - setup_name: Name of the tag setup
##
## Returns: Dictionary with the setup or empty Dictionary if not found
func get_tag_setup(setup_name: String) -> Dictionary:
	return get_value(SECTION_SETUPS, setup_name, {})

## Sets a tag setup
## Parameters:
## - setup_name: Name of the tag setup
## - setup_data: Dictionary containing setup data
func set_tag_setup(setup_name: String, setup_data: Dictionary) -> void:
	set_value(SECTION_SETUPS, setup_name, setup_data)

## Gets all tag setups
## Returns: Dictionary with all setups
func get_all_tag_setups() -> Dictionary:
	if not _config_loaded:
		_load_config()

	var result = {}
	if _config.has_section(SECTION_SETUPS):
		var setup_keys = _config.get_section_keys(SECTION_SETUPS)
		for setup_name in setup_keys:
			result[setup_name] = get_tag_setup(setup_name)

	return result

## Reset all settings to default values
## This does not affect tag setups
##
## Returns: Error code from the save operation
func reset_to_defaults() -> Error:
	# Clear existing sections first
	clear_section(SECTION_LOGGER)
	clear_section(SECTION_FORMAT)

	# Set defaults for logger settings
	set_log_level(DEFAULT_LOG_LEVEL)
	set_active_tags([])
	set_ignored_tags([])
	set_available_tags([])
	set_buffer_size(DEFAULT_BUFFER_SIZE)
	set_enable_buffer_dump(DEFAULT_ENABLE_BUFFER_DUMP)

	# Set defaults for format settings
	set_show_timestamp(DEFAULT_SHOW_TIMESTAMP)
	set_show_tags(DEFAULT_SHOW_TAGS)
	set_use_colors(DEFAULT_USE_COLORS)
	set_show_source(DEFAULT_SHOW_SOURCE)
	set_show_editor_debug(DEFAULT_SHOW_EDITOR_DEBUG)

	# Save the changes
	return save()

## Instance cleanup function to be called when the plugin is disabled
func cleanup_instance() -> void:
	# Disconnect any signals first
	if is_instance_valid(self):
		# Clear all signal connections
		var connections = get_signal_connection_list("config_changed")
		for connection in connections:
			disconnect("config_changed", connection["callable"])

	# Clear any references we hold
	if _config != null:
		# Clear the ConfigFile completely
		_config.clear()
		_config = null

	# Clear any other references
	_config_loaded = false
