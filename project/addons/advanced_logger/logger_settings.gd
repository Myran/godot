@tool
class_name LoggerSettings
extends RefCounted
## Utility class for managing Logger settings

# Using standard Error enum values to ensure compatibility
enum SettingsError {
	OK = Error.OK,
	INVALID_LOGGER = Error.FAILED,
	FAILED_TO_SAVE = Error.ERR_CANT_CREATE,
	FAILED_TO_LOAD = Error.ERR_CANT_OPEN,
	VALIDATION_ERROR = Error.ERR_INVALID_DATA
}
const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"

## Format settings for log output
class FormatSettings:
	enum LayoutMode { EXPANDED, COMPACT, CUSTOM }
	enum PathMode { FULL, FILENAME, SHORT, LIMITED_FOLDERS }
	# Basic Component Visibility
	var show_timestamp: bool = true
	var show_level: bool = true
	var show_tags: bool = true
	var show_context: bool = true
	var show_source: bool = true

	# Layout Options

	var layout_mode: int = LayoutMode.EXPANDED
	var component_order: Array[String] = ["timestamp", "level", "tags", "message", "source", "context"]

	# Color Settings
	var use_colors: bool = true
	var use_default_colors: bool = true
	var custom_colors: Dictionary = {
		"debug": Color("#928374"),
		"info": Color("#83a598"),
		"warning": Color("#fabd2f"),
		"error": Color("#fb4934"),
		"critical": Color("#fe8019"),
		"timestamp": Color("#928374"),
		"tags": Color("#8ec07c"),
		"source": Color("#928374")
	}

	# Path Display

	var path_mode: int = PathMode.FILENAME
	var path_folder_depth: int = 2

	# Timestamp Settings
	var timestamp_show_date: bool = true
	var timestamp_show_ms: bool = true
	var timestamp_use_24h: bool = true
	var timestamp_use_local: bool = true

	# Context Settings
	var context_multiline: bool = true
	var context_limit: int = 0  # 0 = no limit

	func to_dict() -> Dictionary:
		return {
			"show_timestamp": show_timestamp,
			"show_level": show_level,
			"show_tags": show_tags,
			"show_context": show_context,
			"show_source": show_source,

			"layout_mode": layout_mode,
			"component_order": component_order,

			"use_colors": use_colors,
			"use_default_colors": use_default_colors,
			"custom_colors": _colors_to_dict(custom_colors),

			"path_mode": path_mode,
			"path_folder_depth": path_folder_depth,

			"timestamp_show_date": timestamp_show_date,
			"timestamp_show_ms": timestamp_show_ms,
			"timestamp_use_24h": timestamp_use_24h,
			"timestamp_use_local": timestamp_use_local,

			"context_multiline": context_multiline,
			"context_limit": context_limit
		}

	# Helper to convert color dict to storable format
	func _colors_to_dict(colors: Dictionary) -> Dictionary:
		var result = {}
		for key in colors:
			result[key] = colors[key].to_html(false)
		return result

	static func from_dict(dict: Dictionary) -> FormatSettings:
		var settings = FormatSettings.new()

		# Apply all basic boolean and int values
		for key in dict:
			if key in settings and key != "custom_colors" and key != "component_order":
				settings.set(key, dict[key])

		# Handle special cases
		if "component_order" in dict and dict.component_order is Array:
			var order: Array[String] = []
			for item in dict.component_order:
				if item is String:
					order.append(item)
			if not order.is_empty():
				settings.component_order = order

		if "custom_colors" in dict and dict.custom_colors is Dictionary:
			for key in dict.custom_colors:
				if key is String and dict.custom_colors[key] is String:
					settings.custom_colors[key] = Color(dict.custom_colors[key])

		return settings

