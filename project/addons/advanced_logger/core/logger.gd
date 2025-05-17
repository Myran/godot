@tool
class_name ALogger extends Node
## Simple logging system with tags and levels
enum LogLevel { DEBUG, INFO, WARNING, ERROR, CRITICAL }
# Make sure dependencies are preloaded
const TagManager = preload("res://addons/advanced_logger/utils/tag_manager.gd")
const ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")
const LogFormatter = preload("res://addons/advanced_logger/core/log_formatter.gd")
# Platform-specific helpers (loaded conditionally)
# We don't preload these to avoid issues if they don't exist
var AndroidLoggerHelper = null
var IosLoggerHelper = null



# Common tag constants
const TAG_DB: String = "database"
const TAG_CACHE: String = "cache"
const TAG_FIREBASE: String = "firebase"
const TAG_LOCAL: String = "local_data"
const TAG_ERROR: String = "error"
const TAG_NETWORK: String = "network"

# Domain-specific tag constants
const TAG_UI: String = "ui"
const TAG_UI_INPUT: String = "ui_input"
const TAG_UI_ANIMATION: String = "ui_animation"
const TAG_CARD: String = "card"
const TAG_LEVEL: String = "level"
const TAG_ITEM: String = "item"
const TAG_BATTLE: String = "battle"
const TAG_COMBAT: String = "combat"
const TAG_GAME: String = "game"
const TAG_GAME_STATE: String = "game_state"
const TAG_RNG: String = "rng"
const TAG_RULE: String = "rule"
const TAG_RULES: String = "rules"
const TAG_EVENT: String = "event"
const TAG_PLAYER: String = "player"
const TAG_INPUT: String = "input"
const TAG_SYSTEM: String = "system"
const TAG_DEBUG: String = "debug"
const TAG_DATA: String = "data"
const TAG_DRAFT: String = "draft"
const TAG_INITIALIZATION: String = "initialization"
const TAG_PERFORMANCE: String = "performance"
const TAG_VALIDATION: String = "validation"
const TAG_ANIMATION: String = "animation"
const TAG_STATE_TRANSITION: String = "state_transition"
const TAG_WIN_CONDITION: String = "win_condition"
const TAG_STAT: String = "stat"
const TAG_TEST: String = "test"
const TAG_GRID: String = "grid"
const TAG_CLICKER: String = "clicker"
const TAG_AUTH: String = "auth"
const TAG_FACEBOOK: String = "facebook"
const TAG_APPLE: String = "apple"

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

# --- BUFFER VARIABLES ---
## Stores the last N log entries as dictionaries.
var _log_buffer: Array[Dictionary] = []
## Maximum number of log entries to keep in the buffer.
var _buffer_size: int = ConfigManager.DEFAULT_BUFFER_SIZE
## Whether to dump the buffer on ERROR/CRITICAL logs.
var _enable_buffer_dump: bool = ConfigManager.DEFAULT_ENABLE_BUFFER_DUMP
## Flag to prevent dumping the buffer repeatedly for consecutive errors.
var _buffer_dumped_recently: bool = false
## Flag to indicate this logger has a custom buffer size.
var _has_custom_buffer_size: bool = false
## Flag to indicate this logger has a custom buffer dump setting.
var _has_custom_buffer_dump: bool = false

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

	# Apply platform-specific configuration
	_configure_for_platform()

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
		elif key == ConfigManager.KEY_BUFFER_SIZE and not _has_custom_buffer_size:
			# Only update buffer size if this logger doesn't have a custom size
			_buffer_size = int(value)
			_trim_buffer() # Adjust buffer immediately if size changed
		elif key == ConfigManager.KEY_ENABLE_BUFFER_DUMP and not _has_custom_buffer_dump:
			# Only update buffer dump setting if this logger doesn't have a custom setting
			_enable_buffer_dump = bool(value)
	elif section == ConfigManager.SECTION_FORMAT:
		if key == ConfigManager.KEY_SHOW_TIMESTAMP:
			_show_timestamp = value
		elif key == ConfigManager.KEY_SHOW_TAGS:
			_show_tags = value
		elif key == ConfigManager.KEY_USE_COLORS:
			_use_colors = value
		elif key == ConfigManager.KEY_SHOW_SOURCE:
			_show_source = value

