@tool
class_name Logger extends Node
## Simple logging system with tags and levels

enum LogLevel { DEBUG, INFO, WARNING, ERROR, CRITICAL }

# Color definitions
const LEVEL_COLORS: Dictionary = {
	LogLevel.DEBUG: Color("#928374"),    # Gray
	LogLevel.INFO: Color("#83a598"),     # Blue
	LogLevel.WARNING: Color("#fabd2f"),  # Yellow
	LogLevel.ERROR: Color("#fb4934"),    # Red
	LogLevel.CRITICAL: Color("#fe8019")  # Orange
}

const TIMESTAMP_COLOR: Color = Color("#928374")
const TAG_COLOR: Color = Color("#8ec07c")
const SOURCE_COLOR: Color = Color("#928374")

# Log entry class to store log information
class LogEntry:
	var timestamp: int
	var level: LogLevel
	var message: String
	var tags: Array[String]
	var source_info: Dictionary
	var context: Dictionary

	func _init(p_level: LogLevel, p_message: String, p_tags: Array[String], p_source: Dictionary, p_context: Dictionary = {}) -> void:
		timestamp = int(Time.get_unix_time_from_system())
		level = p_level
		message = p_message
		tags = p_tags.duplicate() as Array[String]
		source_info = p_source.duplicate()
		context = p_context.duplicate()

	func is_within_timeframe(seconds_ago: int) -> bool:
		if seconds_ago <= 0:
			return false
		var now: int = int(Time.get_unix_time_from_system())
		return (now - timestamp) <= seconds_ago

# Simple circular buffer for storing logs
class LogBuffer:
	var entries: Array[LogEntry]
	var capacity: int
	var current_index: int = 0

	func _init(size: int) -> void:
		if size <= 0:
			push_error("Buffer size must be positive")
			capacity = 100 # Default to reasonable size on error
		else:
			capacity = size
		entries = []
		entries.resize(capacity)

	func add(entry: LogEntry) -> void:
		if entry == null:
			push_error("Cannot add null entry to log buffer")
			return
		entries[current_index] = entry
		current_index = (current_index + 1) % capacity

	func get_all_entries() -> Array[LogEntry]:
		var result: Array[LogEntry] = []

		for i in range(capacity):
			var idx: int = (current_index - i - 1 + capacity) % capacity
			if entries[idx] != null:
				result.append(entries[idx])

		return result

	func get_entries_in_timeframe(seconds: int) -> Array[LogEntry]:
		var result: Array[LogEntry] = []
		if seconds <= 0:
			return result

		var all_entries: Array[LogEntry] = get_all_entries()

		for entry in all_entries:
			if entry != null and entry.is_within_timeframe(seconds):
				result.append(entry)

		return result

# Class variables
var _buffer: LogBuffer
var _current_level: LogLevel = LogLevel.INFO
var _active_tags: Array[String] = []
var _ignored_tags: Array[String] = []
var _available_tags: Dictionary = {} # String -> int (tag -> count)
var _buffer_size: int = 1000
var _retroactive_window: int = 300
var _show_timestamp: bool = true
var _show_tags: bool = true
var _use_colors: bool = true

func _init() -> void:
	_buffer = LogBuffer.new(_buffer_size)

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
	_show_recent_logs()