## Tag Setup structure
class TagSetup:
	var name: String
	var active_tags: PackedStringArray
	var ignored_tags: PackedStringArray
	var log_level: int

	func _init(p_name: String, p_active_tags: PackedStringArray,
				p_ignored_tags: PackedStringArray, p_log_level: int) -> void:
		name = p_name
		active_tags = p_active_tags
		ignored_tags = p_ignored_tags
		log_level = p_log_level

	func to_dict() -> Dictionary:
		return {
			"name": name,
			"active_tags": active_tags,
			"ignored_tags": ignored_tags,
			"log_level": log_level
		}

	static func from_dict(dict: Dictionary) -> TagSetup:
		return TagSetup.new(
			dict.get("name", ""),
			dict.get("active_tags", PackedStringArray()),
			dict.get("ignored_tags", PackedStringArray()),
			dict.get("log_level", Logger.LogLevel.INFO)
		)

## Settings structure with default values
class Settings:
	var log_level: int = Logger.LogLevel.INFO
	var buffer_size: int = 1000
	var retro_window: int = 300
	var active_tags: PackedStringArray = PackedStringArray()
	var ignored_tags: PackedStringArray = PackedStringArray()
	var run_tests: bool = true
	var tag_setups: Dictionary = {}  # Dictionary of saved tag setups
	var format_settings: FormatSettings = FormatSettings.new()

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
static func save_settings(logger_instance: Logger, run_tests: bool = true, tag_setups: Dictionary = {}) -> Error:
	if not logger_instance:
		push_error("Cannot save settings: logger instance is null")
		return Error.FAILED

	# Create settings object
	var settings := Settings.new()
	settings.log_level = logger_instance._current_level
	settings.buffer_size = logger_instance._buffer.buffer.size()
	settings.retro_window = logger_instance._config.retroactive_time_window
	settings.active_tags = PackedStringArray(logger_instance.get_active_tags())
	settings.ignored_tags = PackedStringArray(logger_instance.get_ignored_tags())
	settings.run_tests = run_tests

	# Copy the format settings from the logger
	if logger_instance.has("_format_settings"):
		settings.format_settings = logger_instance._format_settings

	# Add tag setups
	if tag_setups.is_empty():
		# If not provided, use existing setups
		settings.tag_setups = get_tag_setups()
	else:
		settings.tag_setups = tag_setups

	# Validate settings
	var validation_result: Error = settings.validate()
	if validation_result != Error.OK:
		push_error("Settings validation failed: %d" % validation_result)
		return Error.ERR_INVALID_DATA

	# Save settings to config file
	var config := ConfigFile.new()
	config.set_value("logger", "log_level", settings.log_level)
	config.set_value("logger", "buffer_size", settings.buffer_size)
	config.set_value("logger", "retro_window", settings.retro_window)
	config.set_value("logger", "active_tags", settings.active_tags)
	config.set_value("logger", "ignored_tags", settings.ignored_tags)
	config.set_value("logger", "run_tests", settings.run_tests)

	# Save tag setups
	var setups_dict = {}
	for key in settings.tag_setups.keys():
		var setup = settings.tag_setups[key]
		setups_dict[key] = setup.to_dict()
	config.set_value("tag_setups", "setups", setups_dict)

	# Save format settings
	config.set_value("format", "settings", settings.format_settings.to_dict())

	var save_result: Error = config.save(CONFIG_PATH)
	if save_result != Error.OK:
		push_error("Failed to save logger settings: %d" % save_result)
		return Error.ERR_CANT_OPEN

	return Error.OK

