@tool
class_name LoggerDock extends Control
## Editor dock for configuring the Advanced Logger settings
##
## Provides configuration UI for the Advanced Logger system with tag filtering,
## drag and drop tag management, and other logger settings.

# Preload the tag scanner
const TagScanner = preload("res://addons/advanced_logger/tag_scanner.gd")

# Override drag and drop methods for Godot 4
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				print_rich("[color=#%s]DEBUG: Mouse down at %s[/color]" % [LoggerColors.DEBUG_HTML, event.position])
				_handle_mouse_down(event.position)
			else:
				print_rich("[color=#%s]DEBUG: Mouse up at %s[/color]" % [LoggerColors.DEBUG_HTML, event.position])
				_handle_mouse_up(event.position)

func _handle_mouse_down(position: Vector2) -> void:
	# Check if the mouse is over any of the item lists
	var global_pos = get_global_mouse_position()

	# Check if the click is inside Available Tags
	if _available_tags_list.get_global_rect().has_point(global_pos):
		# Try to select an item
		var local_pos = _available_tags_list.get_local_mouse_position()
		var index = _available_tags_list.get_item_at_position(local_pos)
		if index >= 0:
			var tag = _available_tags_list.get_item_metadata(index)
			print_rich("[color=#%s]DEBUG: Selected tag in Available Tags: %s (index %d)[/color]" % [LoggerColors.DEBUG_HTML, tag, index])
			_available_tags_list.select(index)

	# Check if the click is inside Active Tags
	elif _tags_list.get_global_rect().has_point(global_pos):
		# Try to select an item
		var local_pos = _tags_list.get_local_mouse_position()
		var index = _tags_list.get_item_at_position(local_pos)
		if index >= 0:
			var tag = _tags_list.get_item_metadata(index)
			print_rich("[color=#%s]DEBUG: Selected tag in Active Tags: %s (index %d)[/color]" % [LoggerColors.DEBUG_HTML, tag, index])
			_tags_list.select(index)

	# Check if the click is inside Ignored Tags
	elif _ignored_tags_list.get_global_rect().has_point(global_pos):
		# Try to select an item
		var local_pos = _ignored_tags_list.get_local_mouse_position()
		var index = _ignored_tags_list.get_item_at_position(local_pos)
		if index >= 0:
			var tag = _ignored_tags_list.get_item_metadata(index)
			print_rich("[color=#%s]DEBUG: Selected tag in Ignored Tags: %s (index %d)[/color]" % [LoggerColors.DEBUG_HTML, tag, index])
			_ignored_tags_list.select(index)

func _handle_mouse_up(position: Vector2) -> void:
	# You can implement drop logic here if needed
	pass

# Create a common drag preview function for reusability
func _create_drag_preview(text: String) -> Control:
	var label = Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.8)

	var panel = Panel.new()
	panel.add_child(label)
	label.position = Vector2(10, 5)
	panel.custom_minimum_size = Vector2(label.get_minimum_size().x + 20, 30)

	return panel

# Helper method to format tags for display
func _format_tag_for_display(tag: String) -> String:
	if tag.is_empty():
		return tag
	return tag.substr(0, 1).capitalize() + tag.substr(1)

# Get drag data from any list with a single function
func _get_drag_data_for_list(item_list: ItemList, source_type: String) -> Variant:
	var indices = item_list.get_selected_items()
	if indices.size() == 0:
		return null

	var tag_index = indices[0]
	var tag_text = item_list.get_item_metadata(tag_index) # Get original tag from metadata

	if not _validate_tag_name(tag_text):
		push_warning("Invalid tag: '%s'" % tag_text)
		return null

	# Create drag data
	var drag_data = {
		"type": "tag",
		"tag": tag_text,
		"source": source_type,
		"index": tag_index
	}

	# Create preview (with capitalized display)
	set_drag_preview(_create_drag_preview(_format_tag_for_display(tag_text)))
	return drag_data

func _get_drag_data(at_position: Vector2) -> Variant:
	# Get global mouse position
	var global_pos = get_global_mouse_position()

	# Use a reusable function to handle all lists
	if _available_tags_list.get_global_rect().has_point(global_pos):
		return _get_drag_data_for_list(_available_tags_list, SOURCE_AVAILABLE)
	elif _tags_list.get_global_rect().has_point(global_pos):
		return _get_drag_data_for_list(_tags_list, SOURCE_ACTIVE)
	elif _ignored_tags_list.get_global_rect().has_point(global_pos):
		return _get_drag_data_for_list(_ignored_tags_list, SOURCE_IGNORED)

	return null