# Loads settings from the ConfigManager
func _load_settings() -> void:
	# In test mode or no config available, use defaults
	if _config == null:
		return

	# General settings
	_current_level = _config.get_log_level()
	_buffer_size = _config.get_buffer_size()
	_enable_buffer_dump = _config.get_enable_buffer_dump()

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

# --- Refactored Logging Pipeline ---

## Internal logging function - handles validation, buffering, filtering, and output
func _log(level: LogLevel, message: String, context: Dictionary, tags: Array[String]) -> void:
	# 1. Validate message - Early exit if invalid
	if not _validate_message(message):
		return

	# 2. Prepare Log Entry Data
	# Use TagManager directly for validation
	var validated_tags := TagManager.validate_tags(tags)
	var log_entry_data := _create_log_entry_data(level, message, context, validated_tags)

	# 3. Buffering Logic
	_handle_buffering(log_entry_data)

	# 4. Filtering Logic
	if not _should_output_log(level, validated_tags):
		return

	# 5. Output the formatted log
	_print_formatted_log(log_entry_data)

## Creates the dictionary containing all data for a single log entry
func _create_log_entry_data(level: LogLevel, message: String, context: Dictionary, validated_tags: Array[String]) -> Dictionary:
	return {
		"level": level,
		"message": message,
		"context": context.duplicate(true), # Deep duplicate
		"tags": validated_tags.duplicate(), # Shallow duplicate is fine for array of strings
		"source_info": _get_source_info()   # Get source info
	}

## Handles adding the log entry to the buffer and triggering dumps if necessary
func _handle_buffering(log_entry_data: Dictionary) -> void:
	# Add to buffer
	_add_to_buffer(log_entry_data)

	# Check if buffer dump is needed
	var level = log_entry_data.level
	if level >= LogLevel.ERROR and _enable_buffer_dump and not _buffer_dumped_recently:
		_dump_buffer()
		_buffer_dumped_recently = true # Prevent immediate re-dumping
	elif level < LogLevel.ERROR:
		_buffer_dumped_recently = false # Reset dump flag if not high severity

## Determines if a log entry should be printed based on level and tag filters
func _should_output_log(level: LogLevel, validated_tags: Array[String]) -> bool:
	# Check level filtering first
	if not _should_show_level(level):
		return false

	# Then check tag filtering
	if not _should_show_tags(validated_tags):
		return false

	# If both pass, output the log
	return true

# --- Filtering Logic ---

## Checks if a log level should be shown based on the current threshold or level tags
func _should_show_level(level: LogLevel) -> bool:
	var level_tag: String = LEVEL_TAGS.get(level, "") # Use .get() for safety
	if level_tag.is_empty():
		push_warning("Invalid log level provided to _should_show_level: %d" % level)
		return false # Should not happen with enum, but good practice

	_debug_print_filter_check_start(level, level_tag)

	# --- Rule 1: Check Ignored Level Tag ---
	if _ignored_tags.has(level_tag):
		_debug_print_filter_result(level_tag, "Ignored Level Tag", false)
		return false

	# --- Rule 2: Check if any Active Level Tags Exist ---
	var active_level_tags = _get_active_level_tags()
	var has_active_level_filter = not active_level_tags.is_empty()

	if has_active_level_filter:
		# --- Rule 2a: Active Level Tags Override Threshold ---
		# If *any* level tag is active, we ONLY filter based on the active level tags.
		# The _current_level threshold is ignored in this case.
		# A message must match *exactly* one of the active level tags.
		# IMPORTANT: This preserves the original strict behavior where higher levels are NOT automatically shown if a lower level tag is active.
		var show_based_on_active_level = _active_tags.has(level_tag) # Exact match required
		_debug_print_filter_result(level_tag, "Active Level Tag Filter", show_based_on_active_level)
		return show_based_on_active_level
	else:
		# --- Rule 3: Use Standard Level Threshold ---
		# If no level tags are active, use the standard _current_level threshold.
		var show_based_on_threshold = level >= _current_level
		_debug_print_filter_result(LogLevel.keys()[level], "Standard Level Threshold", show_based_on_threshold)
		return show_based_on_threshold

