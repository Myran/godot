@tool
class_name AndroidLoggerHelper
extends RefCounted
## Helper class for Android-specific logging functionality

## Checks if the platform is Android
static func is_android() -> bool:
	return OS.get_name() == "Android"

## Gets the proper config path for the current platform
static func get_config_path() -> String:
	if is_android():
		# On Android, use user:// directory for writable config
		return "user://advanced_logger_settings.cfg"
	else:
		# On desktop platforms, use res:// directory
		return "res://addons/advanced_logger/settings.cfg"

## Ensures the logger is properly configured for Android
static func configure_for_android(logger: ALogger) -> void:
	if not is_android():
		return

	# Android-specific settings
	if not Engine.is_editor_hint():
		# Disable rich text colors for better logcat compatibility
		logger.set_use_colors(false)
		print("[Advanced Logger] Android configuration applied")

## Strips color and formatting codes from log messages for Android
static func strip_formatting(message: String) -> String:
	# Remove BBCode formatting
	var result = message.replace("[/color]", "")

	# Remove color tags with regex
	var regex = RegEx.new()
	regex.compile("\\[color=#[0-9a-fA-F]+\\]")
	result = regex.sub(result, "", true)

	# Remove other BBCode tags if present
	regex.compile("\\[/?[a-zA-Z]+\\]")
	result = regex.sub(result, "", true)

	return result
