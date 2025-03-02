@tool
class_name Logger extends Node
## Advanced logging system with colored output, circular buffer, and retroactive log replay

enum LogLevel { DEBUG, INFO, WARNING, ERROR, CRITICAL }

enum LoggerError {
	OK = 0, INVALID_BUFFER_SIZE = 1, INVALID_LOG_LEVEL = 2, INVALID_TIME_WINDOW = 3, INVALID_TAG = 4
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

# Settings are managed by LoggerSettings class

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

	# Helper methods for filtering and checking
	func matches_level(min_level: LogLevel) -> bool:
		return level >= min_level

	func has_tag(tag: String) -> bool:
		return tags.has(tag)

	func has_any_tag(tag_list: Array[String]) -> bool:
		if tags.is_empty() or tag_list.is_empty():
			return false

		for tag in tags:
			if tag_list.has(tag):
				return true
		return false

	func is_within_timeframe(seconds_ago: int) -> bool:
		var now = int(Time.get_unix_time_from_system())
		return (now - timestamp) <= seconds_ago


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

	func get_entries_in_timeframe(seconds: int) -> Array[LogEntry]:
		var result: Array[LogEntry] = []
		var entries = get_recent_entries()

		for entry in entries:
			if entry.is_within_timeframe(seconds):
				result.append(entry)

		return result


class TagManager:
	signal tag_added(tag: String, is_active: bool)
	signal tag_removed(tag: String, was_active: bool)
	signal tags_cleared(was_active: bool)

	var _active_tags: Array[String] = []
	var _ignored_tags: Array[String] = []
	var _available_tags: Dictionary[String, int] = {}
	var _mutex: Mutex

	func _init() -> void:
		_mutex = Mutex.new()

	# Active tags management
	func add_tag(tag: String) -> Error:
		if tag.is_empty():
			push_warning("TagManager: Tag cannot be empty")
			return Error.FAILED

		_mutex.lock()

		# Remove from ignored tags if it exists there
		if _ignored_tags.has(tag):
			_ignored_tags.erase(tag)

		if not _active_tags.has(tag):
			_active_tags.append(tag)
			_mutex.unlock()
			tag_added.emit(tag, true)
			return Error.OK

		_mutex.unlock()
		return Error.OK

	func remove_tag(tag: String) -> void:
		_mutex.lock()
		if _active_tags.has(tag):
			_active_tags.erase(tag)
			_mutex.unlock()
			tag_removed.emit(tag, true)
		else:
			_mutex.unlock()

	func clear_tags() -> void:
		_mutex.lock()
		_active_tags.clear()
		_mutex.unlock()
		tags_cleared.emit(true)

	# Ignored tags management
	func add_ignored_tag(tag: String) -> Error:
		if tag.is_empty():
			push_warning("TagManager: Tag cannot be empty")
			return Error.FAILED

		_mutex.lock()

		# Remove from active tags if it exists there
		if _active_tags.has(tag):
			_active_tags.erase(tag)

		if not _ignored_tags.has(tag):
			_ignored_tags.append(tag)
			_mutex.unlock()
			tag_added.emit(tag, false)
			return Error.OK

		_mutex.unlock()
		return Error.OK

	func remove_ignored_tag(tag: String) -> void:
		_mutex.lock()
		if _ignored_tags.has(tag):
			_ignored_tags.erase(tag)
			_mutex.unlock()
			tag_removed.emit(tag, false)
		else:
			_mutex.unlock()

	func clear_ignored_tags() -> void:
		_mutex.lock()
		_ignored_tags.clear()
		_mutex.unlock()
		tags_cleared.emit(false)

	# Tag filtering
	func should_show_log(level: LogLevel, tags: Array[String]) -> bool:
		_mutex.lock()

		# Check for ignored tags first - they take precedence
		if not _ignored_tags.is_empty():
			for tag in tags:
				if _ignored_tags.has(tag):
					_mutex.unlock()
					return false  # Message has an ignored tag

		# If no active tags, message passes
		if _active_tags.is_empty():
			_mutex.unlock()
			return true

		# If there are active tags but message has no tags, don't show
		if tags.is_empty():
			_mutex.unlock()
			return false

		# Show if any message tag matches active tags
		for tag in tags:
			if _active_tags.has(tag):
				_mutex.unlock()
				return true

		_mutex.unlock()
		return false

	# Tag usage tracking
	func track_tag_usage(tags: Array[String]) -> void:
		if tags.is_empty():
			return