# Helper function to determine drop validity
func _can_drop_tag(tag: String, source: String, target: String) -> bool:
	# Can't drop to the same list
	if source == target:
		return false

	# Check valid source->target combinations
	match target:
		SOURCE_AVAILABLE:
			return source == SOURCE_ACTIVE or source == SOURCE_IGNORED
		SOURCE_ACTIVE:
			# Don't accept if already in active list
			if _active_tags.has(tag):
				return false
			return source == SOURCE_AVAILABLE or source == SOURCE_IGNORED
		SOURCE_IGNORED:
			# Don't accept if already in ignored list
			if _ignored_tags.has(tag):
				return false
			return source == SOURCE_AVAILABLE or source == SOURCE_ACTIVE

	return false

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# Validate the data
	if not data is Dictionary or not data.has("type") or data["type"] != "tag" or not data.has("tag"):
		return false

	var tag = data["tag"]
	var source = data.get("source", "")
	var mouse_pos = get_global_mouse_position()

	# Determine target list type and delegate to helper
	var target_type = ""
	if _available_tags_list.get_global_rect().has_point(mouse_pos):
		target_type = SOURCE_AVAILABLE
	elif _tags_list.get_global_rect().has_point(mouse_pos):
		target_type = SOURCE_ACTIVE
	elif _ignored_tags_list.get_global_rect().has_point(mouse_pos):
		target_type = SOURCE_IGNORED
	else:
		return false

	return _can_drop_tag(tag, source, target_type)

# Common function for handling drops with feedback
func _handle_drop_on_list(item_list: ItemList, tag: String, source: String, target: String) -> void:
	# Visual feedback to indicate drop success
	item_list.add_theme_color_override("font_selected_color", Color.GREEN)
	await get_tree().create_timer(0.2).timeout
	item_list.add_theme_color_override("font_selected_color", Color.WHITE)

	# Handle the tag movement
	_handle_tag_drag(tag, source, target)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	# Validate the data
	if not data is Dictionary or not data.has("type") or data["type"] != "tag" or not data.has("tag"):
		return

	var tag = data["tag"]
	var source = data.get("source", "")
	var mouse_pos = get_global_mouse_position()

	# Use a reusable function for handling drops on all lists
	if _available_tags_list.get_global_rect().has_point(mouse_pos):
		_handle_drop_on_list(_available_tags_list, tag, source, SOURCE_AVAILABLE)
	elif _tags_list.get_global_rect().has_point(mouse_pos):
		_handle_drop_on_list(_tags_list, tag, source, SOURCE_ACTIVE)
	elif _ignored_tags_list.get_global_rect().has_point(mouse_pos):
		_handle_drop_on_list(_ignored_tags_list, tag, source, SOURCE_IGNORED)

# Config constants
const CONFIG_PATH: String = "res://addons/advanced_logger/settings.cfg"
const CONFIG_SECTION_LOGGER: String = "logger"
const CONFIG_SECTION_FORMAT: String = "format"
const CONFIG_SECTION_SETUPS: String = "tag_setups"  # New section for tag setups
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

# Tag setups: Dictionary of name -> {active_tags, ignored_tags}
var _tag_setups: Dictionary = {}

# Drag and drop tracking (using Godot 4 virtual methods)

# Flag to avoid multiple saves during batch operations
var _batch_operation: bool = false

# UI Components - Updated paths for the tabbed interface
@onready var _level_option: OptionButton = $VBoxContainer/TabContainer/Tags/LevelSection/LevelOption
@onready var _startup_message: Label = $VBoxContainer/StartupMessage

# Available Tags components
@onready var _available_tags_list: ItemList = $VBoxContainer/TabContainer/Tags/TagsContainer/AvailableTagsSection/ScrollContainer/TagsList
@onready var _update_tags_button: Button = $VBoxContainer/TabContainer/Settings/ButtonsSection/UpdateTagsButton

# Active Tags components
@onready var _tags_list: ItemList = $VBoxContainer/TabContainer/Tags/TagsContainer/TagsSection/ScrollContainer/TagsList

