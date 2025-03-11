@tool
class_name LoggerDock extends Control
## Editor dock for configuring the Advanced Logger settings
##
## Provides configuration UI for the Advanced Logger system with tag filtering,
## drag and drop tag management, and other logger settings.

# Config constants
const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"
const CONFIG_SECTION_LOGGER: String = "logger"
const CONFIG_SECTION_FORMAT: String = "format"
const CONFIG_KEY_LOG_LEVEL: String = "log_level"
const CONFIG_KEY_ACTIVE_TAGS: String = "active_tags"
const CONFIG_KEY_IGNORED_TAGS: String = "ignored_tags"
const CONFIG_KEY_AVAILABLE_TAGS: String = "available_tags"  # New config key for available tags
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

# Tag source constants to replace magic strings
const SOURCE_AVAILABLE: String = "available"
const SOURCE_ACTIVE: String = "active"
const SOURCE_IGNORED: String = "ignored"

# Settings cache
var _current_level: int = DEFAULT_LOG_LEVEL
var _active_tags: Array[String] = []
var _ignored_tags: Array[String] = []
var _available_tags: Array[String] = []  # New array for available tags
var _show_timestamp: bool = DEFAULT_SHOW_TIMESTAMP
var _show_tags: bool = DEFAULT_SHOW_TAGS
var _use_colors: bool = DEFAULT_USE_COLORS
var _show_source: bool = DEFAULT_SHOW_SOURCE

# Drag and drop tracking
var _drag_source: String = ""
var _drag_index: int = -1

# Flag to avoid multiple saves during batch operations
var _batch_operation: bool = false

# UI Components
@onready var _show_source_check: CheckBox = $VBoxContainer/FormatSection/ShowSourceCheck
@onready var _level_option: OptionButton = $VBoxContainer/LevelSection/LevelOption
@onready var _startup_message: Label = $VBoxContainer/StartupMessage  # New startup message label

# Available Tags components
@onready
var _available_tags_input: LineEdit = $VBoxContainer/AvailableTagsSection/TagsInputHBox/TagsInput
@onready var _available_tags_list: ItemList = $VBoxContainer/AvailableTagsSection/TagsList
@onready
var _add_available_tag_button: Button = $VBoxContainer/AvailableTagsSection/TagsInputHBox/AddTagButton
@onready
var _remove_available_tag_button: Button = $VBoxContainer/AvailableTagsSection/RemoveTagButton

# Active Tags components
@onready var _tags_input: LineEdit = $VBoxContainer/TagsSection/TagsInputHBox/TagsInput
@onready var _tags_list: ItemList = $VBoxContainer/TagsSection/TagsList
@onready var _add_tag_button: Button = $VBoxContainer/TagsSection/TagsInputHBox/AddTagButton
@onready var _remove_tag_button: Button = $VBoxContainer/TagsSection/RemoveTagButton

# Ignored Tags components
@onready
var _ignored_tags_input: LineEdit = $VBoxContainer/IgnoredTagsSection/IgnoredTagsInputHBox/IgnoredTagsInput
@onready var _ignored_tags_list: ItemList = $VBoxContainer/IgnoredTagsSection/IgnoredTagsList
@onready
var _add_ignored_tag_button: Button = $VBoxContainer/IgnoredTagsSection/IgnoredTagsInputHBox/AddIgnoredTagButton
@onready
var _remove_ignored_tag_button: Button = $VBoxContainer/IgnoredTagsSection/RemoveIgnoredTagButton

@onready var _show_timestamp_check: CheckBox = $VBoxContainer/FormatSection/ShowTimestampCheck
@onready var _show_tags_check: CheckBox = $VBoxContainer/FormatSection/ShowTagsCheck
@onready var _use_colors_check: CheckBox = $VBoxContainer/FormatSection/UseColorsCheck
@onready var _save_button: Button = $VBoxContainer/ButtonsSection/SaveButton
@onready var _reset_button: Button = $VBoxContainer/ButtonsSection/ResetButton


