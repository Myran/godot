@tool
class_name LoggerDock extends Control
## Editor dock for configuring the Advanced Logger settings

# Config constants
const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"
const CONFIG_SECTION_LOGGER: String = "logger"
const CONFIG_SECTION_FORMAT: String = "format"
const CONFIG_KEY_LOG_LEVEL: String = "log_level"
const CONFIG_KEY_ACTIVE_TAGS: String = "active_tags"
const CONFIG_KEY_IGNORED_TAGS: String = "ignored_tags"
const CONFIG_KEY_SHOW_TIMESTAMP: String = "show_timestamp"
const CONFIG_KEY_SHOW_TAGS: String = "show_tags"
const CONFIG_KEY_USE_COLORS: String = "use_colors"
const CONFIG_KEY_SHOW_SOURCE: String = "show_source"
const DEFAULT_SHOW_SOURCE: bool = true
# Default values
const DEFAULT_LOG_LEVEL: int = 1  # INFO level
const DEFAULT_SHOW_TIMESTAMP: bool = true
const DEFAULT_SHOW_TAGS: bool = true
const DEFAULT_USE_COLORS: bool = true

# Settings cache
var _current_level: int = DEFAULT_LOG_LEVEL
var _active_tags: Array[String] = []
var _ignored_tags: Array[String] = []
var _show_timestamp: bool = DEFAULT_SHOW_TIMESTAMP
var _show_tags: bool = DEFAULT_SHOW_TAGS
var _use_colors: bool = DEFAULT_USE_COLORS
var _show_source: bool = DEFAULT_SHOW_SOURCE
# UI Components
@onready var _show_source_check: CheckBox = $VBoxContainer/FormatSection/ShowSourceCheck
@onready var _level_option: OptionButton = $VBoxContainer/LevelSection/LevelOption
@onready var _tags_input: LineEdit = $VBoxContainer/TagsSection/TagsInputHBox/TagsInput
@onready var _tags_list: ItemList = $VBoxContainer/TagsSection/TagsList
@onready var _add_tag_button: Button = $VBoxContainer/TagsSection/TagsInputHBox/AddTagButton
@onready var _remove_tag_button: Button = $VBoxContainer/TagsSection/RemoveTagButton
@onready var _ignored_tags_input: LineEdit = $VBoxContainer/IgnoredTagsSection/IgnoredTagsInputHBox/IgnoredTagsInput
@onready var _ignored_tags_list: ItemList = $VBoxContainer/IgnoredTagsSection/IgnoredTagsList
@onready var _add_ignored_tag_button: Button = $VBoxContainer/IgnoredTagsSection/IgnoredTagsInputHBox/AddIgnoredTagButton
@onready var _remove_ignored_tag_button: Button = $VBoxContainer/IgnoredTagsSection/RemoveIgnoredTagButton
@onready var _show_timestamp_check: CheckBox = $VBoxContainer/FormatSection/ShowTimestampCheck
@onready var _show_tags_check: CheckBox = $VBoxContainer/FormatSection/ShowTagsCheck
@onready var _use_colors_check: CheckBox = $VBoxContainer/FormatSection/UseColorsCheck
@onready var _save_button: Button = $VBoxContainer/ButtonsSection/SaveButton
@onready var _reset_button: Button = $VBoxContainer/ButtonsSection/ResetButton


func _ready() -> void:
	# Populate the log level dropdown - use enum directly for type safety
	#for i in range(Logger.LogLevel.size()):
		#_level_option.add_item(Logger.LogLevel.keys()[i], i)

	# Connect UI signals
	_level_option.item_selected.connect(_on_level_changed)
	_add_tag_button.pressed.connect(_on_add_tag)
	_remove_tag_button.pressed.connect(_on_remove_tag)
	_tags_input.text_submitted.connect(_on_add_tag)
	_add_ignored_tag_button.pressed.connect(_on_add_ignored_tag)
	_remove_ignored_tag_button.pressed.connect(_on_remove_ignored_tag)
	_ignored_tags_input.text_submitted.connect(_on_add_ignored_tag)
	_show_timestamp_check.toggled.connect(_on_show_timestamp_toggled)
	_show_tags_check.toggled.connect(_on_show_tags_toggled)
	_use_colors_check.toggled.connect(_on_use_colors_toggled)
	_save_button.pressed.connect(_on_save_settings)
	_reset_button.pressed.connect(_on_reset_settings)
	_show_source_check.toggled.connect(_on_show_source_toggled)

	# Load settings from config
	_load_settings_from_config()