# Ignored Tags components
@onready var _ignored_tags_list: ItemList = $VBoxContainer/TabContainer/Tags/TagsContainer/IgnoredTagsSection/ScrollContainer/IgnoredTagsList

# Tag Setup components
@onready var _setups_list: ItemList = $VBoxContainer/TabContainer/Tags/TagsContainer/SetupsSection/ScrollContainer/SetupsList
@onready var _save_setup_button: Button = $VBoxContainer/TabContainer/Tags/TagsContainer/SetupsSection/HBoxContainer/SaveSetupButton
@onready var _setup_name_dialog: ConfirmationDialog = $SetupNameDialog
@onready var _setup_name_input: LineEdit = $SetupNameDialog/VBoxContainer/SetupNameInput

@onready var _show_timestamp_check: CheckBox = $VBoxContainer/TabContainer/Settings/FormatSection/ShowTimestampCheck
@onready var _show_tags_check: CheckBox = $VBoxContainer/TabContainer/Settings/FormatSection/ShowTagsCheck
@onready var _use_colors_check: CheckBox = $VBoxContainer/TabContainer/Settings/FormatSection/UseColorsCheck
@onready var _show_source_check: CheckBox = $VBoxContainer/TabContainer/Settings/FormatSection/ShowSourceCheck
@onready var _save_button: Button = $VBoxContainer/TabContainer/Settings/ButtonsSection/SaveButton
@onready var _reset_button: Button = $VBoxContainer/TabContainer/Settings/ButtonsSection/ResetButton


func _ready() -> void:
	print_rich("[color=#%s]DEBUG: _ready called[/color]" % [LoggerColors.DEBUG_HTML])

	# Make sure drag is enabled on Control
	set_process_input(true)
	mouse_filter = MOUSE_FILTER_PASS

	# Connect UI signals
	_level_option.item_selected.connect(_on_level_changed)

	# Available Tags
	_update_tags_button.pressed.connect(_on_scan_tags)

	# Set up item selection and activation signals
	_available_tags_list.item_selected.connect(_on_available_tag_selected)
	_available_tags_list.item_activated.connect(_on_available_tag_activated)

	# Active Tags
	_tags_list.item_selected.connect(_on_active_tag_selected)
	_tags_list.item_activated.connect(_on_active_tag_activated)

	# Ignored Tags
	_ignored_tags_list.item_selected.connect(_on_ignored_tag_selected)
	_ignored_tags_list.item_activated.connect(_on_ignored_tag_activated)

	# Setup tag setups functionality
	_save_setup_button.pressed.connect(_on_save_setup_button_pressed)
	_setups_list.item_activated.connect(_on_setups_list_item_activated)
	_setups_list.item_clicked.connect(_on_setups_list_item_clicked)
	_setup_name_dialog.confirmed.connect(_on_setup_name_dialog_confirmed)

	# Configure all item lists with the same settings
	for list in [_available_tags_list, _tags_list, _ignored_tags_list, _setups_list]:
		list.mouse_filter = MOUSE_FILTER_PASS
		list.focus_mode = FOCUS_ALL
		list.allow_rmb_select = true
		list.allow_reselect = true

	# Enable dragging on all lists
	print_rich("[color=#%s]DEBUG: Drag and drop initialized[/color]" % [LoggerColors.DEBUG_HTML])

	# Format settings
	_show_timestamp_check.toggled.connect(_on_show_timestamp_toggled)
	_show_tags_check.toggled.connect(_on_show_tags_toggled)
	_use_colors_check.toggled.connect(_on_use_colors_toggled)
	_save_button.pressed.connect(_on_save_settings)
	_reset_button.pressed.connect(_on_reset_settings)
	_show_source_check.toggled.connect(_on_show_source_toggled)

	# Load settings from config
	_load_settings_from_config()

	# Load saved tag setups
	_load_setups_from_config()

	# Display startup message
	_update_startup_message()

	# Perform initial tag scan
	call_deferred("_initial_tag_scan")


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
			_available_tags_list.add_item(_format_tag_for_display(tag))
			_available_tags_list.set_item_metadata(_available_tags_list.item_count - 1, tag)

	# Clear and populate active tags list
	_tags_list.clear()
	for tag in _active_tags:
		_tags_list.add_item(_format_tag_for_display(tag))
		_tags_list.set_item_metadata(_tags_list.item_count - 1, tag)

	# Clear and populate ignored tags list
	_ignored_tags_list.clear()
	for tag in _ignored_tags:
		_ignored_tags_list.add_item(_format_tag_for_display(tag))
		_ignored_tags_list.set_item_metadata(_ignored_tags_list.item_count - 1, tag)


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
## Handle tag movement between categories with match statement for cleaner code
func _handle_tag_drag(tag: String, from_source: String, to_target: String) -> void:
	if not _validate_tag_name(tag) or from_source == to_target:
		return

	_begin_batch_operation()

	# Always ensure tag is in the available tags master list
	if not _available_tags.has(tag):
		_available_tags.append(tag)

	# Use match for cleaner code structure
	# Handle tag removal from source
	match from_source:
		SOURCE_ACTIVE:
			if _active_tags.has(tag):
				_active_tags.erase(tag)
		SOURCE_IGNORED:
			if _ignored_tags.has(tag):
				_ignored_tags.erase(tag)

	# Handle tag addition to target
	match to_target:
		SOURCE_AVAILABLE:
			# Remove from both filtered lists
			_active_tags.erase(tag)
			_ignored_tags.erase(tag)
		SOURCE_ACTIVE:
			_ignored_tags.erase(tag)
			if not _active_tags.has(tag):
				_active_tags.append(tag)
		SOURCE_IGNORED:
			_active_tags.erase(tag)
			if not _ignored_tags.has(tag):
				_ignored_tags.append(tag)

	_end_batch_operation()

	print_rich(
		"[color=#%s]Moved tag '%s' from %s to %s[/color]"
		% [LoggerColors.SUCCESS_HTML, tag, from_source, to_target]
	)