		_mutex.lock()
		for tag in tags:
			if _available_tags.has(tag):
				_available_tags[tag] += 1
			else:
				_available_tags[tag] = 1
		_mutex.unlock()

	# Available tags management
	func get_available_tags() -> Array[String]:
		_mutex.lock()
		var tags: Array[String] = []
		for tag in _available_tags.keys():
			tags.append(tag)
		tags.sort()
		_mutex.unlock()
		return tags

	func get_tag_usage_count(tag: String) -> int:
		_mutex.lock()
		var count = 0
		if _available_tags.has(tag):
			count = _available_tags[tag]
		_mutex.unlock()
		return count

	func get_available_tags_with_counts() -> Dictionary[String, int]:
		_mutex.lock()
		var result = _available_tags.duplicate()
		_mutex.unlock()
		return result

	func scan_buffer_for_tags(entries: Array[LogEntry]) -> void:
		_mutex.lock()
		_available_tags.clear()

		for entry in entries:
			for tag in entry.tags:
				if _available_tags.has(tag):
					_available_tags[tag] += 1
				else:
					_available_tags[tag] = 1
		_mutex.unlock()

	# Getters for internal state
	func get_active_tags() -> Array[String]:
		_mutex.lock()
		var result = _active_tags.duplicate()
		_mutex.unlock()
		return result

	func get_ignored_tags() -> Array[String]:
		_mutex.lock()
		var result = _ignored_tags.duplicate()
		_mutex.unlock()
		return result


class LogFormatter:
	var _level_colors: Dictionary[int, Color]
	var _timestamp_color: Color
	var _tags_color: Color
	var _context_key_color: Color
	var _context_value_color: Color
	var _replay_color: Color
	var _source_color: Color
	var _format_settings: LoggerSettings.FormatSettings

	func _init(
		level_colors: Dictionary[int, Color],
		timestamp_color: Color,
		tags_color: Color,
		context_key_color: Color,
		context_value_color: Color,
		replay_color: Color,
		source_color: Color
	) -> void:
		_level_colors = level_colors
		_timestamp_color = timestamp_color
		_tags_color = tags_color
		_context_key_color = context_key_color
		_context_value_color = context_value_color
		_replay_color = replay_color
		_source_color = source_color
		_format_settings = LoggerSettings.FormatSettings.new()

	## Apply format settings to the formatter
	func apply_format_settings(settings: LoggerSettings.FormatSettings) -> void:
		_format_settings = settings

		# Update colors if using custom colors
		if not _format_settings.use_default_colors and _format_settings.use_colors:
			if "debug" in _format_settings.custom_colors:
				_level_colors[Logger.LogLevel.DEBUG] = _format_settings.custom_colors["debug"]
			if "info" in _format_settings.custom_colors:
				_level_colors[Logger.LogLevel.INFO] = _format_settings.custom_colors["info"]
			if "warning" in _format_settings.custom_colors:
				_level_colors[Logger.LogLevel.WARNING] = _format_settings.custom_colors["warning"]
			if "error" in _format_settings.custom_colors:
				_level_colors[Logger.LogLevel.ERROR] = _format_settings.custom_colors["error"]
			if "critical" in _format_settings.custom_colors:
				_level_colors[Logger.LogLevel.CRITICAL] = _format_settings.custom_colors["critical"]
			if "timestamp" in _format_settings.custom_colors:
				_timestamp_color = _format_settings.custom_colors["timestamp"]
			if "tags" in _format_settings.custom_colors:
				_tags_color = _format_settings.custom_colors["tags"]
			if "source" in _format_settings.custom_colors:
				_source_color = _format_settings.custom_colors["source"]

	## Format a log entry according to the current format settings
	func format_entry(entry: LogEntry, is_replay: bool = false) -> String:
		# Handle layout mode
		match _format_settings.layout_mode:
			LoggerSettings.FormatSettings.LayoutMode.COMPACT:
				return _format_compact(entry, is_replay)
			LoggerSettings.FormatSettings.LayoutMode.CUSTOM:
				return _format_custom(entry, is_replay)
			_:  # EXPANDED
				return _format_expanded(entry, is_replay)

	## Format an entry in expanded (multiline) mode
	func _format_expanded(entry: LogEntry, is_replay: bool) -> String:
		var parts: Array[String] = []