## Check if a log should be shown based on topic tags (non-level tags)
## Parameters:
## - log_tags: Tags associated with the log message (already validated)
## Returns: True if the log should be shown based on topic tags, false otherwise
func _should_show_tags(log_tags: Array[String]) -> bool:
	_debug_print_tag_check_start(log_tags)

	# --- Rule 1: Check Ignored Topic Tags ---
	# If the log has any tag that is in the ignored list, hide it.
	for tag in log_tags:
		# This check uses the instance's _ignored_tags list directly
		if _ignored_tags.has(tag):
			_debug_print_tag_result(log_tags, "Ignored Topic Tag", false)
			return false

	# --- Rule 2: Check Active Topic Tags ---
	var active_topic_tags = _get_active_topic_tags()

	# If there are no active *topic* tags, all non-ignored messages pass this check.
	# (Level filtering is handled separately in _should_show_level)
	if active_topic_tags.is_empty():
		_debug_print_tag_result(log_tags, "No Active Topic Tags", true)
		return true

	# If there are active topic tags, the message must have at least one of them.
	for tag in log_tags:
		if active_topic_tags.has(tag):
			_debug_print_tag_result(log_tags, "Active Topic Tag Match", true)
			return true

	# If we reached here, active topic tags exist, but the message had none of them.
	_debug_print_tag_result(log_tags, "No Active Topic Tag Match", false)
	return false

## Helper function to get currently active level tags
func _get_active_level_tags() -> Array[String]:
	var level_tags: Array[String] = []
	for tag in _active_tags:
		if tag.begins_with(TAG_LEVEL_PREFIX):
			level_tags.append(tag)
	return level_tags

## Helper function to get currently active topic tags (non-level)
func _get_active_topic_tags() -> Array[String]:
	var topic_tags: Array[String] = []
	for tag in _active_tags:
		# Check instance's _active_tags list
		if not tag.begins_with(TAG_LEVEL_PREFIX):
			topic_tags.append(tag)
	return topic_tags

# --- Debug Printing Helpers for Filtering ---

func _debug_print_filter_check_start(level: LogLevel, level_tag: String) -> void:
	if _debug_filter_logging:
		print_rich("[color=#%s]DEBUG: Filtering check for level %s (tag: %s)[/color]" %
			[LoggerColors.DEBUG_HTML, LogLevel.keys()[level], level_tag])
		print_rich("[color=#%s]  Current State: _current_level=%s, _active_tags=%s, _ignored_tags=%s[/color]" %
			[LoggerColors.DEBUG_HTML, LogLevel.keys()[_current_level], _active_tags, _ignored_tags])

func _debug_print_filter_result(identifier: String, reason: String, result: bool) -> void:
	if _debug_filter_logging:
		print_rich("[color=#%s]  Filter Decision (%s): %s -> %s[/color]" %
			[LoggerColors.DEBUG_HTML, reason, identifier, "SHOW" if result else "SKIP"])

func _debug_print_tag_check_start(log_tags: Array[String]) -> void:
	if _debug_filter_logging:
		print_rich("[color=#%s]DEBUG: Tag filtering check for log_tags: %s[/color]" %
			[LoggerColors.DEBUG_HTML, log_tags])
		print_rich("[color=#%s]  Current State: _active_tags=%s, _ignored_tags=%s[/color]" %
			[LoggerColors.DEBUG_HTML, _active_tags, _ignored_tags])