## Begin a batch operation to prevent multiple saves
func _begin_batch_operation() -> void:
	_batch_operation = true


## End a batch operation and save changes
func _end_batch_operation() -> void:
	_batch_operation = false
	_refresh_tags_lists()
	_save_settings_to_config()


# UI Event handlers


# Available Tags handlers
func _on_available_tag_selected(_index: int) -> void:
	# No longer need to enable any remove button
	pass


func _on_available_tag_activated(index: int) -> void:
	# Move tag to active list when double-clicked
	var tag = _available_tags_list.get_item_metadata(index)
	_handle_tag_drag(tag, SOURCE_AVAILABLE, SOURCE_ACTIVE)


# Active Tags handlers
func _on_active_tag_selected(_index: int) -> void:
	# No longer need to enable any remove button
	pass


func _on_active_tag_activated(index: int) -> void:
	# Move to ignored when double-clicked
	var tag = _tags_list.get_item_metadata(index)
	_handle_tag_drag(tag, SOURCE_ACTIVE, SOURCE_IGNORED)


# Ignored Tags handlers
func _on_ignored_tag_selected(_index: int) -> void:
	# No longer need to enable any remove button
	pass


func _on_ignored_tag_activated(index: int) -> void:
	# Move to active when double-clicked
	var tag = _ignored_tags_list.get_item_metadata(index)
	_handle_tag_drag(tag, SOURCE_IGNORED, SOURCE_ACTIVE)


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

## Performs an initial tag scan when the plugin is loaded
func _initial_tag_scan() -> void:
	# Only run if we have no available tags yet or they're empty
	if _available_tags.size() <= 1: # Accounting for possible example tag
		_on_scan_tags()

## Scans the project for tags used in Log calls and adds them to available tags
func _on_scan_tags() -> void:
	print_rich("[color=#%s]Scanning project for Log tags...[/color]" % LoggerColors.INFO_HTML)

	# Determine directories to exclude based on project settings
	var exclude_dirs: Array[String] = []
	var include_test_tags = ProjectSettings.get_setting("advanced_logger/include_test_tags", false)

	# If not including test tags, exclude the tests directory
	if not include_test_tags:
		exclude_dirs.append("res://tests/")
		print_rich("[color=#%s]Excluding test tags[/color]" % LoggerColors.INFO_HTML)
	else:
		print_rich("[color=#%s]Including test tags[/color]" % LoggerColors.INFO_HTML)

	# Get tags from the scanner with appropriate exclusions
	var scanner_tags: Array[String] = TagScanner.scan_project_for_tags(exclude_dirs)

	# Begin batch operation to prevent multiple saves
	_begin_batch_operation()

	# Add each tag to available tags if not already present
	var added_count := 0
	for tag in scanner_tags:
		if not _available_tags.has(tag):
			_available_tags.append(tag)
			added_count += 1

	# Sort tags alphabetically for easier finding
	_available_tags.sort()

	# End batch operation and save changes
	_end_batch_operation()

	print_rich("[color=#%s]Tag scan complete. Found %d tags, added %d new tags.[/color]" %
			   [LoggerColors.SUCCESS_HTML, scanner_tags.size(), added_count])