		# Add timestamp if enabled
		if _format_settings.show_timestamp:
			parts.append(_format_timestamp(entry.timestamp))

		# Add replay indicator if applicable
		if is_replay:
			parts.append(_colorize("[REPLAY]", _replay_color))

		# Add log level if enabled
		if _format_settings.show_level:
			var level_str: String = Logger.LogLevel.keys()[entry.level]
			var level_color: Color = _level_colors[entry.level]
			parts.append(_colorize(level_str, level_color))

		# Add tags if enabled and present
		if _format_settings.show_tags and not entry.tags.is_empty():
			parts.append(_format_tags(entry.tags))

		# Message is always shown (on its own line in expanded mode)
		var message_color: Color = _level_colors[entry.level].darkened(0.2)
		var message_text = _colorize(entry.message, message_color)

		# Build header line
		var header = " ".join(parts)

		# Start building the full message with header and message
		var full_message = header + "\n" + message_text

		# Add context data if enabled and present
		if _format_settings.show_context and not entry.context.is_empty():
			full_message += "\n" + _format_context(entry.context)

		# Add source info if enabled and available
		if _format_settings.show_source and _has_valid_source_info(entry.source_info):
			full_message += "\n    " + _format_source_info(entry.source_info)

		return full_message

	## Format an entry in compact (single line) mode
	func _format_compact(entry: LogEntry, is_replay: bool) -> String:
		var parts: Array[String] = []

		# Add timestamp if enabled
		if _format_settings.show_timestamp:
			parts.append(_format_timestamp(entry.timestamp))

		# Add replay indicator if applicable
		if is_replay:
			parts.append(_colorize("[REPLAY]", _replay_color))

		# Add log level if enabled
		if _format_settings.show_level:
			var level_str: String = Logger.LogLevel.keys()[entry.level]
			var level_color: Color = _level_colors[entry.level]
			parts.append(_colorize(level_str, level_color))

		# Add tags if enabled and present
		if _format_settings.show_tags and not entry.tags.is_empty():
			parts.append(_format_tags(entry.tags))

		# Message is always shown
		var message_color: Color = _level_colors[entry.level].darkened(0.2)
		parts.append(_colorize(entry.message, message_color))

		# Add abbreviated context if enabled
		if _format_settings.show_context and not entry.context.is_empty():
			var context_preview = "{"
			var keys = entry.context.keys()

			# Limit number of context items shown
			var limit = _format_settings.context_limit
			if limit <= 0 or limit > keys.size():
				limit = keys.size()

			for i in range(limit):
				if i > 0:
					context_preview += ", "
				context_preview += keys[i]

			if keys.size() > limit:
				context_preview += ", ..."

			context_preview += "}"
			parts.append(_colorize(context_preview, _context_key_color))

		# Add abbreviated source info if enabled
		if _format_settings.show_source and _has_valid_source_info(entry.source_info):
			var source_text = ""

			match _format_settings.path_mode:
				LoggerSettings.FormatSettings.PathMode.FILENAME:
					var file_path = entry.source_info["file"] as String
					source_text = file_path.get_file()
				_:
					source_text = entry.source_info["file"]

			source_text += ":" + str(entry.source_info["line"])
			parts.append(_colorize("(" + source_text + ")", _source_color))

		return " ".join(parts)

	## Format an entry using custom component order
	func _format_custom(entry: LogEntry, is_replay: bool) -> String:
		var parts: Array[String] = []

		# Process each component in the specified order
		for component in _format_settings.component_order:
			match component:
				"timestamp":
					if _format_settings.show_timestamp:
						parts.append(_format_timestamp(entry.timestamp))

				"level":
					if _format_settings.show_level:
						var level_str: String = Logger.LogLevel.keys()[entry.level]
						var level_color: Color = _level_colors[entry.level]
						parts.append(_colorize(level_str, level_color))

				"tags":
					if _format_settings.show_tags and not entry.tags.is_empty():
						parts.append(_format_tags(entry.tags))

				"message":
					var message_color: Color = _level_colors[entry.level].darkened(0.2)
					parts.append(_colorize(entry.message, message_color))

				"context":
					if _format_settings.show_context and not entry.context.is_empty():
						if _format_settings.context_multiline:
							parts.append("\n" + _format_context(entry.context))
						else:
							# Add inline context (abbreviated)
							var context_preview = "{"
							var keys = entry.context.keys()

							# Limit number of context items shown
							var limit = _format_settings.context_limit
							if limit <= 0 or limit > keys.size():
								limit = keys.size()

