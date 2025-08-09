@tool
class_name ConfigManager
extends RefCounted

signal config_changed(section: String, key: String, value: Variant)


const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"

const SECTION_LOGGER: String = "logger"  ## Section for logger settings (log level, tags)
const SECTION_FORMAT: String = "format"  ## Section for formatting settings (timestamp, colors)
const SECTION_SETUPS: String = "tag_setups"  ## Section for tag setups/presets

const KEY_LOG_LEVEL: String = "log_level"  ## Key for log level setting
const KEY_ACTIVE_TAGS: String = "active_tags"  ## Key for active (filter) tags
const KEY_IGNORED_TAGS: String = "ignored_tags"  ## Key for ignored tags
const KEY_AVAILABLE_TAGS: String = "available_tags"  ## Key for all available tags
const KEY_SHOW_TIMESTAMP: String = "show_timestamp"  ## Key for timestamp display setting
const KEY_SHOW_TAGS: String = "show_tags"  ## Key for tags display setting
const KEY_USE_COLORS: String = "use_colors"  ## Key for color usage setting
const KEY_SHOW_SOURCE: String = "show_source"  ## Key for source info display setting
const KEY_BUFFER_SIZE: String = "buffer_size"  ## Key for buffer size setting
const KEY_ENABLE_BUFFER_DUMP: String = "enable_buffer_dump"  ## Key for buffer dump toggle
const KEY_SHOW_EDITOR_DEBUG: String = "show_editor_debug"  ## Key for showing editor debug prints toggle

const DEFAULT_LOG_LEVEL: int = 1  ## Default log level (INFO)
const DEFAULT_SHOW_TIMESTAMP: bool = true  ## Default timestamp display (on)
const DEFAULT_SHOW_TAGS: bool = true  ## Default tags display (on)
const DEFAULT_USE_COLORS: bool = true  ## Default color usage (on)
const DEFAULT_SHOW_SOURCE: bool = true  ## Default source info display (on)
const DEFAULT_BUFFER_SIZE: int = 20    ## Default buffer size
const DEFAULT_ENABLE_BUFFER_DUMP: bool = true  ## Default buffer dump setting (enabled)
const DEFAULT_SHOW_EDITOR_DEBUG: bool = false  ## Default editor debug prints (disabled)


static var _instance: ConfigManager = null
var _config: ConfigFile = ConfigFile.new()
var _config_loaded: bool = false




static func get_instance() -> ConfigManager:
	if _instance == null:
		_instance = ConfigManager.new()
	return _instance

static func cleanup() -> void:
	if _instance != null:
		_instance.cleanup_instance()

		if is_instance_valid(_instance):
			if _instance._config:
				_instance._config = null

			var temp_instance = _instance
			_instance = null

			if temp_instance is Object and not temp_instance is RefCounted:
				temp_instance.free()
		else:
			_instance = null

func _init() -> void:
	_load_config()