## Load settings into a Settings object
static func load_to_settings() -> Settings:
	var settings := Settings.new()
	var config := ConfigFile.new()

	var load_result: Error = config.load(CONFIG_PATH)
	if load_result != Error.OK:
		print_rich("[color=yellow]Logger settings not found, using defaults[/color]")
		return settings

	# Load with validation
	if config.has_section_key("logger", "log_level"):
		var level: int = config.get_value("logger", "log_level") as int
		if level >= Logger.LogLevel.DEBUG and level <= Logger.LogLevel.CRITICAL:
			settings.log_level = level
		else:
			push_warning("Invalid log level in settings: %d (using default)" % level)

	if config.has_section_key("logger", "buffer_size"):
		var size: int = config.get_value("logger", "buffer_size") as int
		if size >= Logger.LoggerConfig.MIN_BUFFER_SIZE and size <= Logger.LoggerConfig.MAX_BUFFER_SIZE:
			settings.buffer_size = size
		else:
			push_warning("Invalid buffer size in settings: %d (using default)" % size)

	if config.has_section_key("logger", "retro_window"):
		var window: int = config.get_value("logger", "retro_window") as int
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

	if config.has_section_key("logger", "ignored_tags"):
		var tags = config.get_value("logger", "ignored_tags")
		if typeof(tags) == TYPE_PACKED_STRING_ARRAY:
			settings.ignored_tags = tags
		else:
			push_warning("Invalid ignored tags in settings (using default)")

	if config.has_section_key("logger", "run_tests"):
		var run_tests: bool = config.get_value("logger", "run_tests")
		if typeof(run_tests) == TYPE_BOOL:
			settings.run_tests = run_tests
		else:
			push_warning("Invalid run_tests in settings (using default)")

	# Load tag setups
	if config.has_section_key("tag_setups", "setups"):
		var setups_dict = config.get_value("tag_setups", "setups")
		if typeof(setups_dict) == TYPE_DICTIONARY:
			for key in setups_dict.keys():
				var setup_dict = setups_dict[key]
				if typeof(setup_dict) == TYPE_DICTIONARY:
					settings.tag_setups[key] = TagSetup.from_dict(setup_dict)

	# Load format settings
	if config.has_section_key("format", "settings"):
		var format_dict = config.get_value("format", "settings")
		if typeof(format_dict) == TYPE_DICTIONARY:
			settings.format_settings = FormatSettings.from_dict(format_dict)

	return settings

## Load Logger settings from config file and apply to logger instance
static func load_settings(logger_instance: Logger) -> Error:
	if not logger_instance:
		push_error("Cannot load settings: logger instance is null")
		return Error.FAILED

	var settings: Settings = load_to_settings()

	# Validate settings before applying
	var validation_result: Error = settings.validate()
	if validation_result != Error.OK:
		push_warning("Settings validation failed, using safe defaults")
		# Still continue with the validated defaults

	# Store original initialization state
	var was_initialized: bool = logger_instance._initialized
	logger_instance._initialized = false  # Temporarily disable messages

	# Apply settings to logger - using try/apply pattern for safety
	var result: Error = logger_instance.set_level(settings.log_level)
	if result != Error.OK:
		push_error("Failed to set log level: %d" % result)

	result = logger_instance.set_buffer_size(settings.buffer_size)
	if result != Error.OK:
		push_error("Failed to set buffer size: %d" % result)

	result = logger_instance.set_retroactive_window(settings.retro_window)
	if result != Error.OK:
		push_error("Failed to set retroactive window: %d" % result)

	# Apply active tags
	logger_instance.clear_tags()
	for tag in settings.active_tags:
		if not tag.is_empty():
			result = logger_instance.add_tag(tag)
			if result != Error.OK:
				push_warning("Failed to add tag: %s" % tag)

	# Apply ignored tags
	logger_instance.clear_ignored_tags()
	for tag in settings.ignored_tags:
		if not tag.is_empty():
			result = logger_instance.add_ignored_tag(tag)
			if result != Error.OK:
				push_warning("Failed to add ignored tag: %s" % tag)

	# Apply format settings
	if not logger_instance.has_method("_format_settings"):
		logger_instance.set("_format_settings", FormatSettings.new())
	logger_instance._format_settings = settings.format_settings

	# Apply format settings to formatter if it exists
	if logger_instance.has_method("_formatter") and logger_instance._formatter.has_method("apply_format_settings"):
		logger_instance._formatter.apply_format_settings(settings.format_settings)

	# Restore original initialization state
	logger_instance._initialized = was_initialized

	return Error.OK