							for i in range(limit):
								if i > 0:
									context_preview += ", "
								context_preview += keys[i]

							if keys.size() > limit:
								context_preview += ", ..."

							context_preview += "}"
							parts.append(_colorize(context_preview, _context_key_color))

				"source":
					if _format_settings.show_source and _has_valid_source_info(entry.source_info):
						parts.append(_format_source_info(entry.source_info))

		# Add replay indicator if applicable (always at beginning)
		if is_replay:
			parts.insert(0, _colorize("[REPLAY]", _replay_color))

		return " ".join(parts)

	## Format timestamp according to settings
	func _format_timestamp(timestamp: int) -> String:
		var dt = Time.get_datetime_dict_from_unix_time(timestamp)
		var format_str = ""

		# Date part
		if _format_settings.timestamp_show_date:
			format_str += "%04d-%02d-%02d " % [dt.year, dt.month, dt.day]

		# Time part
		if _format_settings.timestamp_use_24h:
			format_str += "%02d:%02d:%02d" % [dt.hour, dt.minute, dt.second]
		else:
			var hour = dt.hour
			var am_pm = "AM"
			if hour >= 12:
				am_pm = "PM"
				if hour > 12:
					hour -= 12
			if hour == 0:
				hour = 12
			format_str += "%d:%02d:%02d %s" % [hour, dt.minute, dt.second, am_pm]

		# Milliseconds
		if _format_settings.timestamp_show_ms:
			format_str += ".%03d" % (timestamp % 1000)

		return _colorize(format_str, _timestamp_color)

	## Format tags according to settings
	func _format_tags(tags: Array[String]) -> String:
		var colored_tags: PackedStringArray = []
		for tag in tags:
			colored_tags.append(_colorize(tag, _tags_color))
		return "[%s]" % ", ".join(colored_tags)

	## Format context data according to settings
	func _format_context(context: Dictionary) -> String:
		var context_lines: Array[String] = []

		var keys = context.keys()
		# Apply context limit if set
		var limit = _format_settings.context_limit
		if limit > 0 and limit < keys.size():
			keys = keys.slice(0, limit)

		for key in keys:
			var value = context[key]
			var formatted_value = _format_context_value(value)
			context_lines.append(
				(
					"    %s: %s"
					% [
						_colorize(key, _context_key_color),
						_colorize(formatted_value, _context_value_color)
					]
				)
			)

		return "\n".join(context_lines)

	## Format source information according to settings
	func _format_source_info(source_info: Dictionary) -> String:
		var file_path = source_info["file"] as String
		var line = source_info["line"]
		var func_name = source_info["function"]

		# Format file path according to settings
		var display_path = file_path
		match _format_settings.path_mode:
			LoggerSettings.FormatSettings.PathMode.FILENAME:
				display_path = file_path.get_file()

			LoggerSettings.FormatSettings.PathMode.SHORT:
				# Remove res:// prefix if present
				if display_path.begins_with("res://"):
					display_path = display_path.substr(6)

			LoggerSettings.FormatSettings.PathMode.LIMITED_FOLDERS:
				var parts = file_path.split("/")
				if parts.size() > _format_settings.path_folder_depth + 1:
					# Keep filename and specified number of parent folders
					display_path = "/".join(
						parts.slice(
							parts.size() - _format_settings.path_folder_depth - 1, parts.size()
						)
					)
				else:
					display_path = file_path

		var source_text = "at: %s:%d (%s)" % [display_path, line, func_name]
		return _colorize(source_text, _source_color)

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

	func _colorize(text: String, color: Color) -> String:
		if (
			text.is_empty()
			or not str(color).is_valid_html_color()
			or not _format_settings.use_colors
		):
			return text
		return "[color=#%s]%s[/color]" % [color.to_html(false), text]

	func _has_valid_source_info(source_info: Dictionary) -> bool:
		return source_info.has("file") and source_info.has("line") and source_info.has("function")

	## Format a log entry for testing mode (plain text)
	func format_test_mode(entry: LogEntry) -> String:
		var level_str: String = Logger.LogLevel.keys()[entry.level]
		var result = "LOG: " + level_str + " - " + entry.message

		if not entry.context.is_empty():
			result += "\n  Context: " + str(entry.context)

		return result

	## Format a log entry in plain text (no colors)
	func format_plain_text(entry: LogEntry) -> String:
		var parts: Array[String] = []

