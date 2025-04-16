@tool
class_name Logger extends Node
## Simple logging system with tags and levels
enum LogLevel { DEBUG, INFO, WARNING, ERROR, CRITICAL }
# Make sure dependencies are preloaded
const TagManager = preload("res://addons/advanced_logger/utils/tag_manager.gd")
const ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")
const LogFormatter = preload("res://addons/advanced_logger/core/log_formatter.gd")



# Common tag constants
const TAG_DB: String = "database"
const TAG_CACHE: String = "cache"
const TAG_FIREBASE: String = "firebase"
const TAG_LOCAL: String = "local_data"
const TAG_ERROR: String = "error"
const TAG_NETWORK: String = "network"

# Level tag constants
const TAG_LEVEL_PREFIX: String = "level:"
const TAG_LEVEL_DEBUG: String = "level:debug"
const TAG_LEVEL_INFO: String = "level:info"
const TAG_LEVEL_WARNING: String = "level:warning"
const TAG_LEVEL_ERROR: String = "level:error"
const TAG_LEVEL_CRITICAL: String = "level:critical"

# Mapping between log levels and corresponding tags
const LEVEL_TAGS: Dictionary = {
	LogLevel.DEBUG: TAG_LEVEL_DEBUG,
	LogLevel.INFO: TAG_LEVEL_INFO,
	LogLevel.WARNING: TAG_LEVEL_WARNING,
	LogLevel.ERROR: TAG_LEVEL_ERROR,
	LogLevel.CRITICAL: TAG_LEVEL_CRITICAL
}

# Tag operation constants
const TAG_CATEGORY_AVAILABLE: String = "available"
const TAG_CATEGORY_ACTIVE: String = "active"
const TAG_CATEGORY_IGNORED: String = "ignored"

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
# Debug mode is explicitly disabled by default - very important!
var _debug_filter_logging: bool = false

# --- ADD BUFFER VARIABLES ---
## Stores the last N log entries as dictionaries.
var _log_buffer: Array[Dictionary] = []
## Maximum number of log entries to keep in the buffer.
var _buffer_size: int = ConfigManager.DEFAULT_BUFFER_SIZE
## Flag to prevent dumping the buffer repeatedly for consecutive errors.
var _buffer_dumped_recently: bool = false

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
		elif key == ConfigManager.KEY_BUFFER_SIZE: # <-- Add this elif block
			_buffer_size = int(value)
			_trim_buffer() # Adjust buffer immediately if size changed
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
	_buffer_size = _config.get_buffer_size() # <-- Add this line

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
	if !_validate_message(message):
		return
	_log(LogLevel.DEBUG, message, context, tags)


