@tool
class_name LogFormatter
extends RefCounted
## Handles formatting of log messages
##
## Centralizes all log message formatting logic to improve maintainability
## and enable future customization options.

# Reference to the color palette
const LogLevel = preload("res://addons/advanced_logger/core/logger.gd").LogLevel

## Formats a log message with appropriate styling
##
## Parameters:
## - level: Log level enum value
## - message: Main log message
## - context: Optional context dictionary
## - tags: Array of tags associated with the message
## - source_info: Dictionary with source file information
## - show_timestamp: Whether to include timestamp
## - show_tags: Whether to include tags
## - use_colors: Whether to use colors in output
## - show_source: Whether to show source file information
##
## Returns: Formatted log string ready for print_rich()
static func format_log(
	level: int,
	message: String,
	context: Dictionary,
	tags: Array[String],
	source_info: Dictionary,
	show_timestamp: bool,
	show_tags: bool,
	use_colors: bool,
	show_source: bool
) -> String:
	var parts: Array[String] = []

	# Constants for dictionary keys
	const FILE_KEY: String = "file"
	const LINE_KEY: String = "line"

	# Fixed width for log levels (padded to the width of "CRITICAL")
	const LOG_LEVEL_WIDTH: int = 5  # "CRITICAL" is 8 chars + 1 for spacing
	# Fixed width for tags section
	const TAGS_WIDTH: int = 10

	# Add timestamp if enabled
	if show_timestamp:
		var dt: Dictionary = Time.get_datetime_dict_from_system()
		var timestamp: String = (
			"%04d-%02d-%02d %02d:%02d:%02d"
			% [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
		)

		if use_colors:
			parts.append("[color=#%s]%s[/color]" % [LoggerColors.TIMESTAMP_HTML, timestamp])
		else:
			parts.append(timestamp)

	# Add log level with fixed width using padding helper
	var level_str: String = LogLevel.keys()[level]
	# Ensure level string doesn't exceed width (though unlikely with standard levels)
	if level_str.length() > LOG_LEVEL_WIDTH:
		level_str = level_str.substr(0, LOG_LEVEL_WIDTH - 3) + "..." # Truncate if too long

	var padded_level: String = _pad_right(level_str, LOG_LEVEL_WIDTH) # Pad after potential truncate

	if use_colors and _get_level_html_color(level) != "":
		parts.append("[color=#%s]%s[/color]" % [_get_level_html_color(level), padded_level])
	else:
		parts.append(padded_level)

	# Add tags if enabled and present, with fixed width
	var tags_part = ""
	if show_tags:
		if not tags.is_empty():
			var tags_text: String = "[%s]" % ", ".join(tags)
			# Truncate if tags string exceeds width
			if tags_text.length() > TAGS_WIDTH:
				tags_text = tags_text.substr(0, TAGS_WIDTH - 3) + "..." # Indicate truncation
			tags_part = _pad_right(tags_text, TAGS_WIDTH)
		else:
			# Add empty space to maintain alignment even when no tags
			tags_part = " ".repeat(TAGS_WIDTH)

		if use_colors:
			parts.append("[color=#%s]%s[/color]" % [LoggerColors.TAG_HTML, tags_part])
		else:
			parts.append(tags_part)

	# Add message (always included)
	if use_colors and _get_level_html_color(level) != "":
		parts.append("[color=#%s]%s[/color]" % [_get_level_html_color(level), message])
	else:
		parts.append(message)

	# Add context if present
	if not context.is_empty():
		parts.append(str(context))

	if show_source:
		var file_name: String = String(source_info.get(FILE_KEY, "unknown")).get_file()
		var line: int = int(source_info.get(LINE_KEY, 0))
		var source_text: String = "(%s:%d)" % [file_name, line]

		if use_colors:
			parts.append("[color=#%s]%s[/color]" % [LoggerColors.TIMESTAMP_HTML, source_text])
		else:
			parts.append(source_text)

	# Return the formatted log
	return " ".join(parts)

## Helper function to get HTML color code for a log level
static func _get_level_html_color(level: int) -> String:
	match level:
		LogLevel.DEBUG:
			return LoggerColors.DEBUG_HTML
		LogLevel.INFO:
			return LoggerColors.INFO_HTML
		LogLevel.WARNING:
			return LoggerColors.WARNING_HTML
		LogLevel.ERROR:
			return LoggerColors.ERROR_HTML
		LogLevel.CRITICAL:
			return LoggerColors.CRITICAL_HTML
	return ""

## Helper function to pad a string to a specific width (right padding)
static func _pad_right(text: String, width: int) -> String:
	var len = text.length()
	if len >= width:
		return text # Return original if already wider or equal
	return text + " ".repeat(width - len)