		var timestamp: String = Time.get_datetime_string_from_unix_time(entry.timestamp)
		parts.append(timestamp)

		var level_str: String = Logger.LogLevel.keys()[entry.level]
		parts.append(level_str)

		if not entry.tags.is_empty():
			parts.append("[%s]" % ", ".join(entry.tags))

		parts.append(entry.message)

		return " ".join(parts)

	## Generate a sample log entry for preview
	static func generate_preview_entry() -> LogEntry:
		var entry = LogEntry.new(
			Logger.LogLevel.INFO,
			"User logged in successfully",
			{"user_id": "12345", "ip": "192.168.1.100", "session_id": "abc123def456"},
			["auth", "login"],
			{"file": "res://scripts/auth/login_manager.gd", "line": 42, "function": "process_login"}
		)
		return entry


class LoggerConfig:
	const MIN_BUFFER_SIZE: int = 50
	const MAX_BUFFER_SIZE: int = 10000
	const MIN_TIME_WINDOW: int = 10  # seconds
	const MAX_TIME_WINDOW: int = 3600  # 1 hour

	var buffer_size: int = 1000
	var default_level: LogLevel = LogLevel.INFO
	var retroactive_level_limit: int = -1
	var retroactive_time_window: int = 300
	var mutex: Mutex

	func _init(
		_buffer_size: int = 1000,
		_default_level: LogLevel = LogLevel.INFO,
		_retro_level_limit: int = -1,
		_retro_time_window: int = 300
	) -> void:
		mutex = Mutex.new()
		if set_buffer_size(_buffer_size) != LoggerError.OK:
			push_error("Failed to set buffer size")
		if set_default_level(_default_level) != LoggerError.OK:
			push_error("Failed to set default level")
		if set_retroactive_level_limit(_retro_level_limit) != LoggerError.OK:
			push_error("Failed to set retroactive level limit")
		if set_retroactive_time_window(_retro_time_window) != LoggerError.OK:
			push_error("Failed to set retroactive time window")

	func set_buffer_size(size: int) -> LoggerError:
		mutex.lock()
		if size < MIN_BUFFER_SIZE or size > MAX_BUFFER_SIZE:
			mutex.unlock()
			return LoggerError.INVALID_BUFFER_SIZE
		buffer_size = size
		mutex.unlock()
		return LoggerError.OK

	func set_default_level(level: LogLevel) -> LoggerError:
		mutex.lock()
		if level < LogLevel.DEBUG or level > LogLevel.CRITICAL:
			mutex.unlock()
			return LoggerError.INVALID_LOG_LEVEL
		default_level = level
		mutex.unlock()
		return LoggerError.OK

	func set_retroactive_level_limit(limit: int) -> LoggerError:
		mutex.lock()
		if limit != -1 and (limit < LogLevel.DEBUG or limit > LogLevel.CRITICAL):
			mutex.unlock()
			return LoggerError.INVALID_LOG_LEVEL
		retroactive_level_limit = limit
		mutex.unlock()
		return LoggerError.OK

	func set_retroactive_time_window(seconds: int) -> LoggerError:
		mutex.lock()
		if seconds < MIN_TIME_WINDOW or seconds > MAX_TIME_WINDOW:
			mutex.unlock()
			return LoggerError.INVALID_TIME_WINDOW
		retroactive_time_window = seconds
		mutex.unlock()
		return LoggerError.OK


var _config: LoggerConfig
var _buffer: CircularBuffer
var _tag_manager: TagManager
var _formatter: LogFormatter
var _current_level: LogLevel = LogLevel.INFO
var _format_settings: LoggerSettings.FormatSettings
var _enabled: bool = true
var _testing_mode: bool = false
var _initialized: bool = false
var _mutex: Mutex


func _init(config: LoggerConfig = null) -> void:
	_mutex = Mutex.new()
	_config = config if config else LoggerConfig.new()
	_buffer = CircularBuffer.new(_config.buffer_size)
	_tag_manager = TagManager.new()
	_format_settings = LoggerSettings.FormatSettings.new()
	_formatter = LogFormatter.new(
		LEVEL_COLORS,
		TIMESTAMP_COLOR,
		TAGS_COLOR,
		CONTEXT_KEY_COLOR,
		CONTEXT_VALUE_COLOR,
		REPLAY_COLOR,
		SOURCE_COLOR
	)
	_formatter.apply_format_settings(_format_settings)

