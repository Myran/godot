@tool
class_name Logger extends Node
## Advanced logging system with colored output, circular buffer, and retroactive log replay

enum LogLevel { DEBUG, INFO, WARNING, ERROR, CRITICAL }

enum LoggerError {
	OK = 0,
	INVALID_BUFFER_SIZE = 1,
	INVALID_LOG_LEVEL = 2,
	INVALID_TIME_WINDOW = 3,
	INVALID_TAG = 4
}

# Define colors as individual constants
const GRUVBOX_BG: Color = Color("282828")
const GRUVBOX_RED: Color = Color("fb4934")
const GRUVBOX_GREEN: Color = Color("b8bb26")
const GRUVBOX_YELLOW: Color = Color("fabd2f")
const GRUVBOX_BLUE: Color = Color("83a598")
const GRUVBOX_PURPLE: Color = Color("d3869b")
const GRUVBOX_AQUA: Color = Color("8ec07c")
const GRUVBOX_ORANGE: Color = Color("fe8019")
const GRUVBOX_GRAY: Color = Color("928374")

# Color mappings
const LEVEL_COLORS: Dictionary[int, Color] = {
	LogLevel.DEBUG: GRUVBOX_GRAY,
	LogLevel.INFO: GRUVBOX_BLUE,
	LogLevel.WARNING: GRUVBOX_YELLOW,
	LogLevel.ERROR: GRUVBOX_RED,
	LogLevel.CRITICAL: GRUVBOX_ORANGE
}

const TIMESTAMP_COLOR: Color = GRUVBOX_GRAY
const TAGS_COLOR: Color = GRUVBOX_AQUA
const CONTEXT_KEY_COLOR: Color = GRUVBOX_PURPLE
const CONTEXT_VALUE_COLOR: Color = GRUVBOX_BLUE
const REPLAY_COLOR: Color = GRUVBOX_YELLOW
const SOURCE_COLOR: Color = GRUVBOX_GRAY

class LogEntry:
	var timestamp: int
	var level: LogLevel
	var message: String
	var context: Dictionary
	var tags: Array[String]
	var source_info: Dictionary

	func _init(
		_level: LogLevel,
		_message: String,
		_context: Dictionary,
		_tags: Array[String],
		_source: Dictionary
	) -> void:
		timestamp = int(Time.get_unix_time_from_system())
		level = _level
		message = _message
		context = _context.duplicate()
		tags = _tags.duplicate()
		source_info = _source

class CircularBuffer:
	var buffer: Array[LogEntry]
	var current_index: int = 0
	var mutex: Mutex

	func _init(size: int) -> void:
		buffer = []
		buffer.resize(size)
		mutex = Mutex.new()

	func add(entry: LogEntry) -> void:
		mutex.lock()
		buffer[current_index] = entry
		current_index = (current_index + 1) % buffer.size()
		mutex.unlock()

	func get_recent_entries() -> Array[LogEntry]:
		mutex.lock()
		var entries: Array[LogEntry] = []

		var idx: int = current_index
		for i: int in range(buffer.size()):
			idx = (current_index - i - 1 + buffer.size()) % buffer.size()
			if buffer[idx] != null:
				entries.push_front(buffer[idx])

		mutex.unlock()
		return entries