func info(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if !_validate_message(message):
		return
	_log(LogLevel.INFO, message, context, tags)


func warning(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if !_validate_message(message):
		return
	_log(LogLevel.WARNING, message, context, tags)


func error(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if !_validate_message(message):
		return
	_log(LogLevel.ERROR, message, context, tags)


func critical(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if !_validate_message(message):
		return
	_log(LogLevel.CRITICAL, message, context, tags)


## Validates the message parameter
## Returns true if valid, otherwise false
func _validate_message(message: String) -> bool:
	if message.is_empty():
		push_warning("Empty log message provided")
		return false
	return true


## Checks if a log level should be shown based on the current threshold or level tags
func _should_show_level(level: LogLevel) -> bool:
	var level_tag: String = LEVEL_TAGS[level]

	# Debug - log what we're checking
	if _debug_filter_logging:
		print_rich("[color=#%s]DEBUG: Checking level %s (tag: %s), ignored_tags: %s, active_tags: %s[/color]" %
			[LoggerColors.DEBUG_HTML, LogLevel.keys()[level], level_tag, _ignored_tags, _active_tags])

	# Check if this level tag is ignored
	if _ignored_tags.has(level_tag):
		if _debug_filter_logging:
			print_rich("[color=#%s]DEBUG: Level tag %s is ignored, skipping[/color]" %
				[LoggerColors.DEBUG_HTML, level_tag])
		return false

	# Check if any level tags are in active tags
	var has_active_level_tag: bool = false
	var active_level_tags = []
	for tag in _active_tags:
		if tag.begins_with(TAG_LEVEL_PREFIX):
			has_active_level_tag = true
			active_level_tags.append(tag)

	# If we have active level tags, they override the level setting
	if has_active_level_tag:
		if _debug_filter_logging:
			print_rich("[color=#%s]DEBUG: Found active level tags: %s[/color]" %
				[LoggerColors.DEBUG_HTML, active_level_tags])

		var should_show = _active_tags.has(level_tag)

		if _debug_filter_logging:
			print_rich("[color=#%s]DEBUG: Level tag override - should show %s? %s[/color]" %
				[LoggerColors.DEBUG_HTML, level_tag, should_show])
		return should_show

	# Otherwise use traditional level threshold
	var should_show = level >= _current_level

	if _debug_filter_logging:
		print_rich("[color=#%s]DEBUG: Traditional level threshold - should show %s? %s[/color]" %
			[LoggerColors.DEBUG_HTML, LogLevel.keys()[level], should_show])
	return should_show


# --- ADD BUFFER HELPER METHODS ---

## Adds a log entry dictionary to the buffer, maintaining max size.
func _add_to_buffer(log_data: Dictionary) -> void:
	_log_buffer.append(log_data)
	# Trim the buffer if it exceeds the max size
	if _log_buffer.size() > _buffer_size:
		_log_buffer.pop_front()

## Trims the buffer to the current _buffer_size. Used when config changes.
func _trim_buffer() -> void:
	while _log_buffer.size() > _buffer_size:
		_log_buffer.pop_front()

## Prints the entire contents of the log buffer to the console with clear demarcation.
func _dump_buffer() -> void:
	# Use distinct colors for clarity
	var header_footer_color = LoggerColors.WARNING_HTML # Yellow
	var separator = "".rpad(60, "=") # Create a string of 60 equal signs

	print_rich("\n[color=#%s]%s[/color]" % [header_footer_color, separator])
	print_rich("[color=#%s]=== Dumping Log Buffer (%d entries) ===[/color]" % [header_footer_color, _log_buffer.size()])
	print_rich("[color=#%s]%s[/color]\n" % [header_footer_color, separator])

	# Iterate through a copy to avoid issues if buffer changes during iteration
	var buffer_copy = _log_buffer.duplicate()
	for entry_data in buffer_copy:
		# Create a deep copy to modify the message safely
		var data_to_print = entry_data.duplicate(true)
		# Prepend indicator to the message
		data_to_print.message = "[BUFFER] " + data_to_print.message
		# Print using the standard formatting function
		_print_formatted_log(data_to_print)

	print_rich("\n[color=#%s]%s[/color]" % [header_footer_color, separator])
	print_rich("[color=#%s]=== End Log Buffer Dump ===[/color]" % [header_footer_color])
	print_rich("[color=#%s]%s[/color]\n" % [header_footer_color, separator])

# --- REPLACE THIS ENTIRE METHOD ---
## Internal logging function - handles buffering, filtering, and output
func _log(level: LogLevel, message: String, context: Dictionary, tags: Array[String]) -> void:
	# 1. Validate message
	if !_validate_message(message):
		return

	# 2. Capture log entry data *before* filtering
	var log_entry_data := {
		"level": level,
		"message": message,
		"context": context.duplicate(true), # Deep duplicate context
		"tags": tags.duplicate(),         # Shallow duplicate tags array
		"source_info": _get_source_info() # Get source info now
	}

	# 3. Add to buffer
	_add_to_buffer(log_entry_data)

	# 4. Check if buffer dump is needed (Error/Critical and not recently dumped)
	if level >= LogLevel.ERROR and not _buffer_dumped_recently:
		_dump_buffer()
		_buffer_dumped_recently = true # Prevent immediate re-dumping

	# 5. Reset dump flag if this log is not high severity
	elif level < LogLevel.ERROR:
		_buffer_dumped_recently = false

	# 6. Perform filtering for *this specific log entry*
	# Skip if level filtering prevents this message
	if not _should_show_level(level):
		if _debug_filter_logging:
			print_rich("[color=#%s]DEBUG: Skipping log due to level filtering[/color]" % [LoggerColors.DEBUG_HTML])
		return

	# Validate tags and check if we should show the message based on tags
	var validated_tags := _validate_tags(tags) # Use original tags array
	if not _should_show_tags(validated_tags):
		if _debug_filter_logging:
			print_rich("[color=#%s]DEBUG: Skipping log due to tag filtering[/color]" % [LoggerColors.DEBUG_HTML])
		return

	# 7. Output the *current* log if it passed filters
	if _debug_filter_logging:
		print_rich("[color=#%s]DEBUG: Showing log - level: %s, tags: %s[/color]" %
			[LoggerColors.DEBUG_HTML, LogLevel.keys()[level], validated_tags])

	# Call the refactored printing function
	_print_formatted_log(log_entry_data)


## Validates an array of tags, returning only valid ones
## Parameters:
## - tags: Array of tags to validate
## Returns: Array containing only valid tags
func _validate_tags(tags: Array[String]) -> Array[String]:
	return TagManager.validate_tags(tags)


## Checks if a tag is valid (delegates to TagManager for consistent validation)
func _is_valid_tag(tag) -> bool:
	return TagManager.is_valid_tag(tag)


## Check if a log should be shown based on tags
## Parameters:
## - tags: Tags associated with the log message
## Returns: True if the log should be shown, false otherwise
func _should_show_tags(tags: Array) -> bool:
	var result = TagManager.should_show_tags(tags, _active_tags, _ignored_tags)

	if _debug_filter_logging:
		print_rich("[color=#%s]DEBUG: Checking if tags %s should be shown: %s (active: %s, ignored: %s)[/color]" %
			[LoggerColors.DEBUG_HTML, tags, result, _active_tags, _ignored_tags])

	return result


# Get source information (file, line, function)
func _get_source_info() -> Dictionary:
	var source_info := _create_default_source_info()
	var stack := get_stack()

	if stack.is_empty():
		return source_info

	var frame := _find_non_logger_frame(stack)
	if frame != null && !frame.is_empty():
		_update_source_info_from_frame(source_info, frame)

	return source_info


## Creates a default source info dictionary
func _create_default_source_info() -> Dictionary:
	return {
		"file": "unknown",
		"line": 0,
		"function": "unknown"
	}


## Finds the first stack frame that isn't from the logger itself
func _find_non_logger_frame(stack: Array) -> Dictionary:
	const SOURCE_KEY: String = "source"

	for frame in stack:
		if not frame.has(SOURCE_KEY):
			continue

		var source: String = frame.get(SOURCE_KEY)
		if not source.ends_with("logger.gd"):
			return frame

	return {}


## Updates source info with data from a stack frame
func _update_source_info_from_frame(source_info: Dictionary, frame: Dictionary) -> void:
	const FILE_KEY: String = "file"
	const LINE_KEY: String = "line"
	const FUNCTION_KEY: String = "function"
	const SOURCE_KEY: String = "source"

	if frame.has(SOURCE_KEY):
		source_info[FILE_KEY] = frame.get(SOURCE_KEY)

	if frame.has(LINE_KEY):
		source_info[LINE_KEY] = int(frame.get(LINE_KEY, 0))

	if frame.has(FUNCTION_KEY):
		source_info[FUNCTION_KEY] = String(frame.get(FUNCTION_KEY, "unknown"))


# --- RENAME _output_log TO _print_formatted_log AND REPLACE ITS CONTENT ---
## Formats and prints a single log entry dictionary
func _print_formatted_log(log_data: Dictionary) -> void:
	# Extract data from the dictionary
	var level: int = log_data.level
	var message: String = log_data.message
	var context: Dictionary = log_data.context
	var tags: Array[String] = log_data.tags
	var source_info: Dictionary = log_data.source_info

	# Use the LogFormatter to get the formatted log message
	var formatted_log = LogFormatter.format_log(
		level,
		message,
		context,
		tags,
		source_info,
		_show_timestamp,
		_show_tags,
		_use_colors,
		_show_source
	)

	# Output the formatted log
	print_rich(formatted_log)


# Settings methods
func set_level(level: LogLevel) -> Error:
	if !_is_valid_level(level):
		push_warning("Invalid log level: %d" % level)
		return Error.FAILED

	_current_level = level

	# Update config
	if _config != null:
		_config.set_log_level(level)

	return OK


## Validates that a log level is within the enum range
func _is_valid_level(level: int) -> bool:
	return level >= LogLevel.DEBUG and level <= LogLevel.CRITICAL


func get_level() -> LogLevel:
	return _current_level


# Tag management
## Adds a tag to the active tags list
## Returns OK if successful, FAILED otherwise
func add_tag(tag: String) -> Error:
	# Use the new helper method for tag operations
	return _add_tag_to_category(tag, TAG_CATEGORY_ACTIVE)


## Removes a tag from the active tags list
## Returns OK if successful, FAILED otherwise
func remove_tag(tag: String) -> Error:
	if !_is_valid_tag(tag):
		push_warning("Cannot remove invalid tag: '%s'" % tag)
		return Error.FAILED

	# Only proceed if tag is in active list
	if !_active_tags.has(tag):
		return Error.FAILED  # Tag wasn't in the list

	var update_result = _move_tag_between_categories(tag, TAG_CATEGORY_ACTIVE, TAG_CATEGORY_AVAILABLE)
	if update_result == OK:
		_update_active_tags_in_config()

	return update_result


## Clears all active tags
func clear_tags() -> void:
	_active_tags.clear()

	# Update tag list in config if available
	_update_active_tags_in_config()


## Adds a tag to the ignored tags list
## Returns OK if successful, FAILED otherwise
func add_ignored_tag(tag: String) -> Error:
	# Use the new helper method for tag operations
	return _add_tag_to_category(tag, TAG_CATEGORY_IGNORED)


## Removes a tag from the ignored tags list
## Returns OK if successful, FAILED otherwise
func remove_ignored_tag(tag: String) -> Error:
	if !_is_valid_tag(tag):
		push_warning("Cannot remove invalid ignored tag: '%s'" % tag)
		return Error.FAILED

	# Only proceed if tag is in ignored list
	if !_ignored_tags.has(tag):
		return Error.FAILED  # Tag wasn't in the list

	var update_result = _move_tag_between_categories(tag, TAG_CATEGORY_IGNORED, TAG_CATEGORY_AVAILABLE)
	if update_result == OK:
		_update_ignored_tags_in_config()

	return update_result


## Clears all ignored tags
func clear_ignored_tags() -> void:
	_ignored_tags.clear()

	# Update tag list in config if available
	_update_ignored_tags_in_config()


## Helper method to add a tag to a specific category (active or ignored)
func _add_tag_to_category(tag: String, category: String) -> Error:
	if !_is_valid_tag(tag):
		push_warning("Cannot add invalid tag: '%s'" % tag)
		return Error.FAILED

	# Use the shared tag moving logic
	var update_result = _move_tag_between_categories(tag, TAG_CATEGORY_AVAILABLE, category)
	if update_result == OK:
		# Update config based on the category
		if category == TAG_CATEGORY_ACTIVE:
			_update_active_tags_in_config()
			_update_ignored_tags_in_config()
		elif category == TAG_CATEGORY_IGNORED:
			_update_ignored_tags_in_config()
			_update_active_tags_in_config()

	return update_result


## Moves a tag between categories using TagManager
func _move_tag_between_categories(tag: String, from_category: String, to_category: String) -> Error:
	# Create available tags list that includes all currently known tags
	var available_tags := _create_available_tags_list(tag)

	# Use TagManager for moving tag between categories
	var result = TagManager.move_tag(
		tag,
		from_category,
		to_category,
		available_tags,
		_active_tags,
		_ignored_tags
	)

	# Update tags from the result
	_active_tags = result.active_tags
	_ignored_tags = result.ignored_tags

	return OK


## Creates a list of available tags including all currently known tags
func _create_available_tags_list(tag: String = "") -> Array[String]:
	var available_tags: Array[String] = []

	# Add current active and ignored tags
	available_tags.append_array(_active_tags)
	available_tags.append_array(_ignored_tags)

	# Add the new tag if provided and not already in the list
	if !tag.is_empty() && !available_tags.has(tag):
		available_tags.append(tag)

	return available_tags


## Updates active tags in configuration
func _update_active_tags_in_config() -> void:
	if _debug_filter_logging:
		print_rich("[color=#%s]DEBUG: Updating active tags in config: %s[/color]" %
			[LoggerColors.DEBUG_HTML, _active_tags])

	if _config != null:
		_config.set_active_tags(_active_tags)


## Updates ignored tags in configuration
func _update_ignored_tags_in_config() -> void:
	if _debug_filter_logging:
		print_rich("[color=#%s]DEBUG: Updating ignored tags in config: %s[/color]" %
			[LoggerColors.DEBUG_HTML, _ignored_tags])

	if _config != null:
		_config.set_ignored_tags(_ignored_tags)


# Format settings
func set_show_timestamp(show: bool) -> void:
	_show_timestamp = show
	_update_format_setting(ConfigManager.KEY_SHOW_TIMESTAMP, show)


func set_show_tags(show: bool) -> void:
	_show_tags = show
	_update_format_setting(ConfigManager.KEY_SHOW_TAGS, show)


func set_use_colors(use: bool) -> void:
	_use_colors = use
	_update_format_setting(ConfigManager.KEY_USE_COLORS, use)


func set_show_source(show: bool) -> void:
	_show_source = show
	_update_format_setting(ConfigManager.KEY_SHOW_SOURCE, show)

## Enable or disable debug logs for filtering logic
## This is useful for troubleshooting tag and level filtering
## Parameters:
## - enable: Whether to enable debug logs
func set_debug_filter_logging(enable: bool) -> void:
	_debug_filter_logging = enable

	# Always print this message regardless of the flag
	print("============================================")
	if enable:
		print_rich("[color=#%s]Advanced Logger debug filter logging ENABLED[/color]" %
			LoggerColors.SUCCESS_HTML)

		# Print current state to verify settings
		print_rich("[color=#%s]Current state: log level=%s, active_tags=%s, ignored_tags=%s[/color]" %
			[LoggerColors.INFO_HTML, LogLevel.keys()[_current_level], _active_tags, _ignored_tags])
	else:
		print_rich("[color=#%s]Advanced Logger debug filter logging DISABLED[/color]" %
			LoggerColors.INFO_HTML)
	print("============================================")

	# Force a debug print to demonstrate it's working
	if enable:
		print_rich("[color=#%s]TESTING: Debug filter logging is active. This message should appear.[/color]" %
			LoggerColors.WARNING_HTML)


## Helper for updating format settings in configuration
func _update_format_setting(key: String, value: bool) -> void:
	if _config != null:
		_config.set_value(ConfigManager.SECTION_FORMAT, key, value)
