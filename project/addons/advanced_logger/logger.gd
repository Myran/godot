@tool
class_name Logger extends Node
## Simple logging system with tags and levels

enum LogLevel { DEBUG, INFO, WARNING, ERROR, CRITICAL }

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

func _init() -> void:
	# Load settings on creation
	LoggerSettings.load_settings(self)

# Core logging methods
func debug(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if message.is_empty():
		push_warning("Empty log message provided")
	_log(LogLevel.DEBUG, message, context, tags)

func info(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if message.is_empty():
		push_warning("Empty log message provided")
	_log(LogLevel.INFO, message, context, tags)

func warning(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if message.is_empty():
		push_warning("Empty log message provided")
	_log(LogLevel.WARNING, message, context, tags)

func error(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if message.is_empty():
		push_warning("Empty log message provided")
	_log(LogLevel.ERROR, message, context, tags)

func critical(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if message.is_empty():
		push_warning("Empty log message provided")
	_log(LogLevel.CRITICAL, message, context, tags)

# Internal logging function
func _log(level: LogLevel, message: String, context: Dictionary, tags: Array[String]) -> void:
	# Validate level
	if level < LogLevel.DEBUG or level > LogLevel.CRITICAL:
		push_error("Invalid log level: " + str(level))
		level = LogLevel.INFO

	# Validate tags
	var validated_tags: Array[String] = []
	for tag in tags:
		if tag is String and not tag.is_empty():
			validated_tags.append(tag)

	# Get source information
	var source_info: Dictionary = _get_source_info()

	# Only show if it passes level and tag filters
	if level >= _current_level and _should_show_tags(validated_tags):
		_output_log(level, message, context, validated_tags, source_info)

# Check if a log should be shown based on tags
func _should_show_tags(tags: Array[String]) -> bool:
	if tags == null:
		push_error("Null tags array provided")
		return true

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

	var stack: Array = get_stack()
	if stack == null or stack.is_empty():
		return source_info

	# Find the first stack frame that is NOT from the logger itself
	for i in range(stack.size()):
		if i >= stack.size():
			break

		if not stack[i].has("source"):
			continue

		var source = stack[i].source
		if typeof(source) == TYPE_STRING and not String(source).ends_with("logger.gd"):
			source_info["file"] = source
			source_info["line"] = int(stack[i].line) if stack[i].has("line") else 0
			source_info["function"] = String(stack[i].function) if stack[i].has("function") else "unknown"
			break

	return source_info

# Format and output a log
func _output_log(level: LogLevel, message: String, context: Dictionary, tags: Array[String], source_info: Dictionary) -> void:
	var parts: Array[String] = []

	# Add timestamp if enabled
	if _show_timestamp:
		var dt: Dictionary = Time.get_datetime_dict_from_system()
		var timestamp: String = "%04d-%02d-%02d %02d:%02d:%02d" % [
			dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second
		]

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
		var context_text: String = str(context)
		parts.append(context_text)

	# Add source information
	var file_name: String = String(source_info.get("file", "unknown")).get_file()
	var line: int = int(source_info.get("line", 0))
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
func add_tag(tag: String) -> Error:
	if tag.is_empty():
		push_warning("Cannot add empty tag")
		return Error.FAILED

	if not _active_tags.has(tag):
		_active_tags.append(tag)

	# Remove from ignored tags if present
	if _ignored_tags.has(tag):
		_ignored_tags.erase(tag)

	return Error.OK

func remove_tag(tag: String) -> Error:
	if tag.is_empty():
		push_warning("Cannot remove empty tag")
		return Error.FAILED

	if _active_tags.has(tag):
		_active_tags.erase(tag)
		return Error.OK

	return Error.FAILED # Tag wasn't in the list

func clear_tags() -> void:
	_active_tags.clear()

func add_ignored_tag(tag: String) -> Error:
	if tag.is_empty():
		push_warning("Cannot add empty ignored tag")
		return Error.FAILED

	if not _ignored_tags.has(tag):
		_ignored_tags.append(tag)

	# Remove from active tags if present
	if _active_tags.has(tag):
		_active_tags.erase(tag)

	return Error.OK

func remove_ignored_tag(tag: String) -> Error:
	if tag.is_empty():
		push_warning("Cannot remove empty ignored tag")
		return Error.FAILED

	if _ignored_tags.has(tag):
		_ignored_tags.erase(tag)
		return Error.OK

	return Error.FAILED # Tag wasn't in the list

func clear_ignored_tags() -> void:
	_ignored_tags.clear()

# Format settings
func set_show_timestamp(show: bool) -> void:
	_show_timestamp = show

func set_show_tags(show: bool) -> void:
	_show_tags = show

func set_use_colors(use: bool) -> void:
	_use_colors = use