## Get run_tests setting from config file
static func should_run_tests() -> bool:
	return load_to_settings().run_tests

## Apply settings from one logger to another with full error handling
static func apply_logger_to_logger(source: Logger, target: Logger) -> Error:
	if not source or not target:
		push_error("Cannot sync loggers: one or both instances are null")
		return Error.FAILED

	var result: Error = Error.OK

	# Store original initialization state
	var was_initialized: bool = target._initialized
	target._initialized = false  # Temporarily disable messages

	# Apply level
	var level_result: Error = target.set_level(source._current_level)
	if level_result != Error.OK:
		push_error("Failed to apply log level to target logger")
		result = level_result

	# Apply buffer size
	var buffer_result: Error = target.set_buffer_size(source._buffer.buffer.size())
	if buffer_result != Error.OK:
		push_error("Failed to apply buffer size to target logger")
		result = buffer_result

	# Apply retroactive window
	var window_result: Error = target.set_retroactive_window(source._config.retroactive_time_window)
	if window_result != Error.OK:
		push_error("Failed to apply retroactive window to target logger")
		result = window_result

	# Apply active tags
	target.clear_tags()
	for tag in source.get_active_tags():
		var tag_result: Error = target.add_tag(tag)
		if tag_result != Error.OK:
			push_warning("Failed to apply tag to target logger: %s" % tag)
			result = tag_result

	# Apply ignored tags
	target.clear_ignored_tags()
	for tag in source.get_ignored_tags():
		var tag_result: Error = target.add_ignored_tag(tag)
		if tag_result != Error.OK:
			push_warning("Failed to apply ignored tag to target logger: %s" % tag)
			result = tag_result

	# Apply format settings if available
	if source.has("_format_settings") and target.has("_format_settings"):
		target._format_settings = source._format_settings
		# Apply format settings to formatter if it exists
		if target.has("_formatter") and target._formatter.has_method("apply_format_settings"):
			target._formatter.apply_format_settings(source._format_settings)

	# Restore original initialization state
	target._initialized = was_initialized

	return result

## Get all saved tag setups
static func get_tag_setups() -> Dictionary:
	return load_to_settings().tag_setups

## Get format settings
static func get_format_settings() -> FormatSettings:
	return load_to_settings().format_settings

## Save format settings
static func save_format_settings(format_settings: FormatSettings) -> Error:
	var logger = Engine.get_singleton("Log")
	if not logger:
		push_error("Failed to get logger singleton")
		return Error.FAILED

	# Update logger's format settings
	if not logger.has("_format_settings"):
		logger.set("_format_settings", FormatSettings.new())
	logger._format_settings = format_settings

	# Apply to formatter if available
	if logger.has("_formatter") and logger._formatter.has_method("apply_format_settings"):
		logger._formatter.apply_format_settings(format_settings)

	# Save settings
	return save_settings(logger, should_run_tests())

## Save a tag setup
static func save_tag_setup(name: String, active_tags: Array[String],
						ignored_tags: Array[String], log_level: int) -> Error:
	var setups = get_tag_setups()

	# Create the setup
	var setup = TagSetup.new(
		name,
		PackedStringArray(active_tags),
		PackedStringArray(ignored_tags),
		log_level
	)

	# Add to dictionary
	setups[name] = setup

	# Get current logger and settings
	var logger = Engine.get_singleton("Log")
	if not logger:
		push_error("Failed to get logger singleton")
		return Error.FAILED

	# Save settings with updated tag setups
	return save_settings(logger, should_run_tests(), setups)

## Delete a tag setup
static func delete_tag_setup(name: String) -> Error:
	var setups = get_tag_setups()

	# Remove from dictionary if it exists
	if setups.has(name):
		setups.erase(name)

		# Get current logger and settings
		var logger = Engine.get_singleton("Log")
		if not logger:
			push_error("Failed to get logger singleton")
			return Error.FAILED

		# Save settings with updated tag setups
		return save_settings(logger, should_run_tests(), setups)

	return Error.OK
