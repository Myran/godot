@tool
class_name Logger extends Node
## Simple logging system with tags and levels

# Make sure dependencies are preloaded
const TagManager = preload("res://addons/advanced_logger/tag_manager.gd")
const ConfigManager = preload("res://addons/advanced_logger/config_manager.gd")

enum LogLevel { DEBUG, INFO, WARNING, ERROR, CRITICAL }

# Common tag constants
const TAG_DB: String = "database"
const TAG_CACHE: String = "cache"
const TAG_FIREBASE: String = "firebase"
const TAG_LOCAL: String = "local_data"
const TAG_ERROR: String = "error"
const TAG_NETWORK: String = "network"

# Reference the centralized color palette
const LEVEL_COLORS: Dictionary = {
	LogLevel.DEBUG: LoggerColors.DEBUG_COLOR,
	LogLevel.INFO: LoggerColors.INFO_COLOR,
	LogLevel.WARNING: LoggerColors.WARNING_COLOR,
	LogLevel.ERROR: LoggerColors.ERROR_COLOR,
	LogLevel.CRITICAL: LoggerColors.CRITICAL_COLOR
}

const LEVEL_HTML_COLORS: Dictionary = {
	LogLevel.DEBUG: LoggerColors.DEBUG_HTML,
	LogLevel.INFO: LoggerColors.INFO_HTML,
	LogLevel.WARNING: LoggerColors.WARNING_HTML,
	LogLevel.ERROR: LoggerColors.ERROR_HTML,
	LogLevel.CRITICAL: LoggerColors.CRITICAL_HTML
}

# Class variables
var _current_level: LogLevel = LogLevel.INFO
var _active_tags: Array[String] = []
var _ignored_tags: Array[String] = []
var _show_timestamp: bool = true
var _show_tags: bool = true
var _use_colors: bool = true
var _show_source: bool = true

# Config instance
var _config: ConfigManager = null


func _init() -> void:
	# Get the config instance
	_config = ConfigManager.get_instance()

	# Register for configuration changes
	if _config != null:
		_config.config_changed.connect(_on_config_changed)

	# Load settings
	_load_settings()

## Handles configuration changes
func _on_config_changed(section: String, key: String, value: Variant) -> void:
	# Update internal state when config changes
	if section == ConfigManager.SECTION_LOGGER:
		if key == ConfigManager.KEY_LOG_LEVEL:
			_current_level = value
		elif key == ConfigManager.KEY_ACTIVE_TAGS:
			_active_tags = value
		elif key == ConfigManager.KEY_IGNORED_TAGS:
			_ignored_tags = value
	elif section == ConfigManager.SECTION_FORMAT:
		if key == ConfigManager.KEY_SHOW_TIMESTAMP:
			_show_timestamp = value
		elif key == ConfigManager.KEY_SHOW_TAGS:
			_show_tags = value
		elif key == ConfigManager.KEY_USE_COLORS:
			_use_colors = value
		elif key == ConfigManager.KEY_SHOW_SOURCE:
			_show_source = value

## Loads settings from the ConfigManager
func _load_settings() -> void:
	# In test mode or no config available, use defaults
	if _config == null:
		return

	# General settings
	_current_level = _config.get_log_level()

	# Tags
	_active_tags = _config.get_active_tags()
	_ignored_tags = _config.get_ignored_tags()

	# Format settings
	_show_timestamp = _config.get_show_timestamp()
	_show_tags = _config.get_show_tags()
	_use_colors = _config.get_use_colors()
	_show_source = _config.get_show_source()