func _debug_print_tag_result(log_tags: Array[String], reason: String, result: bool) -> void:
	if _debug_filter_logging:
		print_rich("[color=#%s]  Tag Filter Decision (%s): %s -> %s[/color]" %
			[LoggerColors.DEBUG_HTML, reason, log_tags, "SHOW" if result else "SKIP"])

# --- Buffer Management ---

## Adds a log entry dictionary to the buffer, maintaining max size.
func _add_to_buffer(log_data: Dictionary) -> void:
	_log_buffer.append(log_data)
	# Trim the buffer if it exceeds the max size
	if _log_buffer.size() > _buffer_size:
		_log_buffer.pop_front()

## Trims the buffer to the current _buffer_size. Used when config changes.
func _trim_buffer() -> void:
	var original_size = _log_buffer.size()
	while _log_buffer.size() > _buffer_size:
		_log_buffer.pop_front()

	if original_size > _buffer_size:
		print_rich("[color=#%s]DEBUG: Buffer trimmed from %d to %d entries (max: %d)[/color]" %
			[LoggerColors.DEBUG_HTML, original_size, _log_buffer.size(), _buffer_size])

## Prints the entire contents of the log buffer to the console with clear demarcation.
func _dump_buffer() -> void:
	var header_footer_color = LoggerColors.WARNING_HTML # Yellow for visibility
	var separator = "═".repeat(80) # Use double lines for more emphasis

	# Get platform info
	var platform = OS.get_name()
	var use_plain_formatting = platform == "iOS" or platform == "Android"

	# Print header with timestamp for context
	var dt = Time.get_datetime_dict_from_system()
	var dump_timestamp = "%02d:%02d:%02d" % [dt.hour, dt.minute, dt.second]

	# Use platform-specific formatting for buffer headers
	if use_plain_formatting:
		# Plain formatting for mobile platforms
		print("\n" + separator)
		print("=== BUFFER DUMP (" + dump_timestamp + ") - Last " + str(_log_buffer.size()) + " entries ===")
		print(separator)
	else:
		# Rich formatting for desktop platforms
		print_rich("\n[color=#%s]%s[/color]" % [header_footer_color, separator])
		print_rich("[color=#%s]=== BUFFER DUMP (%s) - Last %d entries ===[/color]" %
			[header_footer_color, dump_timestamp, _log_buffer.size()])
		print_rich("[color=#%s]%s[/color]" % [header_footer_color, separator])

	# Iterate through a copy to avoid issues if buffer changes during iteration
	var buffer_copy = _log_buffer.duplicate(true) # Use deep copy for safety
	if buffer_copy.is_empty():
		if use_plain_formatting:
			print("  (Buffer is empty)")
		else:
			print_rich("[color=#%s]  (Buffer is empty)[/color]" % LoggerColors.TIMESTAMP_HTML)
	else:
		for entry_data in buffer_copy:
			# Create a deep copy to modify the message safely
			var data_to_print = entry_data.duplicate(true)
			# Mark this entry as being printed from the buffer dump
			data_to_print["is_buffer_dump"] = true

			# Print using the standard formatting function
			# Ensures buffered messages look the same as live ones, just marked
			_print_formatted_log(data_to_print)

	# Print footer
	if use_plain_formatting:
		print(separator)
		print("=== END BUFFER DUMP ===")
		print(separator + "\n")
	else:
		print_rich("[color=#%s]%s[/color]" % [header_footer_color, separator])
		print_rich("[color=#%s]=== END BUFFER DUMP ===[/color]" % header_footer_color)
		print_rich("[color=#%s]%s[/color]\n" % [header_footer_color, separator])

# --- Source Info Helpers ---