class LoggerConfig:
	const MIN_BUFFER_SIZE: int = 50
	const MAX_BUFFER_SIZE: int = 10000
	const MIN_TIME_WINDOW: int = 10  # seconds
	const MAX_TIME_WINDOW: int = 3600  # 1 hour

	var buffer_size: int = 1000
	var default_level: LogLevel = LogLevel.INFO
	var retroactive_level_limit: int = -1
	var retroactive_time_window: int = 300

	func _init(
		_buffer_size: int = 1000,
		_default_level: LogLevel = LogLevel.INFO,
		_retro_level_limit: int = -1,
		_retro_time_window: int = 300
	) -> void:
		if set_buffer_size(_buffer_size) != LoggerError.OK:
			push_error("Failed to set buffer size")
		if set_default_level(_default_level) != LoggerError.OK:
			push_error("Failed to set default level")
		if set_retroactive_level_limit(_retro_level_limit) != LoggerError.OK:
			push_error("Failed to set retroactive level limit")
		if set_retroactive_time_window(_retro_time_window) != LoggerError.OK:
			push_error("Failed to set retroactive time window")

	func set_buffer_size(size: int) -> LoggerError:
		if size < MIN_BUFFER_SIZE or size > MAX_BUFFER_SIZE:
			return LoggerError.INVALID_BUFFER_SIZE
		buffer_size = size
		return LoggerError.OK

	func set_default_level(level: LogLevel) -> LoggerError:
		if level < LogLevel.DEBUG or level > LogLevel.CRITICAL:
			return LoggerError.INVALID_LOG_LEVEL
		default_level = level
		return LoggerError.OK

	func set_retroactive_level_limit(limit: int) -> LoggerError:
		if limit != -1 and (limit < LogLevel.DEBUG or limit > LogLevel.CRITICAL):
			return LoggerError.INVALID_LOG_LEVEL
		retroactive_level_limit = limit
		return LoggerError.OK

	func set_retroactive_time_window(seconds: int) -> LoggerError:
		if seconds < MIN_TIME_WINDOW or seconds > MAX_TIME_WINDOW:
			return LoggerError.INVALID_TIME_WINDOW
		retroactive_time_window = seconds
		return LoggerError.OK

var _config: LoggerConfig
var _buffer: CircularBuffer
var _current_level: LogLevel = LogLevel.INFO
var _active_tags: Array[String] = []
var _enabled: bool = true

func _init(config: LoggerConfig = null) -> void:
	_config = config if config else LoggerConfig.new()
	_buffer = CircularBuffer.new(_config.buffer_size)
	set_level(_config.default_level)  # Use set_level to ensure proper initialization

# Configuration methods
func set_level(level: LogLevel) -> Error:
	if level < LogLevel.DEBUG or level > LogLevel.CRITICAL:
		push_warning("Logger: Invalid log level: %d" % level)
		return FAILED

	var err: LoggerError = _config.set_default_level(level)
	if err != LoggerError.OK:
		push_warning("Logger: Failed to set log level: %d" % level)
		return FAILED

	_current_level = level
	_config.default_level = level  # Ensure config is updated
	print_rich("[color=green]Logger level set to: %s[/color]" % LogLevel.keys()[level])
	return OK

func set_buffer_size(size: int) -> Error:
	var err: LoggerError = _config.set_buffer_size(size)
	if err != LoggerError.OK:
		push_warning(
			"Logger: Invalid buffer size %d (must be between %d and %d)"
			% [size, LoggerConfig.MIN_BUFFER_SIZE, LoggerConfig.MAX_BUFFER_SIZE]
		)
		return FAILED
	_buffer = CircularBuffer.new(size)
	return OK

func set_retroactive_window(seconds: int) -> Error:
	var err: LoggerError = _config.set_retroactive_time_window(seconds)
	if err != LoggerError.OK:
		push_warning(
			"Logger: Invalid time window %d (must be between %d and %d seconds)"
			% [seconds, LoggerConfig.MIN_TIME_WINDOW, LoggerConfig.MAX_TIME_WINDOW]
		)
		return FAILED
	return OK

func add_tag(tag: String) -> Error:
	if tag.is_empty():
		push_warning("Logger: Tag cannot be empty")
		return FAILED
	if not _active_tags.has(tag):
		_active_tags.append(tag)
		print_rich("[color=green]Added tag: %s[/color]" % tag)
	return OK

func remove_tag(tag: String) -> void:
	if _active_tags.has(tag):
		_active_tags.erase(tag)
		print_rich("[color=yellow]Removed tag: %s[/color]" % tag)

func clear_tags() -> void:
	_active_tags.clear()
	print_rich("[color=yellow]Cleared all tags[/color]")

func enable() -> void:
	_enabled = true
	print_rich("[color=green]Logger enabled[/color]")

func disable() -> void:
	_enabled = false
	print_rich("[color=red]Logger disabled[/color]")