# Core logging methods
func debug(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if message.is_empty():
		push_warning("Empty log message provided")
		return
	_log(LogLevel.DEBUG, message, context, tags)


func info(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if message.is_empty():
		push_warning("Empty log message provided")
		return
	_log(LogLevel.INFO, message, context, tags)


func warning(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if message.is_empty():
		push_warning("Empty log message provided")
		return
	_log(LogLevel.WARNING, message, context, tags)


func error(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if message.is_empty():
		push_warning("Empty log message provided")
		return
	_log(LogLevel.ERROR, message, context, tags)


func critical(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if message.is_empty():
		push_warning("Empty log message provided")
		return
	_log(LogLevel.CRITICAL, message, context, tags)


# Internal logging function
func _log(level: LogLevel, message: String, context: Dictionary, tags: Array[String]) -> void:
	# Skip if level filtering prevents this message
	if level < _current_level:
		return

	# Validate tags and check if we should show the message
	var validated_tags := _validate_tags(tags)
	if not _should_show_tags(validated_tags):
		return

	# Get source information and output the log
	var source_info := _get_source_info()
	_output_log(level, message, context, validated_tags, source_info)


# Validate tags, returning only non-empty strings
func _validate_tags(tags: Array[String]) -> Array[String]:
	return TagManager.validate_tags(tags)


## Checks if a tag is valid (delegates to TagManager for consistent validation)
func _is_valid_tag(tag) -> bool:
	return TagManager.is_valid_tag(tag)


# Check if a log should be shown based on tags
func _should_show_tags(tags: Array) -> bool:
	return TagManager.should_show_tags(tags, _active_tags, _ignored_tags)


# Get source information (file, line, function)
func _get_source_info() -> Dictionary:
	var source_info: Dictionary = {"file": "unknown", "line": 0, "function": "unknown"}

	const FILE_KEY: String = "file"
	const LINE_KEY: String = "line"
	const FUNCTION_KEY: String = "function"
	const SOURCE_KEY: String = "source"

	var stack: Array = get_stack()
	if stack.is_empty():
		return source_info

	# Find the first stack frame that is NOT from the logger itself
	for frame in stack:
		if not frame.has(SOURCE_KEY):
			continue

		var source: String = frame.get(SOURCE_KEY)
		if not source.ends_with("logger.gd"):
			source_info[FILE_KEY] = source
			source_info[LINE_KEY] = int(frame.get(LINE_KEY, 0))
			source_info[FUNCTION_KEY] = String(frame.get(FUNCTION_KEY, "unknown"))
			break

	return source_info


# Format and output a log
func _output_log(
	level: LogLevel,
	message: String,
	context: Dictionary,
	tags: Array[String],
	source_info: Dictionary
) -> void:
	var parts: Array[String] = []

	# Constants for dictionary keys
	const FILE_KEY: String = "file"
	const LINE_KEY: String = "line"

	# Fixed width for log levels (padded to the width of "CRITICAL")
	const LOG_LEVEL_WIDTH: int = 5  # "CRITICAL" is 8 chars + 1 for spacing
	# Fixed width for tags section
	const TAGS_WIDTH: int = 10

	# Add timestamp if enabled
	if _show_timestamp:
		var dt: Dictionary = Time.get_datetime_dict_from_system()
		var timestamp: String = (
			"%04d-%02d-%02d %02d:%02d:%02d"
			% [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
		)

		if _use_colors:
			parts.append("[color=#%s]%s[/color]" % [LoggerColors.TIMESTAMP_HTML, timestamp])
		else:
			parts.append(timestamp)

	# Add log level with fixed width using padding helper
	var level_str: String = LogLevel.keys()[level]
	var padded_level: String = _pad_right(level_str, LOG_LEVEL_WIDTH)

	if _use_colors and LEVEL_HTML_COLORS.has(level):
		parts.append("[color=#%s]%s[/color]" % [LEVEL_HTML_COLORS[level], padded_level])
	else:
		parts.append(padded_level)

	# Add tags if enabled and present, with consistent spacing
	if _show_tags and not tags.is_empty():
		var tags_text: String = "[%s]" % ", ".join(tags)
		# Fixed width for tags section
		tags_text = _pad_right(tags_text, TAGS_WIDTH)

		if _use_colors:
			parts.append("[color=#%s]%s[/color]" % [LoggerColors.TAG_HTML, tags_text])
		else:
			parts.append(tags_text)
	elif _show_tags:
		# Add empty space to maintain alignment even when no tags
		parts.append(" ".repeat(TAGS_WIDTH))

	# Add message (always included)
	if _use_colors and LEVEL_HTML_COLORS.has(level):
		parts.append("[color=#%s]%s[/color]" % [LEVEL_HTML_COLORS[level], message])
	else:
		parts.append(message)

	# Add context if present
	if not context.is_empty():
		parts.append(str(context))

	if _show_source:
		var file_name: String = String(source_info.get(FILE_KEY, "unknown")).get_file()
		var line: int = int(source_info.get(LINE_KEY, 0))
		var source_text: String = "(%s:%d)" % [file_name, line]

		if _use_colors:
			parts.append("[color=#%s]%s[/color]" % [LoggerColors.TIMESTAMP_HTML, source_text])
		else:
			parts.append(source_text)

	# Output the formatted log
	print_rich(" ".join(parts))


## Helper function to pad a string to a specific width
## Returns the string padded with spaces to the specified width
func _pad_right(text: String, width: int) -> String:
	if text.length() >= width:
		return text

	# Use the more efficient String.pad_decimals method which adds spaces
	return text + " ".repeat(width - text.length())


# Settings methods
func set_level(level: LogLevel) -> Error:
	if level < LogLevel.DEBUG or level > LogLevel.CRITICAL:
		push_warning("Invalid log level: %d" % level)
		return Error.FAILED

	_current_level = level

	# Update config
	if _config != null:
		_config.set_log_level(level)

	return OK


func get_level() -> LogLevel:
	return _current_level


# Tag management
## Adds a tag to the active tags list
## Returns OK if successful, FAILED otherwise
func add_tag(tag: String) -> Error:
	if not _is_valid_tag(tag):
		push_warning("Cannot add empty tag")
		return Error.FAILED

	if not _active_tags.has(tag):
		_active_tags.append(tag)

	# Remove from ignored tags if present
	if _ignored_tags.has(tag):
		_ignored_tags.erase(tag)

	# Update both tag lists in config if available
	if _config != null:
		_config.set_active_tags(_active_tags)
		_config.set_ignored_tags(_ignored_tags)

	return OK


## Removes a tag from the active tags list
## Returns OK if successful, FAILED otherwise
func remove_tag(tag: String) -> Error:
	if not _is_valid_tag(tag):
		push_warning("Cannot remove empty tag")
		return Error.FAILED

	if _active_tags.has(tag):
		_active_tags.erase(tag)

		# Update tag list in config if available
		if _config != null:
			_config.set_active_tags(_active_tags)
		return OK

	return Error.FAILED  # Tag wasn't in the list


## Clears all active tags
func clear_tags() -> void:
	_active_tags.clear()

	# Update tag list in config if available
	if _config != null:
		_config.set_active_tags(_active_tags)


## Adds a tag to the ignored tags list
## Returns OK if successful, FAILED otherwise
func add_ignored_tag(tag: String) -> Error:
	if not _is_valid_tag(tag):
		push_warning("Cannot add empty ignored tag")
		return Error.FAILED

	if not _ignored_tags.has(tag):
		_ignored_tags.append(tag)

	# Remove from active tags if present
	if _active_tags.has(tag):
		_active_tags.erase(tag)

	# Update both tag lists in config if available
	if _config != null:
		_config.set_active_tags(_active_tags)
		_config.set_ignored_tags(_ignored_tags)

	return OK


## Removes a tag from the ignored tags list
## Returns OK if successful, FAILED otherwise
func remove_ignored_tag(tag: String) -> Error:
	if not _is_valid_tag(tag):
		push_warning("Cannot remove empty ignored tag")
		return Error.FAILED

	if _ignored_tags.has(tag):
		_ignored_tags.erase(tag)

		# Update tag list in config if available
		if _config != null:
			_config.set_ignored_tags(_ignored_tags)
		return OK

	return Error.FAILED  # Tag wasn't in the list


## Clears all ignored tags
func clear_ignored_tags() -> void:
	_ignored_tags.clear()

	# Update tag list in config if available
	if _config != null:
		_config.set_ignored_tags(_ignored_tags)


# Format settings
func set_show_timestamp(show: bool) -> void:
	_show_timestamp = show
	if _config != null:
		_config.set_show_timestamp(show)


func set_show_tags(show: bool) -> void:
	_show_tags = show
	if _config != null:
		_config.set_show_tags(show)


func set_use_colors(use: bool) -> void:
	_use_colors = use
	if _config != null:
		_config.set_use_colors(use)


func set_show_source(show: bool) -> void:
	_show_source = show
	if _config != null:
		_config.set_show_source(show)