## Get source information (file, line, function)
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
## Configure logger based on platform
func _configure_for_platform() -> void:
	# Platform-specific initialization
	var platform = OS.get_name()

	# Android-specific configuration
	if platform == "Android":
		# Try to load Android helper if available
		AndroidLoggerHelper = load("res://addons/advanced_logger/utils/android_logger_helper.gd")
		if AndroidLoggerHelper:
			# Apply Android-specific configuration
			AndroidLoggerHelper.configure_for_android(self)

	# iOS-specific configuration
	elif platform == "iOS":
		# Try to load iOS helper if available
		IosLoggerHelper = load("res://addons/advanced_logger/utils/ios_logger_helper.gd")
		if IosLoggerHelper:
			# Apply iOS-specific configuration
			IosLoggerHelper.configure_for_ios(self)
		else:
			# Fallback if helper not found - basic iOS configuration
			if not Engine.is_editor_hint():
				# Force disable colors on iOS runtime for better console output
				_use_colors = false
				print("[Advanced Logger] Running on iOS - colors disabled")

## Formats and prints a single log entry dictionary
func _print_formatted_log(log_data: Dictionary) -> void:
	# Extract data from the dictionary
	var level: int = log_data.level
	var message: String = log_data.message
	var context: Dictionary = log_data.context
	var tags: Array[String] = log_data.tags
	var source_info: Dictionary = log_data.source_info
	var is_buffer_dump_entry: bool = log_data.get("is_buffer_dump", false)

	# Determine timestamp color override for buffer dump entries
	var timestamp_color_override: String = ""
	if is_buffer_dump_entry:
		timestamp_color_override = LoggerColors.WARNING_HTML # Use the header/footer color

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
		_show_source,
		timestamp_color_override # Pass the override color
	)

	# Platform-specific output formatting
	var platform = OS.get_name()

	# Android-specific output
	if platform == "Android":
		if AndroidLoggerHelper:
			# Use Android-specific formatting and processing
			if is_buffer_dump_entry:
				# For buffer entries, handle specially to maintain [BUFFER] prefix
				print(AndroidLoggerHelper.process_log_message(
					level,
					"[BUFFER] " + message,
					context,
					tags
				))
			else:
				# For regular logs, use standard processing
				print(AndroidLoggerHelper.process_log_message(
					level,
					message,
					context,
					tags
				))
		else:
			# Strip BBCode if present (fallback if helper not available)
			var plain_text = formatted_log.replace("[/color]", "").replace("[color=#", ">[")
			# Replace color tags with simple text
			var regex = RegEx.new()
			regex.compile("\\[color=#[0-9a-fA-F]+\\]")
			plain_text = regex.sub(plain_text, "", true)
			print(plain_text)

	# iOS-specific output
	elif platform == "iOS":
		if IosLoggerHelper:
			# Process the message first to format it appropriately for iOS
			var ios_formatted = IosLoggerHelper.process_log_message(
				level,
				message,
				context,
				tags
			)
			# Make absolutely sure all formatting is stripped before printing
			print(ios_formatted)
		else:
			# Strip BBCode if present (fallback if helper not available)
			var plain_text = formatted_log.replace("[/color]", "").replace("[color=#", ">[")
			# Replace color tags and ANSI escape sequences
			var regex = RegEx.new()
			regex.compile("\\[color=#[0-9a-fA-F]+\\]")
			plain_text = regex.sub(plain_text, "", true)
			# Also strip ANSI sequences
			regex.compile("\\[(\\d+;)*\\d+m")
			plain_text = regex.sub(plain_text, "", true)
			print(plain_text)

	# Default rich text output for other platforms
	else:
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
# Tag management
## Adds a tag to the active tags list.
## Ensures the tag is valid and not already active.
## Removes the tag from the ignored list if present.
## Returns OK on success, ERR_INVALID_PARAMETER for invalid tags,
## ERR_ALREADY_EXISTS if the tag is already active.
func add_tag(tag: String) -> Error:
	if not TagManager.is_valid_tag(tag):
		push_warning("Cannot add invalid tag: '%s'" % tag)
		return Error.ERR_INVALID_PARAMETER
	if _active_tags.has(tag):
		# Optionally print a message here if needed, but returning the error is key
		# print("Tag '%s' is already active." % tag)
		return Error.ERR_ALREADY_EXISTS

	# Check if the tag was previously ignored before erasing
	var was_ignored = _ignored_tags.has(tag)
	if was_ignored:
		_ignored_tags.erase(tag)

	_active_tags.append(tag)

	# Update config immediately to reflect the change
	_update_active_tags_in_config()
	if was_ignored: # Update ignored config only if it was actually removed
		_update_ignored_tags_in_config()

	return OK