func _ready() -> void:
	# Connect UI signals
	_level_option.item_selected.connect(_on_level_changed)

	# Available Tags
	_add_available_tag_button.pressed.connect(_on_add_available_tag)
	_remove_available_tag_button.pressed.connect(_on_remove_available_tag)
	_available_tags_input.text_submitted.connect(_on_add_available_tag)

	# Set up drag and drop for available tags
	_available_tags_list.item_selected.connect(_on_available_tag_selected)
	_available_tags_list.item_activated.connect(_on_available_tag_activated)
	_available_tags_list.get_drag_data = _get_available_tag_drag_data
	_available_tags_list.can_drop_data = _can_drop_on_available_tags
	_available_tags_list.drop_data = _drop_on_available_tags

	# Active Tags
	_add_tag_button.pressed.connect(_on_add_tag)
	_remove_tag_button.pressed.connect(_on_remove_tag)
	_tags_input.text_submitted.connect(_on_add_tag)

	# Set up drag and drop for active tags
	_tags_list.item_selected.connect(_on_active_tag_selected)
	_tags_list.item_activated.connect(_on_active_tag_activated)
	_tags_list.get_drag_data = _get_active_tag_drag_data
	_tags_list.can_drop_data = _can_drop_on_active_tags
	_tags_list.drop_data = _drop_on_active_tags

	# Ignored Tags
	_add_ignored_tag_button.pressed.connect(_on_add_ignored_tag)
	_remove_ignored_tag_button.pressed.connect(_on_remove_ignored_tag)
	_ignored_tags_input.text_submitted.connect(_on_add_ignored_tag)

	# Set up drag and drop for ignored tags
	_ignored_tags_list.item_selected.connect(_on_ignored_tag_selected)
	_ignored_tags_list.item_activated.connect(_on_ignored_tag_activated)
	_ignored_tags_list.get_drag_data = _get_ignored_tag_drag_data
	_ignored_tags_list.can_drop_data = _can_drop_on_ignored_tags
	_ignored_tags_list.drop_data = _drop_on_ignored_tags

	# Format settings
	_show_timestamp_check.toggled.connect(_on_show_timestamp_toggled)
	_show_tags_check.toggled.connect(_on_show_tags_toggled)
	_use_colors_check.toggled.connect(_on_use_colors_toggled)
	_save_button.pressed.connect(_on_save_settings)
	_reset_button.pressed.connect(_on_reset_settings)
	_show_source_check.toggled.connect(_on_show_source_toggled)

	# Load settings from config
	_load_settings_from_config()

	# Display startup message
	_update_startup_message()


## Updates the startup message with current tag status
func _update_startup_message() -> void:
	# Create message about current active and ignored tags
	var message: String = ""

	if _active_tags.size() > 0:
		message += "Active filter tags: " + ", ".join(_active_tags)
	else:
		message += "No active filter tags (showing all logs except ignored)"

	if _ignored_tags.size() > 0:
		message += "\nIgnored tags: " + ", ".join(_ignored_tags)
	else:
		message += "\nNo ignored tags"

	_startup_message.text = message

	# Also print to console for convenience
	print_rich("[color=#%s]Advanced Logger Tags:[/color]" % LoggerColors.INFO_HTML)
	print_rich("[color=#%s]%s[/color]" % [LoggerColors.INFO_HTML, message])


## Loads logger settings from the config file
## Returns OK if successful, otherwise returns an error code
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

	# Load available tags
	_available_tags.clear()
	if config.has_section_key(CONFIG_SECTION_LOGGER, CONFIG_KEY_AVAILABLE_TAGS):
		var tags: PackedStringArray = config.get_value(
			CONFIG_SECTION_LOGGER, CONFIG_KEY_AVAILABLE_TAGS
		)
		for tag in tags:
			if _validate_tag_name(tag):
				_available_tags.append(tag)

	# Load active tags
	_active_tags.clear()
	if config.has_section_key(CONFIG_SECTION_LOGGER, CONFIG_KEY_ACTIVE_TAGS):
		var tags: PackedStringArray = config.get_value(
			CONFIG_SECTION_LOGGER, CONFIG_KEY_ACTIVE_TAGS
		)
		for tag in tags:
			if _validate_tag_name(tag):
				_active_tags.append(tag)

				# Also add to available tags if not already there
				if not _available_tags.has(tag):
					_available_tags.append(tag)

	# Load ignored tags
	_ignored_tags.clear()
	if config.has_section_key(CONFIG_SECTION_LOGGER, CONFIG_KEY_IGNORED_TAGS):
		var tags: PackedStringArray = config.get_value(
			CONFIG_SECTION_LOGGER, CONFIG_KEY_IGNORED_TAGS
		)
		for tag in tags:
			if _validate_tag_name(tag):
				_ignored_tags.append(tag)

				# Also add to available tags if not already there
				if not _available_tags.has(tag):
					_available_tags.append(tag)

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


