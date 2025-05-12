@tool
class_name IosLoggerHelper
extends RefCounted
## Helper class for iOS-specific logging functionality

## Checks if the platform is iOS
static func is_ios() -> bool:
	return OS.get_name() == "iOS"

## Gets the proper config path for iOS platform
static func get_config_path() -> String:
	if is_ios():
		# On iOS, use user:// directory for writable config
		return "user://advanced_logger_settings.cfg"
	else:
		# On desktop platforms, use res:// directory
		return "res://addons/advanced_logger/settings.cfg"

## Ensures the logger is properly configured for iOS
static func configure_for_ios(logger: ALogger) -> void:
	if not is_ios():
		return

	# iOS-specific settings
	if not Engine.is_editor_hint():
		# iOS console has similar limitations to Android
		# Disable rich text colors for better console output
		logger.set_use_colors(false)
		print("[Advanced Logger] iOS configuration applied")

## Strips color and formatting codes from log messages for iOS
## iOS console has limitations in formatting support
static func strip_formatting(message: String) -> String:
	return MobileFormatter.strip_formatting(message)

## Process a log message specifically for iOS output
## Creates a plain format without any styling for iOS console
static func process_log_message(level: int, message: String, context: Dictionary, tags: Array[String] = []) -> String:
	# Format the message using the shared formatter
	var formatted = MobileFormatter.format_log_message(level, message, context, tags)

	# Make sure the formatted message doesn't contain any escape sequences
	return strip_formatting(formatted)