func critical(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if message.is_empty():
		push_warning("Empty log message provided")
	_log(LogLevel.CRITICAL, message, context, tags)
	_show_recent_logs()

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

	var source_info: Dictionary = _get_source_info()
	var entry: LogEntry = LogEntry.new(level, message, validated_tags, source_info)

	# Always store in buffer
	_buffer.add(entry)

	# Track tags
	for tag in validated_tags:
		if _available_tags.has(tag):
			_available_tags[tag] = _available_tags[tag] + 1
		else:
			_available_tags[tag] = 1

	# Only show if it passes level and tag filters
	if level >= _current_level and _should_show_tags(validated_tags):
		_output_log_entry(entry)

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

# Format and output a log entry
func _output_log_entry(entry: LogEntry) -> void:
	if entry == null:
		push_error("Cannot output null log entry")
		return

	var formatted: String = _format_entry(entry)
	print_rich(formatted)

# Format a log entry
func _format_entry(entry: LogEntry) -> String:
	if entry == null:
		push_error("Cannot format null log entry")
		return "Invalid log entry"

	var parts: Array[String] = []

	# Add timestamp if enabled
	if _show_timestamp:
		var dt: Dictionary = Time.get_datetime_dict_from_unix_time(entry.timestamp)
		var timestamp: String = "%04d-%02d-%02d %02d:%02d:%02d" % [
			dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second
		]

		if _use_colors:
			parts.append("[color=#%s]%s[/color]" % [TIMESTAMP_COLOR.to_html(false), timestamp])
		else:
			parts.append(timestamp)

	# Add log level
	var level_str: String = LogLevel.keys()[entry.level]
	if _use_colors and LEVEL_COLORS.has(entry.level):
		parts.append("[color=#%s]%s[/color]" % [LEVEL_COLORS[entry.level].to_html(false), level_str])
	else:
		parts.append(level_str)

	# Add tags if enabled and present
	if _show_tags and not entry.tags.is_empty():
		var tags_text: String = "[%s]" % ", ".join(entry.tags)
		if _use_colors:
			parts.append("[color=#%s]%s[/color]" % [TAG_COLOR.to_html(false), tags_text])
		else:
			parts.append(tags_text)

	# Add message (always included)
	if _use_colors and LEVEL_COLORS.has(entry.level):
		parts.append("[color=#%s]%s[/color]" % [LEVEL_COLORS[entry.level].to_html(false), entry.message])
	else:
		parts.append(entry.message)

	# Add context if present
	if not entry.context.is_empty():
		var context_text: String = str(entry.context)
		parts.append(context_text)

	# Add source information
	var file_name: String = String(entry.source_info.get("file", "unknown")).get_file()
	var line: int = int(entry.source_info.get("line", 0))
	var source_text: String = "(%s:%d)" % [file_name, line]

	if _use_colors:
		parts.append("[color=#%s]%s[/color]" % [SOURCE_COLOR.to_html(false), source_text])
	else:
		parts.append(source_text)

	return " ".join(parts)

# Show recent logs (used for error and critical logs) - replays logs that happened before the error
func _show_recent_logs() -> void:
	print_rich("\n[color=yellow]=== Recent Log History ===[/color]")

	# Save current level to temporarily show all logs
	var saved_level = _current_level

	# Get logs from the retroactive window
	var entries = _buffer.get_entries_in_timeframe(_retroactive_window)

	# Skip the last entry (which is the error that triggered this rewind)
	if entries.size() > 1:
		entries.pop_back()

	# Show all logs from the time window
	for entry in entries:
		# Format based on the entry's level
		var formatted = _format_entry(entry)

		# Make entries below current level appear dimmer
		if entry.level < saved_level:
			print_rich("[color=gray]%s[/color]" % formatted)
		else:
			print_rich(formatted)

	print_rich("[color=yellow]=== End Log History ===[/color]\n")

# Settings methods
func set_level(level: LogLevel) -> Error:
	if level < LogLevel.DEBUG or level > LogLevel.CRITICAL:
		push_warning("Invalid log level: %d" % level)
		return Error.FAILED

	_current_level = level
	return Error.OK

func get_level() -> LogLevel:
	return _current_level

func set_buffer_size(size: int) -> Error:
	if size < 10 or size > 10000:
		push_warning("Buffer size must be between 10 and 10000")
		return Error.FAILED

	_buffer_size = size
	_buffer = LogBuffer.new(size)
	return Error.OK

func set_retroactive_window(seconds: int) -> Error:
	if seconds < 10 or seconds > 3600:
		push_warning("Retroactive window must be between 10 and 3600 seconds")
		return Error.FAILED

	_retroactive_window = seconds
	return Error.OK

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

# Tag getters
func get_active_tags() -> Array[String]:
	return _active_tags.duplicate() as Array[String]

func get_ignored_tags() -> Array[String]:
	return _ignored_tags.duplicate() as Array[String]

func get_available_tags() -> Array[String]:
	var tags: Array[String] = []
	for key in _available_tags.keys():
		if key is String and not key.is_empty():
			tags.append(key)
	return tags

func get_available_tags_with_counts() -> Dictionary:
	return _available_tags.duplicate()

# Format settings
func set_show_timestamp(show: bool) -> void:
	_show_timestamp = show

func set_show_tags(show: bool) -> void:
	_show_tags = show

func set_use_colors(use: bool) -> void:
	_use_colors = use

# Scan the buffer for available tags
func scan_for_tags() -> void:
	_available_tags.clear()

	var entries: Array[LogEntry] = _buffer.get_all_entries()
	for entry in entries:
		if entry != null:
			for tag in entry.tags:
				if tag is String and not tag.is_empty():
					if _available_tags.has(tag):
						_available_tags[tag] = _available_tags[tag] + 1
					else:
						_available_tags[tag] = 1