func _load_settings_from_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_result: Error = config.load(CONFIG_PATH)

	if load_result != OK:
		# If file doesn't exist or other error, use defaults
		_apply_defaults()
		return

	# Validate required sections exist
	if (
		not config.has_section(CONFIG_SECTION_LOGGER)
		or not config.has_section(CONFIG_SECTION_FORMAT)
	):
		push_warning("Config file missing required sections")
		_apply_defaults()
		return

	if config.has_section_key(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_SOURCE):
		_show_source = config.get_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_SOURCE) as bool
		_show_source_check.button_pressed = _show_source

	# Load log level
	if config.has_section_key(CONFIG_SECTION_LOGGER, CONFIG_KEY_LOG_LEVEL):
		var level_value: int = config.get_value(CONFIG_SECTION_LOGGER, CONFIG_KEY_LOG_LEVEL)
		_current_level = level_value
		_level_option.select(_current_level)

	# Load active tags
	_active_tags.clear()
	if config.has_section_key(CONFIG_SECTION_LOGGER, CONFIG_KEY_ACTIVE_TAGS):
		var tags: PackedStringArray = config.get_value(
			CONFIG_SECTION_LOGGER, CONFIG_KEY_ACTIVE_TAGS
		)
		for tag in tags:
			if LoggerSettings._is_valid_tag(tag):
				_active_tags.append(tag)

	# Load ignored tags
	_ignored_tags.clear()
	if config.has_section_key(CONFIG_SECTION_LOGGER, CONFIG_KEY_IGNORED_TAGS):
		var tags: PackedStringArray = config.get_value(
			CONFIG_SECTION_LOGGER, CONFIG_KEY_IGNORED_TAGS
		)
		for tag in tags:
			if LoggerSettings._is_valid_tag(tag):
				_ignored_tags.append(tag)

	# Load format settings
	if config.has_section_key(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_TIMESTAMP):
		_show_timestamp = config.get_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_TIMESTAMP) as bool
		_show_timestamp_check.button_pressed = _show_timestamp

	if config.has_section_key(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_TAGS):
		_show_tags = config.get_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_TAGS) as bool
		_show_tags_check.button_pressed = _show_tags

	if config.has_section_key(CONFIG_SECTION_FORMAT, CONFIG_KEY_USE_COLORS):
		_use_colors = config.get_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_USE_COLORS) as bool
		_use_colors_check.button_pressed = _use_colors

	# Refresh UI
	_refresh_tags_lists()


func _save_settings_to_config() -> Error:
	var config: ConfigFile = ConfigFile.new()

	# Logger general settings
	config.set_value(CONFIG_SECTION_LOGGER, CONFIG_KEY_LOG_LEVEL, _current_level)

	# Tag settings
	config.set_value(CONFIG_SECTION_LOGGER, CONFIG_KEY_ACTIVE_TAGS, PackedStringArray(_active_tags))
	config.set_value(
		CONFIG_SECTION_LOGGER, CONFIG_KEY_IGNORED_TAGS, PackedStringArray(_ignored_tags)
	)

	# Format settings
	config.set_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_TIMESTAMP, _show_timestamp)
	config.set_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_TAGS, _show_tags)
	config.set_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_USE_COLORS, _use_colors)
	config.set_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_SOURCE, _show_source)

	# Make sure the directory exists
	var dir := DirAccess.open("res://")
	if dir:
		# Create addons directory if it doesn't exist
		if not dir.dir_exists("addons"):
			var err := dir.make_dir("addons")
			if err != OK:
				push_error("Failed to create addons directory: %s" % error_string(err))
				return err

		# Move to addons directory
		if dir.change_dir("addons") != OK:
			push_error("Failed to access addons directory")
			return Error.FAILED

		# Create the advanced_logger directory if it doesn't exist
		if not dir.dir_exists("advanced_logger"):
			var err := dir.make_dir("advanced_logger")
			if err != OK:
				push_error("Failed to create advanced_logger directory: %s" % error_string(err))
				return err
	else:
		push_error("Failed to access project directory")
		return Error.FAILED

	# Try to save with better error handling
	var save_result: Error = config.save(CONFIG_PATH)
	if save_result == OK:
		print_rich(
			"[color=#%s]Logger settings saved successfully[/color]" % LoggerColors.SUCCESS_HTML
		)
	else:
		push_error("Failed to save logger settings: %s" % error_string(save_result))

	return save_result


