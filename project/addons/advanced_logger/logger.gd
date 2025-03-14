@tool
class_name Logger extends Node
## Simple logging system with tags and levels

enum LogLevel { DEBUG, INFO, WARNING, ERROR, CRITICAL }

# Config constants - must match those in LoggerDock

const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"
const CONFIG_SECTION_LOGGER: String = "logger"
const CONFIG_SECTION_FORMAT: String = "format"
const CONFIG_KEY_LOG_LEVEL: String = "log_level"
const CONFIG_KEY_ACTIVE_TAGS: String = "active_tags"
const CONFIG_KEY_IGNORED_TAGS: String = "ignored_tags"
const CONFIG_KEY_SHOW_TIMESTAMP: String = "show_timestamp"
const CONFIG_KEY_SHOW_TAGS: String = "show_tags"
const CONFIG_KEY_USE_COLORS: String = "use_colors"

# Default values
const DEFAULT_LOG_LEVEL: LogLevel = LogLevel.INFO
const DEFAULT_SHOW_TIMESTAMP: bool = true
const DEFAULT_SHOW_TAGS: bool = true
const DEFAULT_USE_COLORS: bool = true
const DEFAULT_SHOW_SOURCE: bool = true

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
var _current_level: LogLevel = DEFAULT_LOG_LEVEL
var _active_tags: Array[String] = []
var _ignored_tags: Array[String] = []
var _show_timestamp: bool = DEFAULT_SHOW_TIMESTAMP
var _show_tags: bool = DEFAULT_SHOW_TAGS
var _use_colors: bool = DEFAULT_USE_COLORS
var _show_source: bool = DEFAULT_SHOW_SOURCE


func _init() -> void:
	# Load settings on creation
	LoggerSettings.load_settings(self)

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
	var validated_tags: Array[String] = []
	for tag in tags:
		if _is_valid_tag(tag):
			validated_tags.append(tag)
	return validated_tags


## Checks if a tag is valid (delegates to LoggerSettings for consistent validation)
func _is_valid_tag(tag: String) -> bool:
	return LoggerSettings._is_valid_tag(tag)


# Check if a log should be shown based on tags
func _should_show_tags(tags: Array[String]) -> bool:
	# If tags are ignored, don't show
	for tag in tags:
		if tag is String and _ignored_tags.has(tag):
			return false

	# If no active tags are set, show all logs
	if _active_tags.is_empty():
		return true

	# If there are active tags but message has no tags, don't show
	if tags.is_empty():
		return false

	# Show if any message tag matches active tags
	for tag in tags:
		if tag is String and _active_tags.has(tag):
			return true

	return false


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

	# Add log level
	var level_str: String = LogLevel.keys()[level]
	if _use_colors and LEVEL_HTML_COLORS.has(level):
		parts.append("[color=#%s]%s[/color]" % [LEVEL_HTML_COLORS[level], level_str])
	else:
		parts.append(level_str)

	# Add tags if enabled and present
	if _show_tags and not tags.is_empty():
		var tags_text: String = "[%s]" % ", ".join(tags)
		if _use_colors:
			parts.append("[color=#%s]%s[/color]" % [LoggerColors.TAG_HTML, tags_text])
		else:
			parts.append(tags_text)

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


# Settings methods
func set_level(level: LogLevel) -> Error:
	if level < LogLevel.DEBUG or level > LogLevel.CRITICAL:
		push_warning("Invalid log level: %d" % level)
		return Error.FAILED

	_current_level = level
	return Error.OK


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

	return Error.OK


## Removes a tag from the active tags list
## Returns OK if successful, FAILED otherwise
func remove_tag(tag: String) -> Error:
	if not _is_valid_tag(tag):
		push_warning("Cannot remove empty tag")
		return Error.FAILED

	if _active_tags.has(tag):
		_active_tags.erase(tag)
		return Error.OK

	return Error.FAILED  # Tag wasn't in the list


## Clears all active tags
func clear_tags() -> void:
	_active_tags.clear()


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

	return Error.OK


## Removes a tag from the ignored tags list
## Returns OK if successful, FAILED otherwise
func remove_ignored_tag(tag: String) -> Error:
	if not _is_valid_tag(tag):
		push_warning("Cannot remove empty ignored tag")
		return Error.FAILED

	if _ignored_tags.has(tag):
		_ignored_tags.erase(tag)
		return Error.OK

	return Error.FAILED  # Tag wasn't in the list


## Clears all ignored tags
func clear_ignored_tags() -> void:
	_ignored_tags.clear()


# Format settings
func set_show_timestamp(show: bool) -> void:
	_show_timestamp = show


func set_show_tags(show: bool) -> void:
	_show_tags = show


func set_use_colors(use: bool) -> void:
	_use_colors = use


func set_show_source(show: bool) -> void:
	_show_source = show