## Saves logger settings to the config file
## Returns OK if successful, otherwise returns an error code
func _save_settings_to_config() -> Error:
	# Skip saving during batch operations
	if _batch_operation:
		return OK

	var config: ConfigFile = ConfigFile.new()

	# Try to load existing config first to preserve other settings
	var load_result := config.load(CONFIG_PATH)
	if load_result != OK and load_result != ERR_FILE_NOT_FOUND:
		push_error("Failed to load existing config: %s" % error_string(load_result))
		# Continue anyway to try creating a new file

	# Logger general settings
	config.set_value(CONFIG_SECTION_LOGGER, CONFIG_KEY_LOG_LEVEL, _current_level)

	# Tag settings
	config.set_value(CONFIG_SECTION_LOGGER, CONFIG_KEY_ACTIVE_TAGS, PackedStringArray(_active_tags))
	config.set_value(
		CONFIG_SECTION_LOGGER, CONFIG_KEY_IGNORED_TAGS, PackedStringArray(_ignored_tags)
	)
	config.set_value(
		CONFIG_SECTION_LOGGER, CONFIG_KEY_AVAILABLE_TAGS, PackedStringArray(_available_tags)
	)

	# Format settings
	config.set_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_TIMESTAMP, _show_timestamp)
	config.set_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_TAGS, _show_tags)
	config.set_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_USE_COLORS, _use_colors)
	config.set_value(CONFIG_SECTION_FORMAT, CONFIG_KEY_SHOW_SOURCE, _show_source)

	# More robust directory handling
	var dir_path := "res://addons/advanced_logger"
	var dir := DirAccess.open("res://")
	if not dir:
		var err := FileAccess.get_open_error()
		push_error("Failed to access project directory: %s" % error_string(err))
		return err

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

	# Try to save with better error handling
	var save_result: Error = config.save(CONFIG_PATH)
	if save_result == OK:
		print_rich(
			"[color=#%s]Logger settings saved successfully[/color]" % LoggerColors.SUCCESS_HTML
		)
	else:
		push_error("Failed to save logger settings: %s" % error_string(save_result))

	# Update startup message
	_update_startup_message()

	return save_result


## Refreshes all tag list UIs from the current state
func _refresh_tags_lists() -> void:
	# Clear and populate available tags list
	_available_tags_list.clear()
	for tag in _available_tags:
		if not _active_tags.has(tag) and not _ignored_tags.has(tag):
			_available_tags_list.add_item(tag)

	# Clear and populate active tags list
	_tags_list.clear()
	for tag in _active_tags:
		_tags_list.add_item(tag)

	# Clear and populate ignored tags list
	_ignored_tags_list.clear()
	for tag in _ignored_tags:
		_ignored_tags_list.add_item(tag)


## Applies default settings and resets UI
func _apply_defaults() -> void:
	# Set defaults
	_current_level = DEFAULT_LOG_LEVEL
	_available_tags.clear()
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


## Validates a tag name is properly formatted
## Returns true if the tag is valid, false otherwise
func _validate_tag_name(tag: String) -> bool:
	if tag.is_empty():
		return false

	# First check using existing LoggerSettings static method
	if not LoggerSettings._is_valid_tag(tag):
		return false

	# Enhanced validation for better tag names
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_-]+$")
	return regex.search(tag) != null


