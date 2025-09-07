@tool
class_name AndroidLoggerHelper
extends RefCounted

const MobileFormatter = preload("res://addons/advanced_logger/utils/mobile_formatter.gd")

# Android kernel log entry size limits - CORRECTED WITH ACTUAL KERNEL LIMITS
const ANDROID_KERNEL_LIMIT: int = 4076     # LOGGER_ENTRY_MAX_PAYLOAD - absolute Android kernel limit
const ANDROID_EFFECTIVE_LIMIT: int = 4000  # Effective limit accounting for Android logcat formatting
const CHUNK_OVERHEAD: int = 200             # Overhead for chunk headers + MobileFormatter + context
const MAX_CHUNK_SIZE: int = 3500            # Safe chunk size: 4000 - 200 overhead - 300 safety margin
const MIN_CHUNK_SIZE: int = 1000            # Minimum acceptable chunk size for meaningful content

static func is_android() -> bool:
	return OS.get_name() == "Android"

static func get_config_path() -> String:
	if is_android():
		return "user://advanced_logger_settings.cfg"
	else:
		return "res://addons/advanced_logger/settings.cfg"

static func configure_for_android(logger: ALogger) -> void:
	if not is_android():
		return

	if not Engine.is_editor_hint():
		logger.set_use_colors(false)
		print("[Advanced Logger] Android configuration applied")

static func strip_formatting(message: String) -> String:
	return MobileFormatter.strip_formatting(message)

static func process_log_message(level: int, message: String, context: Dictionary, tags: Array[String] = []) -> String:
	# Check if chunking is needed
	if _should_chunk_message(message, context, tags):
		return _process_chunked_message(level, message, context, tags)
	else:
		# Standard processing for small messages
		var formatted = MobileFormatter.format_log_message(level, message, context, tags)
		return strip_formatting(formatted)

static func _should_chunk_message(message: String, context: Dictionary, tags: Array[String]) -> bool:
	# Calculate the FINAL formatted message size that will be sent to Android logcat
	var test_formatted = MobileFormatter.format_log_message(1, message, context, tags)
	var final_message_size = test_formatted.length()

	# Check if FINAL formatted message exceeds Android's effective limit
	var should_chunk = final_message_size > ANDROID_EFFECTIVE_LIMIT

	if should_chunk:
		print("[AndroidLoggerHelper] CHUNK: Final formatted size: %d bytes, Android limit: %d, chunking required" % [final_message_size, ANDROID_EFFECTIVE_LIMIT])

	return should_chunk

static func _process_chunked_message(level: int, message: String, context: Dictionary, tags: Array[String]) -> String:
	# Generate unique message ID for chunk correlation
	var msg_id = _generate_message_id()

	# First create the fully formatted message (this is what actually gets sent to logcat)
	var full_formatted = MobileFormatter.format_log_message(level, message, context, tags)
	var full_formatted_stripped = strip_formatting(full_formatted)

	# Split the FORMATTED message into chunks that fit within Android limits
	var chunks = _chunk_formatted_message(full_formatted_stripped)
	var total_chunks = chunks.size()

	# Process each chunk with chunk headers
	var result_lines: Array[String] = []

	for i in range(total_chunks):
		var chunk_number = i + 1
		var chunk_content = chunks[i]

		# Add chunk header with explicit boundary markers
		var chunked_message = "[CHUNK %d/%d] [MSG_ID: %s] <START>%s<END>" % [chunk_number, total_chunks, msg_id, chunk_content]
		result_lines.append(chunked_message)

	return "\n".join(result_lines)

static func _chunk_formatted_message(formatted_content: String) -> Array[String]:
	var chunks: Array[String] = []
	var current_content = formatted_content

	# Android logcat line limit is 1066 bytes total
	# Logcat overhead: ~74 bytes (timestamp, PID, TID, level, tag, chunk header, <START>)
	# Available content: 1066 - 74 - 5 (<END>) = 987 bytes
	var safe_chunk_size = 950  # Conservative 950 bytes per chunk to ensure <END> marker fits

	while current_content.length() > safe_chunk_size:
		var chunk_size = safe_chunk_size
		var substring = current_content.substr(0, chunk_size)

		# Try to find a good break point at a newline to avoid splitting JSON
		var newline_index = substring.rfind('\n')
		if newline_index >= MIN_CHUNK_SIZE:
			# Found a good newline break point
			substring = substring.substr(0, newline_index)
			chunk_size = newline_index

		# Add this chunk
		chunks.append(substring)

		# Remove the processed part
		current_content = current_content.substr(chunk_size)

		# Skip the newline character if we split at one
		if newline_index >= MIN_CHUNK_SIZE and current_content.begins_with('\n'):
			current_content = current_content.substr(1)

	# Add the remaining content as the final chunk
	if not current_content.is_empty():
		chunks.append(current_content)

	print("[AndroidLoggerHelper] DEBUG: Split %d byte formatted message into %d chunks (max chunk size: %d, with boundary markers)" % [formatted_content.length(), chunks.size(), safe_chunk_size])
	return chunks

static func _chunk_message(message: String) -> Array[String]:
	var chunks: Array[String] = []
	var current_message = message

	# Use a smaller raw chunk size to account for chunk headers + MobileFormatter overhead
	# Format: "[CHUNK X/Y] [MSG_ID: abc123] " = ~30 bytes + MobileFormatter overhead ~500 bytes
	var safe_raw_chunk_size = ANDROID_EFFECTIVE_LIMIT - 600  # 3400 bytes for raw content

	while current_message.length() > safe_raw_chunk_size:
		var chunk_size = safe_raw_chunk_size
		var substring = current_message.substr(0, chunk_size)

		# Try to find a good break point at a newline to avoid splitting JSON
		var newline_index = substring.rfind('\n')
		if newline_index >= MIN_CHUNK_SIZE:
			# Found a good newline break point
			substring = substring.substr(0, newline_index)
			chunk_size = newline_index

		# Add this chunk
		chunks.append(substring)

		# Remove the processed part from the message
		current_message = current_message.substr(chunk_size)

		# Skip the newline character if we split at one
		if newline_index >= MIN_CHUNK_SIZE and current_message.begins_with('\n'):
			current_message = current_message.substr(1)

	# Add the remaining message as the final chunk
	if not current_message.is_empty():
		chunks.append(current_message)

	print("[AndroidLoggerHelper] DEBUG: Split %d byte message into %d chunks (max raw chunk size: %d)" % [message.length(), chunks.size(), safe_raw_chunk_size])
	return chunks

static func _generate_message_id() -> String:
	# Generate a simple unique ID based on time and random
	var time_ms = Time.get_ticks_msec()
	var random_suffix = randi() % 1000
	return "%x%03x" % [time_ms & 0xFFFFFF, random_suffix]