	# Load settings using the shared LoggerSettings utility
	if LoggerSettings.load_settings(self) != OK:
		# If settings couldn't be loaded, use defaults
		push_warning("Logger: Could not load settings, using defaults")
		set_level(_config.default_level)

	# Mark as initialized after setup
	_initialized = true


# Configuration methods
func set_level(level: LogLevel) -> Error:
	if level < LogLevel.DEBUG or level > LogLevel.CRITICAL:
		push_warning("Logger: Invalid log level: %d" % level)
		return Error.FAILED

	_mutex.lock()
	var err: LoggerError = _config.set_default_level(level)
	if err != LoggerError.OK:
		push_warning("Logger: Failed to set log level: %d" % level)
		_mutex.unlock()
		return Error.FAILED

	_current_level = level
	_config.default_level = level  # Ensure config is updated

	# Only print during manual changes, not initialization
	var should_notify = _initialized and Engine.is_editor_hint() and OS.has_feature("editor")
	_mutex.unlock()

	if should_notify:
		print_rich("[color=green]Logger level set to: %s[/color]" % LogLevel.keys()[level])
	return Error.OK


func set_buffer_size(size: int) -> Error:
	var err: LoggerError = _config.set_buffer_size(size)
	if err != LoggerError.OK:
		push_warning(
			(
				"Logger: Invalid buffer size %d (must be between %d and %d)"
				% [size, LoggerConfig.MIN_BUFFER_SIZE, LoggerConfig.MAX_BUFFER_SIZE]
			)
		)
		return Error.FAILED

	_mutex.lock()
	_buffer = CircularBuffer.new(size)
	_mutex.unlock()
	return Error.OK


func set_retroactive_window(seconds: int) -> Error:
	var err: LoggerError = _config.set_retroactive_time_window(seconds)
	if err != LoggerError.OK:
		push_warning(
			(
				"Logger: Invalid time window %d (must be between %d and %d seconds)"
				% [seconds, LoggerConfig.MIN_TIME_WINDOW, LoggerConfig.MAX_TIME_WINDOW]
			)
		)
		return Error.FAILED
	return Error.OK


# Tag management - delegated to TagManager
func add_tag(tag: String) -> Error:
	var result = _tag_manager.add_tag(tag)
	if result == OK and Engine.is_editor_hint() and OS.has_feature("editor") and _initialized:
		print_rich("[color=green]Added tag: %s[/color]" % tag)
	return result


func remove_tag(tag: String) -> void:
	_tag_manager.remove_tag(tag)
	if Engine.is_editor_hint() and OS.has_feature("editor") and _initialized:
		print_rich("[color=yellow]Removed tag: %s[/color]" % tag)


func clear_tags() -> void:
	_tag_manager.clear_tags()
	# Only print during manual changes, not initialization
	if Engine.is_editor_hint() and OS.has_feature("editor") and _initialized:
		print_rich("[color=yellow]Cleared all tags[/color]")


# Ignored tags management - delegated to TagManager
func add_ignored_tag(tag: String) -> Error:
	var result = _tag_manager.add_ignored_tag(tag)
	if result == OK and Engine.is_editor_hint() and OS.has_feature("editor") and _initialized:
		print_rich("[color=green]Added ignored tag: %s[/color]" % tag)
	return result


func remove_ignored_tag(tag: String) -> void:
	_tag_manager.remove_ignored_tag(tag)
	if Engine.is_editor_hint() and OS.has_feature("editor") and _initialized:
		print_rich("[color=yellow]Removed ignored tag: %s[/color]" % tag)


func clear_ignored_tags() -> void:
	_tag_manager.clear_ignored_tags()
	# Only print during manual changes, not initialization
	if Engine.is_editor_hint() and OS.has_feature("editor") and _initialized:
		print_rich("[color=yellow]Cleared all ignored tags[/color]")


func enable() -> void:
	_mutex.lock()
	_enabled = true
	_mutex.unlock()
	print_rich("[color=green]Logger enabled[/color]")


func disable() -> void:
	_mutex.lock()
	_enabled = false
	_mutex.unlock()
	print_rich("[color=red]Logger disabled[/color]")


func enable_testing_mode() -> void:
	_mutex.lock()
	_testing_mode = true
	_mutex.unlock()
	print("Logger testing mode enabled")


func disable_testing_mode() -> void:
	_mutex.lock()
	_testing_mode = false
	_mutex.unlock()
	print("Logger testing mode disabled")


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


# Get all available tags that have been used
func get_available_tags() -> Array[String]:
	return _tag_manager.get_available_tags()


# Get tag usage count
func get_tag_usage_count(tag: String) -> int:
	return _tag_manager.get_tag_usage_count(tag)


# Get all available tags with their usage counts
func get_available_tags_with_counts() -> Dictionary[String, int]:
	return _tag_manager.get_available_tags_with_counts()


# Access to internal tag lists for UI
func get_active_tags() -> Array[String]:
	return _tag_manager.get_active_tags()


func get_ignored_tags() -> Array[String]:
	return _tag_manager.get_ignored_tags()


# Internal methods
func _log(level: LogLevel, message: String, context: Dictionary, tags: Array[String]) -> void:
	_mutex.lock()
	if not _enabled:
		_mutex.unlock()
		return