## Helper function to move a tag between lists
## Parameters:
## - tag: The tag to move
## - from_list: Source list array
## - to_list: Target list array
func _move_tag(tag: String, from_list: Array[String], to_list: Array[String]) -> void:
	if from_list.has(tag):
		from_list.erase(tag)
	if not to_list.has(tag):
		to_list.append(tag)
	_refresh_tags_lists()
	_save_settings_to_config()


## Handle tag movement between categories
##
## Parameters:
## - tag: The tag being moved
## - from_source: Source category ("available", "active", or "ignored")
## - to_target: Target category for the tag
func _handle_tag_drag(tag: String, from_source: String, to_target: String) -> void:
	if not _validate_tag_name(tag):
		push_warning("Invalid tag format: '%s'" % tag)
		return

	_begin_batch_operation()

	# Remove from source category
	if from_source == SOURCE_AVAILABLE:
		# Don't actually remove from available tags, as it's a master list
		pass
	elif from_source == SOURCE_ACTIVE:
		_active_tags.erase(tag)
	elif from_source == SOURCE_IGNORED:
		_ignored_tags.erase(tag)

	# Add to target category
	if to_target == SOURCE_AVAILABLE:
		# Just make sure it's in the available tags
		if not _available_tags.has(tag):
			_available_tags.append(tag)
	elif to_target == SOURCE_ACTIVE:
		# Add to active, ensure it's not in ignored
		if _ignored_tags.has(tag):
			_ignored_tags.erase(tag)
		if not _active_tags.has(tag):
			_active_tags.append(tag)
	elif to_target == SOURCE_IGNORED:
		# Add to ignored, ensure it's not in active
		if _active_tags.has(tag):
			_active_tags.erase(tag)
		if not _ignored_tags.has(tag):
			_ignored_tags.append(tag)

	_end_batch_operation()

	print_rich(
		(
			"[color=#%s]Moved tag '%s' from %s to %s[/color]"
			% [LoggerColors.SUCCESS_HTML, tag, from_source, to_target]
		)
	)


## Begin a batch operation to prevent multiple saves
func _begin_batch_operation() -> void:
	_batch_operation = true


## End a batch operation and save changes
func _end_batch_operation() -> void:
	_batch_operation = false
	_refresh_tags_lists()
	_save_settings_to_config()


# Drag & Drop handlers for Available Tags
func _get_available_tag_drag_data(_position: Vector2) -> Variant:
	var index := _available_tags_list.get_selected_items()
	if index.size() == 0:
		return null

	var tag_index = index[0]
	var tag_text = _available_tags_list.get_item_text(tag_index)

	if not _validate_tag_name(tag_text):
		push_warning("Invalid tag: '%s'" % tag_text)
		return null

	# Store source info for the drop
	_drag_source = SOURCE_AVAILABLE
	_drag_index = tag_index

	# Create drag preview
	var preview = Label.new()
	preview.text = tag_text
	preview.modulate = Color(1, 1, 1, 0.7)

	var control = Control.new()
	control.add_child(preview)
	preview.position = -0.5 * preview.size

	set_drag_preview(control)

	# Visual feedback
	_available_tags_list.add_theme_color_override("font_selected_color", Color.CORNFLOWER_BLUE)

	# Return the tag text
	return tag_text


func _can_drop_on_available_tags(_position: Vector2, data: Variant) -> bool:
	# Accept drops from active or ignored tags list
	if not data is String:
		return false
	return _drag_source == SOURCE_ACTIVE or _drag_source == SOURCE_IGNORED


func _drop_on_available_tags(_position: Vector2, data: Variant) -> void:
	var tag = data as String
	_handle_tag_drag(tag, _drag_source, SOURCE_AVAILABLE)


