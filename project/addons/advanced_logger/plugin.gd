@tool
extends EditorPlugin

var logger_dock: LoggerDock
var logger_instance: Logger
const SETTINGS_PATH: String = "res://addons/advanced_logger/settings.cfg"

func _enter_tree() -> void:
	logger_instance = Logger.new()
	logger_dock = preload("res://addons/advanced_logger/logger_dock.gd").new(logger_instance)
	add_control_to_bottom_panel(logger_dock, "Logger")
	_load_settings()

func _exit_tree() -> void:
	_save_settings()
	remove_control_from_bottom_panel(logger_dock)
	if logger_dock:
		logger_dock.free()
	if logger_instance:
		logger_instance.free()

func _save_settings() -> void:
	if not logger_dock or not logger_instance:
		return

	var settings: Dictionary = {
		"log_level": logger_instance._current_level as int,
		"buffer_size": logger_instance._buffer.buffer.size() as int,
		"retro_window": logger_instance._config.retroactive_time_window as int,
		"active_tags": PackedStringArray(logger_instance._active_tags)
	}

	var config := ConfigFile.new()
	for key: String in settings:
		config.set_value("logger", key, settings[key])

	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Failed to save logger settings: %d" % err)

func _load_settings() -> void:
	if not logger_dock or not logger_instance:
		return

	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	# Load and validate log level
	if config.has_section_key("logger", "log_level"):
		var level: Variant = config.get_value("logger", "log_level")
		if typeof(level) == TYPE_INT:
			if level >= LogLevel.DEBUG and level <= LogLevel.CRITICAL:
				logger_dock.set_log_level(level as int)

	# Load and validate buffer size
	if config.has_section_key("logger", "buffer_size"):
		var size: Variant = config.get_value("logger", "buffer_size")
		if typeof(size) == TYPE_INT:
			if size >= LoggerConfig.MIN_BUFFER_SIZE and size <= LoggerConfig.MAX_BUFFER_SIZE:
				logger_dock.set_buffer_size(size as int)

	# Load and validate retroactive window
	if config.has_section_key("logger", "retro_window"):
		var window: Variant = config.get_value("logger", "retro_window")
		if typeof(window) == TYPE_INT:
			if window >= LoggerConfig.MIN_TIME_WINDOW and window <= LoggerConfig.MAX_TIME_WINDOW:
				logger_dock.set_retro_window(window as int)

	# Load and validate tags
	if config.has_section_key("logger", "active_tags"):
		var tags: Variant = config.get_value("logger", "active_tags")
		if typeof(tags) == TYPE_PACKED_STRING_ARRAY:
			for tag in (tags as PackedStringArray):
				if typeof(tag) == TYPE_STRING and not tag.is_empty():
					logger_dock.add_tag(tag)
