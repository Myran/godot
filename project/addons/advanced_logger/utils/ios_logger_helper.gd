@tool
class_name IosLoggerHelper
extends RefCounted

const MobileFormatter = preload("res://addons/advanced_logger/utils/mobile_formatter.gd")

static func is_ios() -> bool:
	return OS.get_name() == "iOS"

static func get_config_path() -> String:
	if is_ios():
		return "user://advanced_logger_settings.cfg"
	else:
		return "res://addons/advanced_logger/settings.cfg"

static func configure_for_ios(logger: ALogger) -> void:
	if not is_ios():
		return

	if not Engine.is_editor_hint():
		logger.set_use_colors(false)
		print("[Advanced Logger] iOS configuration applied")

static func strip_formatting(message: String) -> String:
	return MobileFormatter.strip_formatting(message)

static func process_log_message(level: int, message: String, context: Dictionary, tags: Array[String] = []) -> String:
	var formatted = MobileFormatter.format_log_message(level, message, context, tags)

	return strip_formatting(formatted)