# Drag & Drop handlers for Active Tags
func _get_active_tag_drag_data(_position: Vector2) -> Variant:
	var index := _tags_list.get_selected_items()
	if index.size() == 0:
		return null

	var tag_index = index[0]
	var tag_text = _tags_list.get_item_text(tag_index)

	if not _validate_tag_name(tag_text):
		push_warning("Invalid tag: '%s'" % tag_text)
		return null

	# Store source info for the drop
	_drag_source = SOURCE_ACTIVE
	_drag_index = tag_index

	# Create drag preview
	var preview = Label.new()
	preview.text = tag_text
	preview.modulate = Color(1, 1, 1, 0.7)

	var control = Control.new()
	control.add_child(preview)
	preview.position = -0.5 * preview.size

	set_drag_preview(control)

	# Visual feedback
	_tags_list.add_theme_color_override("font_selected_color", Color.CORNFLOWER_BLUE)

	# Return the tag text
	return tag_text


func _can_drop_on_active_tags(_position: Vector2, data: Variant) -> bool:
	# Accept drops from available or ignored tags list
	if not data is String:
		return false
	return _drag_source == SOURCE_AVAILABLE or _drag_source == SOURCE_IGNORED


func _drop_on_active_tags(_position: Vector2, data: Variant) -> void:
	var tag = data as String
	_handle_tag_drag(tag, _drag_source, SOURCE_ACTIVE)


# Drag & Drop handlers for Ignored Tags
func _get_ignored_tag_drag_data(_position: Vector2) -> Variant:
	var index := _ignored_tags_list.get_selected_items()
	if index.size() == 0:
		return null

	var tag_index = index[0]
	var tag_text = _ignored_tags_list.get_item_text(tag_index)

	if not _validate_tag_name(tag_text):
		push_warning("Invalid tag: '%s'" % tag_text)
		return null

	# Store source info for the drop
	_drag_source = SOURCE_IGNORED
	_drag_index = tag_index

	# Create drag preview
	var preview = Label.new()
	preview.text = tag_text
	preview.modulate = Color(1, 1, 1, 0.7)

	var control = Control.new()
	control.add_child(preview)
	preview.position = -0.5 * preview.size

	set_drag_preview(control)

	# Visual feedback
	_ignored_tags_list.add_theme_color_override("font_selected_color", Color.CORNFLOWER_BLUE)

	# Return the tag text
	return tag_text


func _can_drop_on_ignored_tags(_position: Vector2, data: Variant) -> bool:
	# Accept drops from available or active tags list
	if not data is String:
		return false
	return _drag_source == SOURCE_AVAILABLE or _drag_source == SOURCE_ACTIVE


func _drop_on_ignored_tags(_position: Vector2, data: Variant) -> void:
	var tag = data as String
	_handle_tag_drag(tag, _drag_source, SOURCE_IGNORED)


# UI Event handlers


# Available Tags handlers
func _on_available_tag_selected(_index: int) -> void:
	# Enable the remove button when a tag is selected
	_remove_available_tag_button.disabled = false


func _on_available_tag_activated(index: int) -> void:
	# Move tag to active list when double-clicked
	var tag = _available_tags_list.get_item_text(index)
	_handle_tag_drag(tag, SOURCE_AVAILABLE, SOURCE_ACTIVE)


func _on_add_available_tag(text: String = "") -> void:
	var tag := _available_tags_input.text.strip_edges() if text.is_empty() else text.strip_edges()
	if tag.is_empty():
		return

	if not _validate_tag_name(tag):
		push_warning("Invalid tag name format: '%s'" % tag)
		return

	# Add to available tags if not already present
	if not _available_tags.has(tag):
		_available_tags.append(tag)
		print_rich(
			"[color=#%s]Added tag '%s' to available tags[/color]" % [LoggerColors.SUCCESS_HTML, tag]
		)

	_available_tags_input.clear()
	_refresh_tags_lists()
	_save_settings_to_config()


func _on_remove_available_tag() -> void:
	var selected := _available_tags_list.get_selected_items()
	if selected.is_empty():
		return

	var index := selected[0]
	if index >= 0 and index < _available_tags_list.item_count:
		var tag := _available_tags_list.get_item_text(index)

		# Check if the tag is in available list
		var tag_index = _available_tags.find(tag)
		if tag_index != -1:
			_available_tags.remove_at(tag_index)
			print_rich(
				(
					"[color=#%s]Removed tag '%s' from available tags[/color]"
					% [LoggerColors.SUCCESS_HTML, tag]
				)
			)

		_refresh_tags_lists()
		_save_settings_to_config()