func _refresh_tags_lists() -> void:
	# Clear and populate active tags list
	_tags_list.clear()
	for tag in _active_tags:
		_tags_list.add_item(tag)

	# Clear and populate ignored tags list
	_ignored_tags_list.clear()
	for tag in _ignored_tags:
		_ignored_tags_list.add_item(tag)


func _apply_defaults() -> void:
	# Set defaults
	_current_level = DEFAULT_LOG_LEVEL
	_active_tags.clear()
	_ignored_tags.clear()
	_show_timestamp = DEFAULT_SHOW_TIMESTAMP
	_show_tags = DEFAULT_SHOW_TAGS
	_use_colors = DEFAULT_USE_COLORS
	_show_source = DEFAULT_SHOW_SOURCE
	_show_source_check.button_pressed = _show_source
	# Update UI
	_level_option.select(_current_level)
	_show_timestamp_check.button_pressed = _show_timestamp
	_show_tags_check.button_pressed = _show_tags
	_use_colors_check.button_pressed = _use_colors
	_refresh_tags_lists()

	# Save to config
	_save_settings_to_config()


# UI Event handlers
func _on_show_source_toggled(button_pressed: bool) -> void:
	_show_source = button_pressed
	_save_settings_to_config()


func _on_level_changed(index: int) -> void:
	_current_level = index
	_save_settings_to_config()


func _on_add_tag() -> void:
	var tag := _tags_input.text.strip_edges()
	if tag.is_empty():
		return

	# Add to active tags if not already present
	if not _active_tags.has(tag):
		_active_tags.append(tag)

		# Remove from ignored tags if present
		if _ignored_tags.has(tag):
			_ignored_tags.erase(tag)

	_tags_input.clear()
	_refresh_tags_lists()
	_save_settings_to_config()


func _on_add_tag_from_input(_text: String) -> void:
	_on_add_tag()


func _on_remove_tag() -> void:
	var selected := _tags_list.get_selected_items()
	if selected.is_empty():
		return

	var index := selected[0]
	if index >= 0 and index < _tags_list.item_count:
		var tag := _tags_list.get_item_text(index)
		if _active_tags.has(tag):
			_active_tags.erase(tag)
			_refresh_tags_lists()
			_save_settings_to_config()


func _on_add_ignored_tag() -> void:
	var tag := _ignored_tags_input.text.strip_edges()
	if tag.is_empty():
		return

	if not _ignored_tags.has(tag):
		_ignored_tags.append(tag)

		# Remove from active tags if present
		if _active_tags.has(tag):
			_active_tags.erase(tag)

	_ignored_tags_input.clear()
	_refresh_tags_lists()
	_save_settings_to_config()


func _on_add_ignored_tag_from_input(_text: String) -> void:
	_on_add_ignored_tag()


func _on_remove_ignored_tag() -> void:
	var selected := _ignored_tags_list.get_selected_items()
	if selected.is_empty():
		return

	var index := selected[0]
	if index >= 0 and index < _ignored_tags_list.item_count:
		var tag := _ignored_tags_list.get_item_text(index)
		if _ignored_tags.has(tag):
			_ignored_tags.erase(tag)
			_refresh_tags_lists()
			_save_settings_to_config()


func _on_show_timestamp_toggled(button_pressed: bool) -> void:
	_show_timestamp = button_pressed
	_save_settings_to_config()


func _on_show_tags_toggled(button_pressed: bool) -> void:
	_show_tags = button_pressed
	_save_settings_to_config()


func _on_use_colors_toggled(button_pressed: bool) -> void:
	_use_colors = button_pressed
	_save_settings_to_config()


func _on_save_settings() -> void:
	print_rich("[color=#%s]Attempting to save settings...[/color]" % LoggerColors.INFO_HTML)
	var result := _save_settings_to_config()
	print_rich(
		(
			"[color=#%s]Save result: %s[/color]"
			% [LoggerColors.INFO_HTML, "OK" if result == OK else error_string(result)]
		)
	)

	# Verify the file exists after saving
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file:
		print_rich(
			(
				"[color=#%s]Config file exists and can be opened for reading[/color]"
				% LoggerColors.SUCCESS_HTML
			)
		)
		file.close()
	else:
		print_rich(
			(
				"[color=#%s]Config file could not be opened: %s[/color]"
				% [LoggerColors.ERROR_HTML, error_string(FileAccess.get_open_error())]
			)
		)


func _on_reset_settings() -> void:
	_apply_defaults()
	print_rich("[color=#%s]Logger settings reset to defaults[/color]" % LoggerColors.INFO_HTML)