func _load_config() -> Error:
	var config_path = _get_platform_config_path()
	var result = Error.FAILED

	print("[ConfigManager] Attempting to load config from: %s" % config_path)
	print("[ConfigManager] File exists: %s" % FileAccess.file_exists(config_path))

	result = _config.load(config_path)
	print("[ConfigManager] Standard load result: %s (%d)" % [error_string(result), result])

	if result != OK and _is_mobile_platform():
		print("[ConfigManager] Standard load failed on mobile, trying FileAccess method")
		if FileAccess.file_exists(config_path):
			print("[ConfigManager] Config file exists, reading with FileAccess")
			var file = FileAccess.open(config_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				print("[ConfigManager] File content length: %d chars" % content.length())
				result = _config.parse(content)
				print("[ConfigManager] Parse result: %s (%d)" % [error_string(result), result])
				file.close()
			else:
				print("[ConfigManager] Failed to open file with FileAccess")
		else:
			print("[ConfigManager] Config file doesn't exist, creating and copying from project config")
			_create_default_config()
			result = OK

	_config_loaded = result == OK or result == ERR_FILE_NOT_FOUND
	print("[ConfigManager] Config loaded successfully: %s" % _config_loaded)

	if result == OK:
		print("[ConfigManager] Config loaded OK, checking for upgrades")
		_upgrade_config_if_needed()
	else:
		print("[ConfigManager] Config load failed, final result: %s" % error_string(result))

	if _config_loaded:
		var loaded_log_level = get_log_level()
		print("[ConfigManager] Loaded log level: %d (%s)" % [loaded_log_level, ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"][loaded_log_level]])

	return result

func _create_default_config() -> void:
	if not _migrate_from_res_config():
		print("[ConfigManager] No res:// config found, using hardcoded defaults")

		_config.set_value(SECTION_LOGGER, KEY_LOG_LEVEL, DEFAULT_LOG_LEVEL)
		_config.set_value(SECTION_LOGGER, KEY_ACTIVE_TAGS, [])
		_config.set_value(SECTION_LOGGER, KEY_IGNORED_TAGS, [])
		_config.set_value(SECTION_LOGGER, KEY_AVAILABLE_TAGS, [])
		_config.set_value(SECTION_LOGGER, KEY_BUFFER_SIZE, DEFAULT_BUFFER_SIZE)
		_config.set_value(SECTION_LOGGER, KEY_ENABLE_BUFFER_DUMP, DEFAULT_ENABLE_BUFFER_DUMP)

		_config.set_value(SECTION_FORMAT, KEY_SHOW_TIMESTAMP, DEFAULT_SHOW_TIMESTAMP)
		_config.set_value(SECTION_FORMAT, KEY_SHOW_TAGS, DEFAULT_SHOW_TAGS)
		_config.set_value(SECTION_FORMAT, KEY_USE_COLORS, DEFAULT_USE_COLORS)
		_config.set_value(SECTION_FORMAT, KEY_SHOW_SOURCE, DEFAULT_SHOW_SOURCE)
		_config.set_value(SECTION_FORMAT, KEY_SHOW_EDITOR_DEBUG, DEFAULT_SHOW_EDITOR_DEBUG)

	_config.set_value("meta", "version", 1)

	if _is_mobile_platform():
		var save_result = save()
		if save_result == OK:
			print("[ConfigManager] Successfully saved migrated config to user:// storage")
		else:
			print("[ConfigManager] Failed to save migrated config: %s" % error_string(save_result))

func _migrate_from_res_config() -> bool:
	var res_config = ConfigFile.new()
	print("[ConfigManager] Attempting to migrate config from res:// path: %s" % CONFIG_PATH)
	print("[ConfigManager] res:// config file exists: %s" % FileAccess.file_exists(CONFIG_PATH))

	var result = res_config.load(CONFIG_PATH)

	if result != OK:
		print("[ConfigManager] Failed to load res:// config for migration: %s" % error_string(result))
		return false

	print("[ConfigManager] Successfully loaded res:// config, migrating settings to mobile platform")

	if res_config.has_section(SECTION_LOGGER):
		var log_level = res_config.get_value(SECTION_LOGGER, KEY_LOG_LEVEL, DEFAULT_LOG_LEVEL)
		_config.set_value(SECTION_LOGGER, KEY_LOG_LEVEL, log_level)
		print("[ConfigManager] Migrated log_level: %d" % log_level)

		var active_tags = res_config.get_value(SECTION_LOGGER, KEY_ACTIVE_TAGS, [])
		_config.set_value(SECTION_LOGGER, KEY_ACTIVE_TAGS, active_tags)

		var ignored_tags = res_config.get_value(SECTION_LOGGER, KEY_IGNORED_TAGS, [])
		_config.set_value(SECTION_LOGGER, KEY_IGNORED_TAGS, ignored_tags)

		var available_tags = res_config.get_value(SECTION_LOGGER, KEY_AVAILABLE_TAGS, [])
		_config.set_value(SECTION_LOGGER, KEY_AVAILABLE_TAGS, available_tags)

		var buffer_size = res_config.get_value(SECTION_LOGGER, KEY_BUFFER_SIZE, DEFAULT_BUFFER_SIZE)
		_config.set_value(SECTION_LOGGER, KEY_BUFFER_SIZE, buffer_size)

		var enable_buffer_dump = res_config.get_value(SECTION_LOGGER, KEY_ENABLE_BUFFER_DUMP, DEFAULT_ENABLE_BUFFER_DUMP)
		_config.set_value(SECTION_LOGGER, KEY_ENABLE_BUFFER_DUMP, enable_buffer_dump)

	if res_config.has_section(SECTION_FORMAT):
		var show_timestamp = res_config.get_value(SECTION_FORMAT, KEY_SHOW_TIMESTAMP, DEFAULT_SHOW_TIMESTAMP)
		_config.set_value(SECTION_FORMAT, KEY_SHOW_TIMESTAMP, show_timestamp)

		var show_tags = res_config.get_value(SECTION_FORMAT, KEY_SHOW_TAGS, DEFAULT_SHOW_TAGS)
		_config.set_value(SECTION_FORMAT, KEY_SHOW_TAGS, show_tags)

		var use_colors = res_config.get_value(SECTION_FORMAT, KEY_USE_COLORS, DEFAULT_USE_COLORS)
		_config.set_value(SECTION_FORMAT, KEY_USE_COLORS, use_colors)

		var show_source = res_config.get_value(SECTION_FORMAT, KEY_SHOW_SOURCE, DEFAULT_SHOW_SOURCE)
		_config.set_value(SECTION_FORMAT, KEY_SHOW_SOURCE, show_source)

		var show_editor_debug = res_config.get_value(SECTION_FORMAT, KEY_SHOW_EDITOR_DEBUG, DEFAULT_SHOW_EDITOR_DEBUG)
		_config.set_value(SECTION_FORMAT, KEY_SHOW_EDITOR_DEBUG, show_editor_debug)

	if res_config.has_section(SECTION_SETUPS):
		print("[ConfigManager] Migrating tag_setups section")
		var setup_keys = res_config.get_section_keys(SECTION_SETUPS)
		for key in setup_keys:
			var value = res_config.get_value(SECTION_SETUPS, key)
			_config.set_value(SECTION_SETUPS, key, value)

	if res_config.has_section("setups"):
		print("[ConfigManager] Migrating legacy setups section")
		var legacy_keys = res_config.get_section_keys("setups")
		for key in legacy_keys:
			var value = res_config.get_value("setups", key)
			_config.set_value(SECTION_SETUPS, key, value)

	print("[ConfigManager] Successfully migrated configuration from res:// to mobile platform")
	return true

func _upgrade_config_if_needed() -> void:
	if not _config.has_section_key("meta", "version"):

		if _config.has_section("setups") and not _config.has_section(SECTION_SETUPS):
			var keys = _config.get_section_keys("setups")
			for key in keys:
				var value = _config.get_value("setups", key)
				_config.set_value(SECTION_SETUPS, key, value)

		_config.set_value("meta", "version", 1)

		save()
		print_rich("[color=#%s]Config upgraded to version 1[/color]" % LoggerColors.INFO_HTML)

func get_value(section: String, key: String, default_value: Variant = null) -> Variant:
	if not _config_loaded:
		_load_config()

	return _config.get_value(section, key, default_value)

func set_value(section: String, key: String, value: Variant) -> void:
	if not _config_loaded:
		_load_config()

	if section == SECTION_LOGGER and key == KEY_LOG_LEVEL:
		if not (value is int and value >= 0 and value <= 4):
			push_warning("Invalid log level value: %s. Using default." % str(value))
			value = DEFAULT_LOG_LEVEL

	if section == SECTION_LOGGER and (key == KEY_ACTIVE_TAGS or key == KEY_IGNORED_TAGS or key == KEY_AVAILABLE_TAGS):
		if not value is Array:
			push_warning("Non-array value for %s.%s. Converting to empty array." % [section, key])
			value = []

	if section == SECTION_FORMAT and (key == KEY_SHOW_TIMESTAMP or key == KEY_SHOW_TAGS or
			key == KEY_USE_COLORS or key == KEY_SHOW_SOURCE):
		if not value is bool:
			push_warning("Non-boolean value for %s.%s. Converting to default." % [section, key])
			if key == KEY_SHOW_TIMESTAMP:
				value = DEFAULT_SHOW_TIMESTAMP
			elif key == KEY_SHOW_TAGS:
				value = DEFAULT_SHOW_TAGS
			elif key == KEY_USE_COLORS:
				value = DEFAULT_USE_COLORS
			elif key == KEY_SHOW_SOURCE:
				value = DEFAULT_SHOW_SOURCE

	_config.set_value(section, key, value)
	config_changed.emit(section, key, value)

func _get_platform_config_path() -> String:
	var platform = OS.get_name()
	print("[ConfigManager] Platform detected: %s" % platform)

	if platform == "Android":
		var android_helper: Script = load("res://addons/advanced_logger/utils/android_logger_helper.gd")
		if android_helper:
			var config_path = android_helper.get_config_path()
			print("[ConfigManager] Android helper loaded, config path: %s" % config_path)
			return config_path
		else:
			print("[ConfigManager] Android helper failed to load, using fallback path")
			return "user://advanced_logger_settings.cfg"

	elif platform == "iOS":
		var ios_helper: Script = load("res://addons/advanced_logger/utils/ios_logger_helper.gd")
		if ios_helper:
			var config_path = ios_helper.get_config_path()
			print("[ConfigManager] iOS helper loaded, config path: %s" % config_path)
			return config_path
		else:
			print("[ConfigManager] iOS helper failed to load, using fallback path")
			return "user://advanced_logger_settings.cfg"

	print("[ConfigManager] Desktop platform, using res:// config path: %s" % CONFIG_PATH)
	return CONFIG_PATH

func _is_mobile_platform() -> bool:
	var platform = OS.get_name()
	return platform == "Android" or platform == "iOS"

func save() -> Error:
	if _is_mobile_platform():
		var user_config_path = "user://advanced_logger_settings.cfg"
		return _config.save(user_config_path)

	var dir_path = CONFIG_PATH.get_base_dir()
	var dir = DirAccess.open("res://")
	if not dir:
		return FileAccess.get_open_error()

	if not dir.dir_exists(dir_path):
		var current_path = "res://"
		for path_part in dir_path.trim_prefix("res://").split("/"):
			if path_part.is_empty():
				continue

			current_path = current_path.path_join(path_part)
			if not dir.dir_exists(current_path):
				dir.make_dir(current_path)

	return _config.save(CONFIG_PATH)

func has_value(section: String, key: String) -> bool:
	if not _config_loaded:
		_load_config()

	return _config.has_section_key(section, key)

func clear_section(section: String) -> bool:
	if not _config_loaded:
		_load_config()

	if not _config.has_section(section):
		return false

	var keys = _config.get_section_keys(section)

	for key in keys:
		_config.set_value(section, key, null)

	return true


func get_log_level() -> int:
	return get_value(SECTION_LOGGER, KEY_LOG_LEVEL, DEFAULT_LOG_LEVEL)

func set_log_level(level: int) -> void:
	set_value(SECTION_LOGGER, KEY_LOG_LEVEL, level)

func get_active_tags() -> Array[String]:
	var tags = get_value(SECTION_LOGGER, KEY_ACTIVE_TAGS, [])
	if tags is Array:
		var result: Array[String] = []
		for tag in tags:
			if tag is String and not _is_reserved_category_name(tag):
				result.append(tag)
		return result
	return []

func set_active_tags(tags: Array[String]) -> void:
	var filtered_tags: Array[String] = []
	for tag in tags:
		if not _is_reserved_category_name(tag):
			filtered_tags.append(tag)

	set_value(SECTION_LOGGER, KEY_ACTIVE_TAGS, filtered_tags)

func get_ignored_tags() -> Array[String]:
	var tags = get_value(SECTION_LOGGER, KEY_IGNORED_TAGS, [])
	if tags is Array:
		var result: Array[String] = []
		for tag in tags:
			if tag is String and not _is_reserved_category_name(tag):
				result.append(tag)
		return result
	return []

func _is_reserved_category_name(tag: String) -> bool:
	if not tag is String:
		return false

	var lower_tag = tag.to_lower()
	return lower_tag == "available" or lower_tag == "active" or lower_tag == "ignored"

func set_ignored_tags(tags: Array[String]) -> void:
	var filtered_tags: Array[String] = []
	for tag in tags:
		if not _is_reserved_category_name(tag):
			filtered_tags.append(tag)

	set_value(SECTION_LOGGER, KEY_IGNORED_TAGS, filtered_tags)

func get_available_tags() -> Array[String]:
	var tags = get_value(SECTION_LOGGER, KEY_AVAILABLE_TAGS, [])
	if tags is Array:
		var result: Array[String] = []
		for tag in tags:
			if tag is String and not _is_reserved_category_name(tag):
				result.append(tag)
		return result
	return []

func set_available_tags(tags: Array[String]) -> void:
	var filtered_tags: Array[String] = []
	for tag in tags:
		if not _is_reserved_category_name(tag):
			filtered_tags.append(tag)

	set_value(SECTION_LOGGER, KEY_AVAILABLE_TAGS, filtered_tags)

func get_show_timestamp() -> bool:
	return get_value(SECTION_FORMAT, KEY_SHOW_TIMESTAMP, DEFAULT_SHOW_TIMESTAMP)

func set_show_timestamp(show: bool) -> void:
	set_value(SECTION_FORMAT, KEY_SHOW_TIMESTAMP, show)

func get_show_tags() -> bool:
	return get_value(SECTION_FORMAT, KEY_SHOW_TAGS, DEFAULT_SHOW_TAGS)

func set_show_tags(show: bool) -> void:
	set_value(SECTION_FORMAT, KEY_SHOW_TAGS, show)

func get_use_colors() -> bool:
	return get_value(SECTION_FORMAT, KEY_USE_COLORS, DEFAULT_USE_COLORS)

func set_use_colors(use: bool) -> void:
	set_value(SECTION_FORMAT, KEY_USE_COLORS, use)

func get_show_source() -> bool:
	return get_value(SECTION_FORMAT, KEY_SHOW_SOURCE, DEFAULT_SHOW_SOURCE)

func set_show_source(show: bool) -> void:
	set_value(SECTION_FORMAT, KEY_SHOW_SOURCE, show)

func get_buffer_size() -> int:
	return get_value(SECTION_LOGGER, KEY_BUFFER_SIZE, DEFAULT_BUFFER_SIZE)

func set_buffer_size(size: int) -> void:
	set_value(SECTION_LOGGER, KEY_BUFFER_SIZE, max(1, size))

func get_enable_buffer_dump() -> bool:
	return get_value(SECTION_LOGGER, KEY_ENABLE_BUFFER_DUMP, DEFAULT_ENABLE_BUFFER_DUMP)

func set_enable_buffer_dump(enable: bool) -> void:
	set_value(SECTION_LOGGER, KEY_ENABLE_BUFFER_DUMP, enable)

func get_show_editor_debug() -> bool:
	return get_value(SECTION_FORMAT, KEY_SHOW_EDITOR_DEBUG, DEFAULT_SHOW_EDITOR_DEBUG)

func set_show_editor_debug(show: bool) -> void:
	set_value(SECTION_FORMAT, KEY_SHOW_EDITOR_DEBUG, show)

func get_tag_setup(setup_name: String) -> Dictionary:
	return get_value(SECTION_SETUPS, setup_name, {})

func set_tag_setup(setup_name: String, setup_data: Dictionary) -> void:
	set_value(SECTION_SETUPS, setup_name, setup_data)

func get_all_tag_setups() -> Dictionary:
	if not _config_loaded:
		_load_config()

	var result = {}
	if _config.has_section(SECTION_SETUPS):
		var setup_keys = _config.get_section_keys(SECTION_SETUPS)
		for setup_name in setup_keys:
			result[setup_name] = get_tag_setup(setup_name)

	return result

func reset_to_defaults() -> Error:
	clear_section(SECTION_LOGGER)
	clear_section(SECTION_FORMAT)

	set_log_level(DEFAULT_LOG_LEVEL)
	set_active_tags([])
	set_ignored_tags([])
	set_available_tags([])
	set_buffer_size(DEFAULT_BUFFER_SIZE)
	set_enable_buffer_dump(DEFAULT_ENABLE_BUFFER_DUMP)

	set_show_timestamp(DEFAULT_SHOW_TIMESTAMP)
	set_show_tags(DEFAULT_SHOW_TAGS)
	set_use_colors(DEFAULT_USE_COLORS)
	set_show_source(DEFAULT_SHOW_SOURCE)
	set_show_editor_debug(DEFAULT_SHOW_EDITOR_DEBUG)

	return save()

func cleanup_instance() -> void:
	if is_instance_valid(self):
		var connections = get_signal_connection_list("config_changed")
		for connection in connections:
			disconnect("config_changed", connection["callable"])

	if _config != null:
		_config.clear()
		_config = null

	_config_loaded = false