# Signal handlers that need to be defined
func _on_level_changed(index: int) -> void:
	_current_level = index
	_save_settings_to_config()

func _on_show_source_toggled(button_pressed: bool) -> void:
	_show_source = button_pressed
	_save_settings_to_config()

## Loads tag setups from the config file
func _load_setups_from_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_result: Error = config.load(CONFIG_PATH)

	if load_result != OK:
		# If file doesn't exist or other error, initialize with defaults
		_create_default_tag_setups()
		return

	# Check if the setups section exists
	if not config.has_section(CONFIG_SECTION_SETUPS):
		_create_default_tag_setups()
		return

	# Clear existing setups
	_tag_setups.clear()

	# Load each setup
	var setup_keys = config.get_section_keys(CONFIG_SECTION_SETUPS)
	for setup_name in setup_keys:
		var setup_data = config.get_value(CONFIG_SECTION_SETUPS, setup_name)
		if setup_data is Dictionary:
			if setup_data.has("active_tags") and setup_data.has("ignored_tags"):
				_tag_setups[setup_name] = setup_data

	# Refresh the setups list
	_refresh_setups_list()

## Creates default tag setups if none exist
func _create_default_tag_setups() -> void:
	_tag_setups = {
		"default": {
			"active_tags": [],
			"ignored_tags": []
		},
		"debug_network": {
			"active_tags": ["network"],
			"ignored_tags": []
		}
	}

	# Save the default setups to config
	_save_setups_to_config()

	# Refresh the UI
	_refresh_setups_list()

## Saves tag setups to the config file
func _save_setups_to_config() -> Error:
	var config: ConfigFile = ConfigFile.new()

	# Try to load existing config first to preserve other settings
	var load_result := config.load(CONFIG_PATH)
	if load_result != OK and load_result != ERR_FILE_NOT_FOUND:
		push_error("Failed to load existing config: %s" % error_string(load_result))
		# Continue anyway to try creating a new file

	# Save each setup in the setups section
	for setup_name in _tag_setups:
		config.set_value(CONFIG_SECTION_SETUPS, setup_name, _tag_setups[setup_name])

	# Try to save with better error handling
	var save_result: Error = config.save(CONFIG_PATH)
	if save_result == OK:
		print_rich(
			"[color=#%s]Tag setups saved successfully[/color]" % LoggerColors.SUCCESS_HTML
		)
	else:
		push_error("Failed to save tag setups: %s" % error_string(save_result))

	return save_result

## Refreshes the tag setups list UI
func _refresh_setups_list() -> void:
	_setups_list.clear()

	# Sort setup names alphabetically for consistency
	var sorted_names = _tag_setups.keys()
	sorted_names.sort()

	for setup_name in sorted_names:
		# Assign icons based on setup content
		var icon_index = 0 # Default icon
		var setup = _tag_setups[setup_name]

		# Different icon if it has active tags
		if setup.has("active_tags") and setup["active_tags"].size() > 0:
			icon_index = 1

		# Different icon if it has both active and ignored tags
		if setup.has("ignored_tags") and setup["ignored_tags"].size() > 0:
			icon_index = 2

		_setups_list.add_item(setup_name, null, true) # Allow selection by clicking anywhere on the row

# Tag Setup handlers
func _on_save_setup_button_pressed() -> void:
	_setup_name_input.text = ""
	_setup_name_dialog.title = "Save Tag Setup"
	_setup_name_dialog.dialog_text = "Enter a name for this tag setup:"
	_setup_name_dialog.popup_centered()
	_setup_name_input.grab_focus()