	var source_info: Dictionary = _get_source_info()
	var entry: LogEntry = LogEntry.new(level, message, context, tags, source_info)

	# Always store in buffer
	_buffer.add(entry)
	_mutex.unlock()

	# Track tags usage
	_tag_manager.track_tag_usage(tags)

	# Show if passes level and tag filters
	if level >= _current_level and _tag_manager.should_show_log(level, tags):
		_output_log_entry(entry)


func _handle_error_occurrence() -> void:
	print_rich("\n[color=yellow]=== Begin Retroactive Log Replay ===[/color]")

	_mutex.lock()
	var entries: Array[LogEntry] = _buffer.get_entries_in_timeframe(_config.retroactive_time_window)
	var saved_level := _current_level
	# Temporarily set level to DEBUG to show all messages
	_current_level = LogLevel.DEBUG
	_mutex.unlock()

	for entry: LogEntry in entries:
		# Show all entries in retroactive mode
		_output_log_entry(entry, true)

	# Restore original level
	_mutex.lock()
	_current_level = saved_level
	_mutex.unlock()

	print_rich("[color=yellow]=== End Retroactive Log Replay ===[/color]\n")


func _get_source_info() -> Dictionary:
	var source_info: Dictionary = {"file": "unknown", "line": 0, "function": "unknown"}

	var stack: Array = get_stack()
	if stack.is_empty():
		return source_info

	# We need to find the first stack frame that is NOT from the logger itself
	var frame_index := 0
	var logger_path := "res://addons/advanced_logger/logger.gd"

	# Skip all frames from within the logger
	for i in range(stack.size()):
		if i >= stack.size():
			break

		if not stack[i].has("source"):
			continue

		var source = stack[i].source
		if typeof(source) == TYPE_STRING and source != logger_path:
			frame_index = i
			break
		elif typeof(source) == TYPE_OBJECT and source != null:
			if source.has_method("get_file") and source.get_file() != logger_path:
				frame_index = i
				break

	# Now extract information from the target frame
	if frame_index < stack.size():
		var frame = stack[frame_index]

		if frame.has("source"):
			var source = frame.source
			if typeof(source) == TYPE_STRING:
				source_info["file"] = source
			elif typeof(source) == TYPE_OBJECT and source != null:
				if source.has_method("get_file"):
					source_info["file"] = source.get_file()

		if frame.has("line"):
			source_info["line"] = frame.line

		if frame.has("function"):
			source_info["function"] = frame.function

	return source_info


func _output_log_entry(entry: LogEntry, is_replay: bool = false) -> void:
	_mutex.lock()
	var testing = _testing_mode
	_mutex.unlock()

	# For testing mode, use a simpler output format
	if testing:
		print(_formatter.format_test_mode(entry))
		return

	# Format the entry using the formatter with current settings
	var formatted_entry = _formatter.format_entry(entry, is_replay)

	# Print both a regular version and rich version for debugging
	print("LOG: " + entry.message)  # Regular print for verification
	print_rich(formatted_entry)  # Rich formatted version


# Function to scan the buffer for used tags
func scan_for_available_tags() -> void:
	_mutex.lock()
	var entries = _buffer.get_recent_entries()
	_mutex.unlock()

	# Scan all entries for tags
	_tag_manager.scan_buffer_for_tags(entries)

	if Engine.is_editor_hint() and OS.has_feature("editor") and _initialized:
		print_rich(
			(
				"[color=green]Scanned logs: found %d unique tags[/color]"
				% _tag_manager.get_available_tags().size()
			)
		)
