@tool
class_name LoggerSettings
extends RefCounted
## Utility class for managing Logger settings

const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"

# Using standard Error enum values to ensure compatibility
enum SettingsError {
	OK = Error.OK,
	INVALID_LOGGER = Error.FAILED,
	FAILED_TO_SAVE = Error.ERR_CANT_CREATE,
	FAILED_TO_LOAD = Error.ERR_CANT_OPEN,
	VALIDATION_ERROR = Error.ERR_INVALID_DATA
}

## Settings structure with default values
class Settings:
	var log_level: int = Logger.LogLevel.INFO
	var buffer_size: int = 1000
	var retro_window: int = 300
	var active_tags: PackedStringArray = PackedStringArray()
	var run_tests: bool = true

	## Validate settings against constraints
	func validate() -> Error:
		if log_level < Logger.LogLevel.DEBUG or log_level > Logger.LogLevel.CRITICAL:
			push_error("Invalid log level: %d" % log_level)
			return Error.ERR_INVALID_DATA

		if buffer_size < Logger.LoggerConfig.MIN_BUFFER_SIZE or buffer_size > Logger.LoggerConfig.MAX_BUFFER_SIZE:
			push_error("Invalid buffer size: %d" % buffer_size)
			return Error.ERR_INVALID_DATA

		if retro_window < Logger.LoggerConfig.MIN_TIME_WINDOW or retro_window > Logger.LoggerConfig.MAX_TIME_WINDOW:
			push_error("Invalid retroactive window: %d" % retro_window)
			return Error.ERR_INVALID_DATA

		return Error.OK

## Save Logger settings to config file
static func save_settings(logger_instance: Logger, run_tests: bool = true) -> Error:
	if not logger_instance:
		push_error("Cannot save settings: logger instance is null")
		return Error.FAILED

	# Create settings object
	var settings := Settings.new()
	settings.log_level = logger_instance._current_level
	settings.buffer_size = logger_instance._buffer.buffer.size()
	settings.retro_window = logger_instance._config.retroactive_time_window
	settings.active_tags = PackedStringArray(logger_instance._active_tags)
	settings.run_tests = run_tests

	# Validate settings
	var validation_result = settings.validate()
	if validation_result != Error.OK:
		push_error("Settings validation failed: %d" % validation_result)
		return validation_result

	# Save settings to config file
	var config := ConfigFile.new()
	config.set_value("logger", "log_level", settings.log_level)
	config.set_value("logger", "buffer_size", settings.buffer_size)
	config.set_value("logger", "retro_window", settings.retro_window)
	config.set_value("logger", "active_tags", settings.active_tags)
	config.set_value("logger", "run_tests", settings.run_tests)

	var save_result := config.save(CONFIG_PATH)
	if save_result != Error.OK:
		push_error("Failed to save logger settings: %d" % save_result)
		return Error.ERR_CANT_CREATE

	return Error.OK

## Load settings into a Settings object
static func load_to_settings() -> Settings:
	var settings := Settings.new()
	var config := ConfigFile.new()

	var load_result = config.load(CONFIG_PATH)
	if load_result != Error.OK:
		print_rich("[color=yellow]Logger settings not found, using defaults[/color]")
		return settings

	# Load with validation
	if config.has_section_key("logger", "log_level"):
		var level = config.get_value("logger", "log_level") as int
		if level >= Logger.LogLevel.DEBUG and level <= Logger.LogLevel.CRITICAL:
			settings.log_level = level
		else:
			push_warning("Invalid log level in settings: %d (using default)" % level)

	if config.has_section_key("logger", "buffer_size"):
		var size = config.get_value("logger", "buffer_size") as int
		if size >= Logger.LoggerConfig.MIN_BUFFER_SIZE and size <= Logger.LoggerConfig.MAX_BUFFER_SIZE:
			settings.buffer_size = size
		else:
			push_warning("Invalid buffer size in settings: %d (using default)" % size)

	if config.has_section_key("logger", "retro_window"):
		var window = config.get_value("logger", "retro_window") as int
		if window >= Logger.LoggerConfig.MIN_TIME_WINDOW and window <= Logger.LoggerConfig.MAX_TIME_WINDOW:
			settings.retro_window = window
		else:
			push_warning("Invalid retroactive window in settings: %d (using default)" % window)

	if config.has_section_key("logger", "active_tags"):
		var tags = config.get_value("logger", "active_tags")
		if typeof(tags) == TYPE_PACKED_STRING_ARRAY:
			settings.active_tags = tags
		else:
			push_warning("Invalid tags in settings (using default)")

	if config.has_section_key("logger", "run_tests"):
		var run_tests = config.get_value("logger", "run_tests")
		if typeof(run_tests) == TYPE_BOOL:
			settings.run_tests = run_tests
		else:
			push_warning("Invalid run_tests in settings (using default)")

	return settings

## Load Logger settings from config file and apply to logger instance
static func load_settings(logger_instance: Logger) -> Error:
	if not logger_instance:
		push_error("Cannot load settings: logger instance is null")
		return Error.FAILED

	var settings = load_to_settings()

	# Validate settings before applying
	var validation_result = settings.validate()
	if validation_result != Error.OK:
		push_warning("Settings validation failed, using safe defaults")
		# Still continue with the validated defaults

	# Apply settings to logger - using try/apply pattern for safety
	var result = logger_instance.set_level(settings.log_level)
	if result != Error.OK:
		push_error("Failed to set log level: %d" % result)

	result = logger_instance.set_buffer_size(settings.buffer_size)
	if result != Error.OK:
		push_error("Failed to set buffer size: %d" % result)

	result = logger_instance.set_retroactive_window(settings.retro_window)
	if result != Error.OK:
		push_error("Failed to set retroactive window: %d" % result)

	# Apply tags
	logger_instance.clear_tags()
	for tag in settings.active_tags:
		if not tag.is_empty():
			result = logger_instance.add_tag(tag)
			if result != Error.OK:
				push_warning("Failed to add tag: %s" % tag)

	return Error.OK

## Get run_tests setting from config file
static func should_run_tests() -> bool:
	return load_to_settings().run_tests

## Apply settings from one logger to another with full error handling
static func apply_logger_to_logger(source: Logger, target: Logger) -> Error:
	if not source or not target:
		push_error("Cannot sync loggers: one or both instances are null")
		return Error.FAILED

	var result := Error.OK

	# Apply level
	var level_result = target.set_level(source._current_level)
	if level_result != Error.OK:
		push_error("Failed to apply log level to target logger")
		result = level_result

	# Apply buffer size
	var buffer_result = target.set_buffer_size(source._buffer.buffer.size())
	if buffer_result != Error.OK:
		push_error("Failed to apply buffer size to target logger")
		result = buffer_result

	# Apply retroactive window
	var window_result = target.set_retroactive_window(source._config.retroactive_time_window)
	if window_result != Error.OK:
		push_error("Failed to apply retroactive window to target logger")
		result = window_result

	# Apply tags
	target.clear_tags()
	for tag in source._active_tags:
		var tag_result = target.add_tag(tag)
		if tag_result != Error.OK:
			push_warning("Failed to apply tag to target logger: %s" % tag)
			result = tag_result

	return result