func _on_setup_name_dialog_confirmed() -> void:
	var setup_name = _setup_name_input.text.strip_edges()
	if setup_name.is_empty():
		push_warning("Setup name cannot be empty")
		return

	# Create the setup data
	var setup = {
		"active_tags": _active_tags.duplicate(),
		"ignored_tags": _ignored_tags.duplicate()
	}

	# Add or update the setup
	_tag_setups[setup_name] = setup

	# Save to config
	_save_setups_to_config()

	# Refresh the UI
	_refresh_setups_list()

	print_rich("[color=#%s]Saved tag setup: %s[/color]" %
		   [LoggerColors.SUCCESS_HTML, setup_name])

func _on_setups_list_item_activated(index: int) -> void:
	var setup_name = _setups_list.get_item_text(index)
	print_rich("[color=#%s]Loading tag setup: %s[/color]" % [LoggerColors.INFO_HTML, setup_name])
	_load_setup(setup_name)

func _on_setups_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	# Only show context menu on right click
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return

	var setup_name = _setups_list.get_item_text(index)

	var menu = PopupMenu.new()
	menu.add_item("Load", 0)
	menu.add_item("Rename", 1)
	menu.add_item("Delete", 2)

	var handle_menu_selection = func(idx: int):
		match idx:
			0: # Load
				_load_setup(setup_name)
			1: # Rename
				_show_rename_dialog(setup_name)
			2: # Delete
				_delete_setup(setup_name)
		menu.queue_free()

	menu.id_pressed.connect(handle_menu_selection)

	add_child(menu)
	# Position the menu at the mouse position
	menu.position = get_viewport().get_mouse_position()
	menu.popup()

func _load_setup(setup_name: String) -> void:
	if not _tag_setups.has(setup_name):
		push_warning("Tag setup not found: %s" % setup_name)
		return

	var setup = _tag_setups[setup_name]

	# Start batch operation to prevent multiple saves
	_begin_batch_operation()

	# Clear existing tags
	_active_tags.clear()
	_ignored_tags.clear()

	# Load tags from setup
	if setup.has("active_tags"):
		for tag in setup["active_tags"]:
			_active_tags.append(tag)

	if setup.has("ignored_tags"):
		for tag in setup["ignored_tags"]:
			_ignored_tags.append(tag)

	# End batch operation and save changes
	_end_batch_operation()

	print_rich("[color=#%s]Loaded tag setup: %s[/color]" %
		   [LoggerColors.SUCCESS_HTML, setup_name])

func _show_rename_dialog(old_name: String) -> void:
	# Store the old name for later reference
	_setup_name_input.text = old_name
	_setup_name_dialog.title = "Rename Setup"
	_setup_name_dialog.dialog_text = ""  # Clear dialog text to avoid overlap

	# Use a custom connection for the rename operation
	if _setup_name_dialog.is_connected("confirmed", _on_setup_name_dialog_confirmed):
		_setup_name_dialog.confirmed.disconnect(_on_setup_name_dialog_confirmed)

	# Create a one-time callback
	var rename_handler = func():
		var new_name = _setup_name_input.text.strip_edges()
		if not new_name.is_empty() and new_name != old_name:
			if _tag_setups.has(old_name):
				var setup = _tag_setups[old_name]
				_tag_setups.erase(old_name)
				_tag_setups[new_name] = setup
				_save_setups_to_config()
				_refresh_setups_list()
				print_rich("[color=#%s]Renamed tag setup: %s → %s[/color]" %
						[LoggerColors.SUCCESS_HTML, old_name, new_name])

		# Reset dialog for normal saves
		_setup_name_dialog.title = "Save Tag Setup"
		_setup_name_dialog.dialog_text = "Enter a name for this tag setup:"

		# Reconnect the normal handler
		if not _setup_name_dialog.is_connected("confirmed", _on_setup_name_dialog_confirmed):
			_setup_name_dialog.confirmed.connect(_on_setup_name_dialog_confirmed)

	# Connect the one-time handler
	_setup_name_dialog.confirmed.connect(rename_handler, Object.CONNECT_ONE_SHOT)

	# Show the dialog
	_setup_name_dialog.popup_centered()

func _delete_setup(setup_name: String) -> void:
	if not _tag_setups.has(setup_name):
		push_warning("Tag setup not found: %s" % setup_name)
		return

	_tag_setups.erase(setup_name)
	_save_setups_to_config()
	_refresh_setups_list()

	print_rich("[color=#%s]Deleted tag setup: %s[/color]" %
		   [LoggerColors.SUCCESS_HTML, setup_name])