# Active Tags handlers
func _on_active_tag_selected(_index: int) -> void:
	# Enable the remove button when a tag is selected
	_remove_tag_button.disabled = false


func _on_active_tag_activated(index: int) -> void:
	# Move to ignored when double-clicked
	var tag = _tags_list.get_item_text(index)
	_handle_tag_drag(tag, SOURCE_ACTIVE, SOURCE_IGNORED)


# Ignored Tags handlers
func _on_ignored_tag_selected(_index: int) -> void:
	# Enable the remove button when a tag is selected
	_remove_ignored_tag_button.disabled = false


func _on_ignored_tag_activated(index: int) -> void:
	# Move to active when double-clicked
	var tag = _ignored_tags_list.get_item_text(index)
	_handle_tag_drag(tag, SOURCE_IGNORED, SOURCE_ACTIVE)


# Original handlers (improved)
func _on_show_source_toggled(button_pressed: bool) -> void:
	_show_source = button_pressed
	_save_settings_to_config()


func _on_level_changed(index: int) -> void:
	_current_level = index
	_save_settings_to_config()


func _on_add_tag(text: String = "") -> void:
	var tag := _tags_input.text.strip_edges() if text.is_empty() else text.strip_edges()
	if tag.is_empty():
		return

	if not _validate_tag_name(tag):
		push_warning("Invalid tag name format: '%s'" % tag)
		return

	# Add to active tags if not already present
	if not _active_tags.has(tag):
		_active_tags.append(tag)

		# Remove from ignored tags if present
		if _ignored_tags.has(tag):
			_ignored_tags.erase(tag)

		# Add to available tags if not present
		if not _available_tags.has(tag):
			_available_tags.append(tag)

		print_rich(
			"[color=#%s]Added tag '%s' to active filters[/color]" % [LoggerColors.SUCCESS_HTML, tag]
		)

	_tags_input.clear()
	_refresh_tags_lists()
	_save_settings_to_config()


func _on_remove_tag() -> void:
	var selected := _tags_list.get_selected_items()
	if selected.is_empty():
		return

	var index := selected[0]
	if index >= 0 and index < _tags_list.item_count:
		var tag := _tags_list.get_item_text(index)
		if _active_tags.has(tag):
			_active_tags.erase(tag)
			print_rich(
				(
					"[color=#%s]Removed tag '%s' from active filters[/color]"
					% [LoggerColors.SUCCESS_HTML, tag]
				)
			)
			_refresh_tags_lists()
			_save_settings_to_config()


func _on_add_ignored_tag(text: String = "") -> void:
	var tag := _ignored_tags_input.text.strip_edges() if text.is_empty() else text.strip_edges()
	if tag.is_empty():
		return

	if not _validate_tag_name(tag):
		push_warning("Invalid tag name format: '%s'" % tag)
		return

	if not _ignored_tags.has(tag):
		_ignored_tags.append(tag)

		# Remove from active tags if present
		if _active_tags.has(tag):
			_active_tags.erase(tag)

		# Add to available tags if not present
		if not _available_tags.has(tag):
			_available_tags.append(tag)

		print_rich(
			"[color=#%s]Added tag '%s' to ignored tags[/color]" % [LoggerColors.SUCCESS_HTML, tag]
		)

	_ignored_tags_input.clear()
	_refresh_tags_lists()
	_save_settings_to_config()


func _on_remove_ignored_tag() -> void:
	var selected := _ignored_tags_list.get_selected_items()
	if selected.is_empty():
		return

	var index := selected[0]
	if index >= 0 and index < _ignored_tags_list.item_count:
		var tag := _ignored_tags_list.get_item_text(index)
		if _ignored_tags.has(tag):
			_ignored_tags.erase(tag)
			print_rich(
				(
					"[color=#%s]Removed tag '%s' from ignored tags[/color]"
					% [LoggerColors.SUCCESS_HTML, tag]
				)
			)
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