## Removes a tag from the active tags list.
## Returns OK on success, ERR_DOES_NOT_EXIST if the tag wasn't active.
func remove_tag(tag: String) -> Error:
	# No need to check validity if just checking existence for removal
	if not _active_tags.has(tag):
		return Error.ERR_DOES_NOT_EXIST # Tag wasn't active

	_active_tags.erase(tag)

	# Update config immediately
	_update_active_tags_in_config()

	return OK

## Clears all active tags.
func clear_tags() -> void:
	_active_tags.clear()
	# Update config immediately
	_update_active_tags_in_config()

## Adds a tag to the ignored tags list.
## Ensures the tag is valid and not already ignored.
## Removes the tag from the active list if present.
## Returns OK on success, ERR_INVALID_PARAMETER for invalid tags,
## ERR_ALREADY_EXISTS if the tag is already ignored.
func add_ignored_tag(tag: String) -> Error:
	if not TagManager.is_valid_tag(tag):
		push_warning("Cannot add invalid ignored tag: '%s'" % tag)
		return Error.ERR_INVALID_PARAMETER
	if _ignored_tags.has(tag):
		return Error.ERR_ALREADY_EXISTS

	# Check if the tag was previously active before erasing
	var was_active = _active_tags.has(tag)
	if was_active:
		_active_tags.erase(tag)

	_ignored_tags.append(tag)

	# Update config immediately
	_update_ignored_tags_in_config()
	if was_active: # Update active config only if it was actually removed
		_update_active_tags_in_config()

	return OK

## Removes a tag from the ignored tags list.
## Returns OK on success, ERR_DOES_NOT_EXIST if the tag wasn't ignored.
func remove_ignored_tag(tag: String) -> Error:
	if not _ignored_tags.has(tag):
		return Error.ERR_DOES_NOT_EXIST # Tag wasn't ignored

	_ignored_tags.erase(tag)

	# Update config immediately
	_update_ignored_tags_in_config()

	return OK

## Clears all ignored tags.
func clear_ignored_tags() -> void:
	_ignored_tags.clear()
	# Update config immediately
	_update_ignored_tags_in_config()

# --- Config Update Helpers ---

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
# Buffer configuration methods
func set_buffer_size(size: int) -> Error:
	if size < 1:
		push_warning("Invalid buffer size: %d. Buffer size must be at least 1." % size)
		return Error.FAILED

	_buffer_size = size
	_trim_buffer() # Adjust buffer immediately

	# Flag to track if this logger has a custom buffer size
	_has_custom_buffer_size = true

	# Update config only if we want to propagate this change globally
	# Otherwise, this logger instance keeps its own buffer size
	if _config != null:
		_config.set_buffer_size(size)

	return OK

func get_buffer_size() -> int:
	return _buffer_size

func set_enable_buffer_dump(enable: bool) -> void:
	_enable_buffer_dump = enable
	_has_custom_buffer_dump = true

	# Update config
	if _config != null:
		_config.set_enable_buffer_dump(enable)

func get_enable_buffer_dump() -> bool:
	return _enable_buffer_dump

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

## Cleanup notification - properly disconnect from ConfigManager
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Disconnect from config signals
		if _config != null:
			if is_instance_valid(_config) and _config.has_signal("config_changed"):
				if _config.config_changed.is_connected(_on_config_changed):
					_config.config_changed.disconnect(_on_config_changed)
			_config = null
