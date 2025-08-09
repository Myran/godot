@tool
class_name AndroidLoggerHelper
extends RefCounted

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
	var formatted = MobileFormatter.format_log_message(level, message, context, tags)

	return strip_formatting(formatted)
