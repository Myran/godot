@tool
class_name MobileFormatter
extends RefCounted

static func get_level_string(level: int) -> String:
	var level_str = "INFO"
	match level:
		0: level_str = "DEBUG"
		1: level_str = "INFO"
		2: level_str = "WARNING"
		3: level_str = "ERROR"
		4: level_str = "CRITICAL"
	return level_str

static func format_log_message(level: int, message: String, context: Dictionary, tags: Array[String] = []) -> String:
	if message.begins_with("[BUFFER]"):
		return _format_buffer_entry(message, context, tags)
	elif message.begins_with("[CHUNK"):
		return _format_chunk_entry(level, message, context, tags)
	else:
		return _format_standard_entry(level, message, context, tags)

static func _format_buffer_entry(message: String, context: Dictionary, tags: Array[String]) -> String:
	var formatted = message

	var tag_part = ""
	if not tags.is_empty():
		tag_part = " [" + ", ".join(tags) + "]"

	if not context.is_empty():
		formatted += tag_part + " " + str(context)
	else:
		formatted += tag_part

	return formatted

static func _format_chunk_entry(level: int, message: String, context: Dictionary, tags: Array[String]) -> String:
	# For chunked messages, preserve the chunk header and add level/tags
	var formatted = "[%s] %s" % [get_level_string(level), message]

	if not tags.is_empty():
		formatted += " [" + ", ".join(tags) + "]"

	if not context.is_empty():
		formatted += " " + str(context)

	return formatted

static func _format_standard_entry(level: int, message: String, context: Dictionary, tags: Array[String]) -> String:
	var formatted = "[%s]" % get_level_string(level)

	if not tags.is_empty():
		formatted += " [" + ", ".join(tags) + "]"

	formatted += " " + message

	if not context.is_empty():
		formatted += " " + str(context)

	return formatted

static func strip_formatting(message: String) -> String:

	var level_pattern = "^\\[(DEBUG|INFO|WARNING|ERROR|CRITICAL|BUFFER)\\]"
	var has_level_prefix = false
	var level_prefix = ""

	var regex = RegEx.new()
	regex.compile(level_pattern)
	var result = regex.search(message)

	if result:
		has_level_prefix = true
		level_prefix = result.get_string()

	var cleaned = message

	cleaned = cleaned.replace("[/color]", "")

	regex.compile("\\[color=#[0-9a-fA-F]+\\]")
	cleaned = regex.sub(cleaned, "", true)

	regex.compile("\\[/?[a-zA-Z]+\\]")
	cleaned = regex.sub(cleaned, "", true)

	regex.compile("\\[(\\d+;)*\\d+m")
	cleaned = regex.sub(cleaned, "", true)

	regex.compile("\\[\\d+[A-Za-z]")
	cleaned = regex.sub(cleaned, "", true)

	if has_level_prefix and not cleaned.begins_with(level_prefix):
		cleaned = level_prefix + " " + cleaned.strip_edges(true, false)

	return cleaned
