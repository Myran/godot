@tool
class_name MobileFormatter
extends RefCounted
## Shared formatter for mobile platforms (iOS and Android)
## Provides consistent formatting across mobile platforms

## Get level string from enum value
static func get_level_string(level: int) -> String:
	var level_str = "INFO"
	match level:
		0: level_str = "DEBUG"
		1: level_str = "INFO"
		2: level_str = "WARNING"
		3: level_str = "ERROR"
		4: level_str = "CRITICAL"
	return level_str

## Format a log message for mobile platforms
## Ensures consistent formatting across iOS and Android
static func format_log_message(level: int, message: String, context: Dictionary, tags: Array[String] = []) -> String:
	# For buffer entries, handle specially
	if message.begins_with("[BUFFER]"):
		return _format_buffer_entry(message, context, tags)
	else:
		return _format_standard_entry(level, message, context, tags)

## Format a buffer entry
static func _format_buffer_entry(message: String, context: Dictionary, tags: Array[String]) -> String:
	# Start with the buffer message
	var formatted = message

	# Add tags before context (if present)
	var tag_part = ""
	if not tags.is_empty():
		tag_part = " [" + ", ".join(tags) + "]"

	# Add context if not empty
	if not context.is_empty():
		formatted += tag_part + " " + str(context)
	else:
		formatted += tag_part

	return formatted

## Format a standard log entry
static func _format_standard_entry(level: int, message: String, context: Dictionary, tags: Array[String]) -> String:
	# Start with level
	var formatted = "[%s]" % get_level_string(level)

	# Add tags between level and message
	if not tags.is_empty():
		formatted += " [" + ", ".join(tags) + "]"

	# Add message
	formatted += " " + message

	# Add context if not empty
	if not context.is_empty():
		formatted += " " + str(context)

	return formatted

## Strip formatting from a message (platform-specific implementations may add their own)
static func strip_formatting(message: String) -> String:
	# Be careful not to remove log level indicators like [INFO] or [DEBUG]
	# We need to identify and preserve these while removing formatting codes

	# First, check if the message starts with a log level indicator
	# Common log level patterns like [INFO], [DEBUG], [WARNING], etc.
	var level_pattern = "^\\[(DEBUG|INFO|WARNING|ERROR|CRITICAL|BUFFER)\\]"
	var has_level_prefix = false
	var level_prefix = ""

	var regex = RegEx.new()
	regex.compile(level_pattern)
	var result = regex.search(message)

	if result:
		has_level_prefix = true
		level_prefix = result.get_string()
		# Store the prefix to add back later

	# Now strip all formatting
	var cleaned = message

	# Remove BBCode formatting
	cleaned = cleaned.replace("[/color]", "")

	# Remove color tags with regex
	regex.compile("\\[color=#[0-9a-fA-F]+\\]")
	cleaned = regex.sub(cleaned, "", true)

	# Remove other BBCode tags if present
	regex.compile("\\[/?[a-zA-Z]+\\]")
	cleaned = regex.sub(cleaned, "", true)

	# Remove ANSI color escape sequences
	# This handles standard ANSI color codes like [38;2;216;166;87m and [39m
	regex.compile("\\[(\\d+;)*\\d+m")
	cleaned = regex.sub(cleaned, "", true)

	# Handle other ANSI escape sequences if needed
	regex.compile("\\[\\d+[A-Za-z]")
	cleaned = regex.sub(cleaned, "", true)

	# If we accidentally removed a valid log level prefix, add it back
	if has_level_prefix and not cleaned.begins_with(level_prefix):
		cleaned = level_prefix + " " + cleaned.strip_edges(true, false)

	return cleaned