# Main logging methods
func debug(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	_log(LogLevel.DEBUG, message, context, tags)

func info(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	_log(LogLevel.INFO, message, context, tags)

func warning(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	_log(LogLevel.WARNING, message, context, tags)

func error(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	_log(LogLevel.ERROR, message, context, tags)
	_handle_error_occurrence()

func critical(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	_log(LogLevel.CRITICAL, message, context, tags)
	_handle_error_occurrence()

# Internal methods
func _log(level: LogLevel, message: String, context: Dictionary, tags: Array[String]) -> void:
	if not _enabled:
		return

	var source_info: Dictionary = _get_source_info()
	var entry: LogEntry = LogEntry.new(level, message, context, tags, source_info)

	# Always store in buffer
	_buffer.add(entry)

	# Show if passes level and tag filters
	if _should_show_log(level, tags):
		_output_log_entry(entry)

func _handle_error_occurrence() -> void:
	print_rich("\n[color=yellow]=== Begin Retroactive Log Replay ===[/color]")

	var entries: Array[LogEntry] = _buffer.get_recent_entries()
	var now: int = int(Time.get_unix_time_from_system())
	var saved_level := _current_level

	# Temporarily set level to DEBUG to show all messages
	_current_level = LogLevel.DEBUG

	for entry: LogEntry in entries:
		# Skip old entries
		if now - entry.timestamp > _config.retroactive_time_window:
			continue

		# Show all entries in retroactive mode
		_output_log_entry(entry, true)

	# Restore original level
	_current_level = saved_level

	print_rich("[color=yellow]=== End Retroactive Log Replay ===[/color]\n")

func _should_show_log(level: LogLevel, tags: Array[String]) -> bool:
	# Only show messages at or above the current level
	if level < _current_level:
		return false

	# If no active tags, message passes
	if _active_tags.is_empty():
		return true

	# If there are active tags but message has no tags, don't show
	if tags.is_empty():
		return false

	# Show if any message tag matches active tags
	for tag in tags:
		if _active_tags.has(tag):
			return true

	return false

func _get_source_info() -> Dictionary:
	var stack: Array = get_stack()
	if stack.size() >= 3:  # Skip logger internal frames
		return {
			"file": stack[2].source.get_file(),
			"line": stack[2].line,
			"function": stack[2].function
		}
	return {}

func _colorize(text: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]

func _output_log_entry(entry: LogEntry, is_replay: bool = false) -> void:
	var parts: Array[String] = []

	var timestamp: String = Time.get_datetime_string_from_unix_time(entry.timestamp)
	parts.append(_colorize(timestamp, TIMESTAMP_COLOR))

	if is_replay:
		parts.append(_colorize("[REPLAY]", REPLAY_COLOR))

	var level_str: String = LogLevel.keys()[entry.level]
	var level_color: Color = LEVEL_COLORS[entry.level]
	parts.append(_colorize(level_str, level_color))

	if not entry.tags.is_empty():
		var colored_tags: PackedStringArray = entry.tags.map(
			func(tag: String) -> String: return _colorize(tag, TAGS_COLOR)
		)
		parts.append("[%s]" % ", ".join(colored_tags))

	var message_color: Color = LEVEL_COLORS[entry.level].darkened(0.2)
	parts.append(_colorize(entry.message, message_color))

	if not entry.context.is_empty():
		var context_lines: Array[String] = []
		for key: String in entry.context:
			var value: Variant = entry.context[key]
			var formatted_value: String = _format_context_value(value)
			context_lines.append(
				"    %s: %s" % [
					_colorize(key, CONTEXT_KEY_COLOR),
					_colorize(formatted_value, CONTEXT_VALUE_COLOR)
				]
			)
		parts.append("\n%s" % "\n".join(context_lines))

	var source_text: String = (
		"at: %s:%d (%s)" % [
			entry.source_info.file,
			entry.source_info.line,
			entry.source_info.function
		]
	)
	parts.append("\n    %s" % _colorize(source_text, SOURCE_COLOR))

	print_rich(" ".join(parts))

func _format_context_value(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING:
			return '"%s"' % value
		TYPE_OBJECT:
			if value == null:
				return "null"
			return str(value)
		_:
			return str(value)
