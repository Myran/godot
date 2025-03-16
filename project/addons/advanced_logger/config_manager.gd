@tool
class_name ConfigManager
extends RefCounted
## Centralized configuration manager for Advanced Logger
##
## Provides a single source of truth for configuration constants, values,
## and operations. Eliminates duplication across multiple files and
## provides a notification system for configuration changes.

signal config_changed(section: String, key: String, value: Variant)

# Centralized constants
const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"

# Section names
const SECTION_LOGGER: String = "logger"
const SECTION_FORMAT: String = "format"
const SECTION_SETUPS: String = "tag_setups"

# Keys
const KEY_LOG_LEVEL: String = "log_level"
const KEY_ACTIVE_TAGS: String = "active_tags"
const KEY_IGNORED_TAGS: String = "ignored_tags"
const KEY_AVAILABLE_TAGS: String = "available_tags"
const KEY_SHOW_TIMESTAMP: String = "show_timestamp"
const KEY_SHOW_TAGS: String = "show_tags"
const KEY_USE_COLORS: String = "use_colors"
const KEY_SHOW_SOURCE: String = "show_source"

# Default values
const DEFAULT_LOG_LEVEL: int = 1  # INFO level
const DEFAULT_SHOW_TIMESTAMP: bool = true
const DEFAULT_SHOW_TAGS: bool = true
const DEFAULT_USE_COLORS: bool = true
const DEFAULT_SHOW_SOURCE: bool = true

# Config file instance
var _config: ConfigFile = ConfigFile.new()
var _config_loaded: bool = false

# Singleton pattern
static var _instance: ConfigManager = null

static func get_instance() -> ConfigManager:
	if _instance == null:
		_instance = ConfigManager.new()
	return _instance

func _init() -> void:
	_load_config()

## Loads the configuration file
## Returns: Error code from the load operation
func _load_config() -> Error:
	var result = _config.load(CONFIG_PATH)
	_config_loaded = result == OK or result == ERR_FILE_NOT_FOUND
	return result

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
func set_value(section: String, key: String, value: Variant) -> void:
	if not _config_loaded:
		_load_config()
	
	_config.set_value(section, key, value)
	config_changed.emit(section, key, value)

## Saves the configuration to disk
## Returns: Error code from the save operation
func save() -> Error:
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
			if tag is String:
				result.append(tag)
		return result
	return []

func set_active_tags(tags: Array[String]) -> void:
	set_value(SECTION_LOGGER, KEY_ACTIVE_TAGS, tags)

func get_ignored_tags() -> Array[String]:
	var tags = get_value(SECTION_LOGGER, KEY_IGNORED_TAGS, [])
	if tags is Array:
		var result: Array[String] = []
		for tag in tags:
			if tag is String:
				result.append(tag)
		return result
	return []

func set_ignored_tags(tags: Array[String]) -> void:
	print_rich("[color=#%s]DEBUG: ConfigManager.set_ignored_tags: %s[/color]" % 
		[LoggerColors.DEBUG_HTML, tags])
	set_value(SECTION_LOGGER, KEY_IGNORED_TAGS, tags)

func get_available_tags() -> Array[String]:
	var tags = get_value(SECTION_LOGGER, KEY_AVAILABLE_TAGS, [])
	if tags is Array:
		var result: Array[String] = []
		for tag in tags:
			if tag is String:
				result.append(tag)
		return result
	return []

func set_available_tags(tags: Array[String]) -> void:
	set_value(SECTION_LOGGER, KEY_AVAILABLE_TAGS, tags)

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
