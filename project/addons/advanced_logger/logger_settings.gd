@tool
class_name LoggerSettings
extends RefCounted
## Simple utility class for managing Logger settings

const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"

## Save Logger settings to config file
static func save_settings(logger_instance: Logger) -> Error:
	if not logger_instance:
		push_error("Cannot save settings: logger instance is null")
		return Error.FAILED

	var config: ConfigFile = ConfigFile.new()
	if config == null:
		push_error("Failed to create ConfigFile")
		return Error.FAILED

	# Logger general settings
	config.set_value("logger", "log_level", logger_instance._current_level)

	# Tag settings
	var active_tags: Array[String] = logger_instance._active_tags
	var ignored_tags: Array[String] = logger_instance._ignored_tags

	config.set_value("logger", "active_tags", PackedStringArray(active_tags))
	config.set_value("logger", "ignored_tags", PackedStringArray(ignored_tags))

	# Format settings
	config.set_value("format", "show_timestamp", logger_instance._show_timestamp)
	config.set_value("format", "show_tags", logger_instance._show_tags)
	config.set_value("format", "use_colors", logger_instance._use_colors)

	var save_result: Error = config.save(CONFIG_PATH)
	if save_result != OK:
		push_error("Failed to save logger settings: %d" % save_result)
		return save_result

	return OK

## Load Logger settings from config file and apply to logger instance
static func load_settings(logger_instance: Logger) -> Error:
	if not logger_instance:
		push_error("Cannot load settings: logger instance is null")
		return Error.FAILED

	var config: ConfigFile = ConfigFile.new()
	if config == null:
		push_error("Failed to create ConfigFile")
		return Error.FAILED

	var load_result: Error = config.load(CONFIG_PATH)
	if load_result != OK:
		# It's fine if file doesn't exist yet - just use defaults
		if load_result == ERR_FILE_NOT_FOUND:
			print("Logger settings file not found, using defaults")
			return OK
		else:
			push_error("Failed to load logger settings: %d" % load_result)
			return load_result

	# Logger general settings
	if config.has_section_key("logger", "log_level"):
		var level: int = config.get_value("logger", "log_level") as int
		if level >= 0 and level <= Logger.LogLevel.size() - 1:
			logger_instance.set_level(level)

	# Clear existing tags
	logger_instance.clear_tags()
	logger_instance.clear_ignored_tags()

	# Tag settings
	if config.has_section_key("logger", "active_tags"):
		var tags = config.get_value("logger", "active_tags")
		if tags is PackedStringArray:
			for tag in tags:
				if tag is String and not tag.is_empty():
					logger_instance.add_tag(tag)

	if config.has_section_key("logger", "ignored_tags"):
		var tags = config.get_value("logger", "ignored_tags")
		if tags is PackedStringArray:
			for tag in tags:
				if tag is String and not tag.is_empty():
					logger_instance.add_ignored_tag(tag)

	# Format settings
	if config.has_section_key("format", "show_timestamp"):
		var show_timestamp = config.get_value("format", "show_timestamp")
		if typeof(show_timestamp) == TYPE_BOOL:
			logger_instance.set_show_timestamp(show_timestamp)

	if config.has_section_key("format", "show_tags"):
		var show_tags = config.get_value("format", "show_tags")
		if typeof(show_tags) == TYPE_BOOL:
			logger_instance.set_show_tags(show_tags)

	if config.has_section_key("format", "use_colors"):
		var use_colors = config.get_value("format", "use_colors")
		if typeof(use_colors) == TYPE_BOOL:
			logger_instance.set_use_colors(use_colors)

	return OK
