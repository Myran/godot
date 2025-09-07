@tool
class_name LogFormatter
extends RefCounted


static func format_log(
	level: int,
	message: String,
	context: Dictionary,
	tags: Array[String],
	source_info: Dictionary,
	show_timestamp: bool,
	show_tags: bool,
	use_colors: bool,
	show_source: bool,
	timestamp_color_override: String = "" # Add new optional parameter
) -> String:
	var platform: String = OS.get_name()
	if (platform == "Android" or platform == "iOS") and use_colors:
		use_colors = false
	var parts: Array[String] = []

	const FILE_KEY: String = "file"
	const LINE_KEY: String = "line"

	const LOG_LEVEL_WIDTH: int = 10 # Increased from 5
	const TAGS_WIDTH: int = 45 # Increased from 30 to provide more space for tags

	if show_timestamp:
		var dt: Dictionary = Time.get_datetime_dict_from_system()
		var timestamp: String = (
			"%04d-%02d-%02d %02d:%02d:%02d"
			% [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
		)

		if use_colors:
			var color_to_use: String = LoggerColors.TIMESTAMP_HTML
			if not timestamp_color_override.is_empty():
				color_to_use = timestamp_color_override
			parts.append("[color=#%s]%s[/color]" % [color_to_use, timestamp])
		else:
			parts.append(timestamp)

	var LoggerScript: GDScript = load("res://addons/advanced_logger/core/logger.gd")
	if not LoggerScript:
		push_error("Failed to load Logger script in LogFormatter.format_log")
		return "ERROR: Could not format log message (Logger script load failed)."

	var level_str: String = LoggerScript.LogLevel.keys()[level]
	if level_str.length() > LOG_LEVEL_WIDTH:
		level_str = level_str.substr(0, LOG_LEVEL_WIDTH - 3) + "..." # Truncate if too long

	var padded_level: String = _pad_right(level_str, LOG_LEVEL_WIDTH) # Pad after potential truncate

	if use_colors and _get_level_html_color(level) != "":
		parts.append("[color=#%s]%s[/color]" % [_get_level_html_color(level), padded_level])
	else:
		parts.append(padded_level)

	var tags_part: String = ""
	if show_tags:
		if not tags.is_empty():
			var tags_text: String = "[%s]" % ", ".join(tags)
			if tags_text.length() > TAGS_WIDTH:
				tags_text = tags_text.substr(0, TAGS_WIDTH - 3) + "..." # Indicate truncation
			tags_part = _pad_right(tags_text, TAGS_WIDTH)
		else:
			tags_part = " ".repeat(TAGS_WIDTH)

		if use_colors:
			parts.append("[color=#%s]%s[/color]" % [LoggerColors.TAG_HTML, tags_part])
		else:
			parts.append(tags_part)

	if use_colors and _get_level_html_color(level) != "":
		parts.append("[color=#%s]%s[/color]" % [_get_level_html_color(level), message])
	else:
		parts.append(message)

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

	return " ".join(parts)

static func _get_level_html_color(level: int) -> String:

	match level:
		ALogger.LogLevel.DEBUG:
			return LoggerColors.DEBUG_HTML
		ALogger.LogLevel.INFO:
			return LoggerColors.INFO_HTML
		ALogger.LogLevel.WARNING:
			return LoggerColors.WARNING_HTML
		ALogger.LogLevel.ERROR:
			return LoggerColors.ERROR_HTML
		ALogger.LogLevel.CRITICAL:
			return LoggerColors.CRITICAL_HTML
	return ""

static func _pad_right(text: String, width: int) -> String:
	var len: int = text.length()
	if len >= width:
		return text # Return original if already wider or equal
	return text + " ".repeat(width - len)
