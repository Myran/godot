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
			print_rich("[color=#%s]DEBUG: Selected tag in Available Tags at index %d[/color]" % [LoggerColors.DEBUG_HTML, index])
			_available_tags_list.select(index)

	# Check if the click is inside Active Tags
	elif _tags_list.get_global_rect().has_point(global_pos):
		# Try to select an item
		var local_pos = _tags_list.get_local_mouse_position()
		var index = _tags_list.get_item_at_position(local_pos)
		if index >= 0:
			print_rich("[color=#%s]DEBUG: Selected tag in Active Tags at index %d[/color]" % [LoggerColors.DEBUG_HTML, index])
			_tags_list.select(index)

	# Check if the click is inside Ignored Tags
	elif _ignored_tags_list.get_global_rect().has_point(global_pos):
		# Try to select an item
		var local_pos = _ignored_tags_list.get_local_mouse_position()
		var index = _ignored_tags_list.get_item_at_position(local_pos)
		if index >= 0:
			print_rich("[color=#%s]DEBUG: Selected tag in Ignored Tags at index %d[/color]" % [LoggerColors.DEBUG_HTML, index])
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

# Get drag data from any list with a single function
func _get_drag_data_for_list(item_list: ItemList, source_type: String) -> Variant:
	var indices = item_list.get_selected_items()
	if indices.size() == 0:
		return null

	var tag_index = indices[0]
	var tag_text = item_list.get_item_text(tag_index)

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

	# Create preview
	set_drag_preview(_create_drag_preview(tag_text))
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

# Drag and drop tracking (using Godot 4 virtual methods)

# Flag to avoid multiple saves during batch operations
var _batch_operation: bool = false

# UI Components
@onready var _show_source_check: CheckBox = $VBoxContainer/FormatSection/ShowSourceCheck
@onready var _level_option: OptionButton = $VBoxContainer/LevelSection/LevelOption
@onready var _startup_message: Label = $VBoxContainer/StartupMessage  # New startup message label

# Available Tags components
@onready var _available_tags_list: ItemList = $VBoxContainer/TagsContainer/AvailableTagsSection/ScrollContainer/TagsList
@onready var _update_tags_button: Button = $VBoxContainer/TagsContainer/AvailableTagsSection/UpdateTagsButton

# Active Tags components
@onready var _tags_list: ItemList = $VBoxContainer/TagsContainer/TagsSection/ScrollContainer/TagsList

# Ignored Tags components
@onready var _ignored_tags_list: ItemList = $VBoxContainer/TagsContainer/IgnoredTagsSection/ScrollContainer/IgnoredTagsList

@onready var _show_timestamp_check: CheckBox = $VBoxContainer/FormatSection/ShowTimestampCheck
@onready var _show_tags_check: CheckBox = $VBoxContainer/FormatSection/ShowTagsCheck
@onready var _use_colors_check: CheckBox = $VBoxContainer/FormatSection/UseColorsCheck
@onready var _save_button: Button = $VBoxContainer/ButtonsSection/SaveButton
@onready var _reset_button: Button = $VBoxContainer/ButtonsSection/ResetButton


func _ready() -> void:
	print_rich("[color=#%s]DEBUG: _ready called[/color]" % [LoggerColors.DEBUG_HTML])

	# Make sure drag is enabled on Control
	set_process_input(true)
	mouse_filter = MOUSE_FILTER_PASS

	# Connect UI signals
	_level_option.item_selected.connect(_on_level_changed)

	# Available Tags - button now respects the project setting
	_update_tags_button.pressed.connect(
		func(): _on_scan_tags() # Will use project setting to determine test tag inclusion
	)

	# Set up item activation signals
	_available_tags_list.item_activated.connect(_on_available_tag_activated)

	# Active Tags - Set up item activation signals
	_tags_list.item_activated.connect(_on_active_tag_activated)

	# Ignored Tags - Set up item activation signals
	_ignored_tags_list.item_activated.connect(_on_ignored_tag_activated)

	# Configure all item lists with the same settings
	for list in [_available_tags_list, _tags_list, _ignored_tags_list]:
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

	# No longer using the update all tags button - test tags inclusion is controlled by project parameter

	# Load settings from config
	_load_settings_from_config()

	# Display startup message
	_update_startup_message()

	# Ensure all lists are properly sized
	call_deferred("_resize_all_lists")

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
			_available_tags_list.add_item(tag)

	# Adjust available tags list height based on content
	_resize_list_to_fit_content(_available_tags_list)

	# Clear and populate active tags list
	_tags_list.clear()
	for tag in _active_tags:
		_tags_list.add_item(tag)

	# Adjust active tags list height based on content
	_resize_list_to_fit_content(_tags_list)

	# Clear and populate ignored tags list
	_ignored_tags_list.clear()
	for tag in _ignored_tags:
		_ignored_tags_list.add_item(tag)

	# Adjust ignored tags list height based on content
	_resize_list_to_fit_content(_ignored_tags_list)


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
func _on_available_tag_activated(index: int) -> void:
	# Move tag to active list when double-clicked
	var tag = _available_tags_list.get_item_text(index)
	_handle_tag_drag(tag, SOURCE_AVAILABLE, SOURCE_ACTIVE)

# Active Tags handlers
func _on_active_tag_activated(index: int) -> void:
	# Move to ignored when double-clicked
	var tag = _tags_list.get_item_text(index)
	_handle_tag_drag(tag, SOURCE_ACTIVE, SOURCE_IGNORED)

# Ignored Tags handlers
func _on_ignored_tag_activated(index: int) -> void:
	# Move to active when double-clicked
	var tag = _ignored_tags_list.get_item_text(index)
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

## Calculates available space for tag lists, ensuring balanced distribution
func _calculate_balanced_list_heights() -> void:
	# Get total available height for the dock
	var total_height: float = get_viewport_rect().size.y

	# Estimate space taken by other UI elements (labels, buttons, etc.)
	var other_elements_height: float = 300.0  # Estimated height of non-list elements

	# Available space for the three tag lists
	var available_list_space: float = max(300.0, total_height - other_elements_height)

	# Count total items across all lists to determine proportional heights
	var total_items := _available_tags_list.item_count + _tags_list.item_count + _ignored_tags_list.item_count

	# Ensure minimal height for empty lists
	if total_items == 0:
		total_items = 3  # Treat as if each list had 1 item

	# Calculate proportional heights for each list (with minimum of 100)
	var min_list_height := 100.0

	# Proportional height calculation based on item count in each list
	var avail_proportion: float = float(_available_tags_list.item_count) / total_items
	var active_proportion: float = float(_tags_list.item_count) / total_items
	var ignored_proportion: float = float(_ignored_tags_list.item_count) / total_items

	# Assign heights, ensuring a minimum
	_available_tags_list.custom_minimum_size.y = max(min_list_height, available_list_space * avail_proportion)
	_tags_list.custom_minimum_size.y = max(min_list_height, available_list_space * active_proportion)
	_ignored_tags_list.custom_minimum_size.y = max(min_list_height, available_list_space * ignored_proportion)

## Resizes all tag lists to ensure proper display
func _resize_all_lists() -> void:
	# Option 1: Fixed sizing based on content
	_resize_list_to_fit_content(_available_tags_list)
	_resize_list_to_fit_content(_tags_list)
	_resize_list_to_fit_content(_ignored_tags_list)

	# Option 2: Dynamic balanced sizing (uncomment to use)
	# _calculate_balanced_list_heights()

## Performs an initial tag scan when the plugin is loaded
func _initial_tag_scan() -> void:
	# Only run if we have no available tags yet or they're empty
	if _available_tags.size() <= 1: # Accounting for possible example tag
		_on_scan_tags() # Uses project setting to determine test tag inclusion

## Scans the project for tags used in Log calls and adds them to available tags
func _on_scan_tags(include_test_tags: bool = false) -> void:
	print_rich("[color=#%s]Scanning project for Log tags...[/color]" % LoggerColors.INFO_HTML)

	# Check for project parameter to determine if test tags should be included
	var project_include_test_tags: bool = ProjectSettings.get_setting("advanced_logger/include_test_tags", false)

	# Parameter overrides project setting if directly specified
	var final_include_test_tags: bool = include_test_tags or project_include_test_tags

	# Directories to exclude during normal development
	var exclude_dirs: Array[String] = []
	if not final_include_test_tags:
		exclude_dirs = ["res://tests/"]
		print_rich("[color=#%s]Excluding test directories: %s[/color]" %
			[LoggerColors.INFO_HTML, ", ".join(exclude_dirs)])
	else:
		print_rich("[color=#%s]Including test directories (test mode)[/color]" % LoggerColors.INFO_HTML)

	# Get tags from the scanner
	var scanner_tags: Array[String] = TagScanner.scan_project_for_tags(exclude_dirs)

	# Begin batch operation to prevent multiple saves
	_begin_batch_operation()

	# Add each tag to available tags if not already present
	var added_count := 0
	for tag in scanner_tags:
		if not _available_tags.has(tag):
			_available_tags.append(tag)
			added_count += 1

	# Also check for constant tags in data_source.gd that might not be directly used in Log calls
	var additional_tags := _scan_for_tag_constants()
	for tag in additional_tags:
		if not _available_tags.has(tag) and not scanner_tags.has(tag):
			_available_tags.append(tag)
			added_count += 1

	# Sort tags alphabetically for easier finding
	_available_tags.sort()

	# End batch operation and save changes
	_end_batch_operation()

	# Ensure lists are properly sized after adding new tags
	_resize_all_lists()

	print_rich("[color=#%s]Tag scan complete. Found %d tags, added %d new tags.[/color]" %
			   [LoggerColors.SUCCESS_HTML, scanner_tags.size(), added_count])

## Scans for TAG constant definitions in source files
func _scan_for_tag_constants() -> Array[String]:
	print_rich("[color=#%s]Looking for additional TAG constants...[/color]" % LoggerColors.INFO_HTML)

	var additional_tags: Array[String] = []
	var files_to_check: Array[String] = [
		"res://autoloads/data_source.gd"
	]

	for file_path in files_to_check:
		var file := FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue

		var content := file.get_as_text()
		file.close()

		# Look for tag constants using regex
		var regex := RegEx.new()
		regex.compile("const\\s+TAG_[A-Za-z0-9_]+\\s*:\\s*String\\s*=\\s*\"([^\"]+)\"")

		var matches := regex.search_all(content)
		for match_result in matches:
			if match_result.strings.size() >= 2:
				var tag := match_result.strings[1]
				if not additional_tags.has(tag) and LoggerSettings._is_valid_tag(tag):
					additional_tags.append(tag)
					print_rich("[color=#%s]Found tag constant: %s[/color]" % [LoggerColors.INFO_HTML, tag])

	return additional_tags

# Signal handlers that need to be defined
func _on_level_changed(index: int) -> void:
	_current_level = index
	_save_settings_to_config()

## Resizes an ItemList to fit its content while maintaining a minimum height
## and ensuring all items are visible
func _resize_list_to_fit_content(item_list: ItemList) -> void:
	# Keep a minimum height for easy drag and drop interaction
	var min_height := 100.0

	# Calculate required height based on item count and item height
	var item_count := item_list.item_count

	if item_count == 0:
		# Keep minimum height even when empty
		item_list.custom_minimum_size.y = min_height
		return

	# Use a default item height if theme is not available yet
	var item_height: float = 24.0  # Common default height for items

	# Try different approaches to get the font height
	var font
	var font_size: float = 16.0  # Default size

	# Approach 1: Try to get theme font from the ItemList directly
	if item_list.has_theme_font_override("font"):
		font = item_list.get_theme_font_override("font")
		if item_list.has_theme_font_size_override("font_size"):
			font_size = item_list.get_theme_font_size_override("font_size")
	# Approach 2: Try to get from the theme using type name
	elif has_theme_font("font", "ItemList"):
		font = get_theme_font("font", "ItemList")
		if has_theme_font_size("font_size", "ItemList"):
			font_size = get_theme_font_size("font_size", "ItemList")
	# Approach 3: Try to get default theme font
	else:
		font = ThemeDB.fallback_font
		font_size = ThemeDB.fallback_font_size

	# Calculate item height if we have a valid font
	if font:
		item_height = font.get_height(font_size) + 10  # Adding padding

	# Add a bit more height per item for visual spacing
	var visible_items := min(item_count, 15)  # Cap maximum visible items
	var required_height: float = visible_items * item_height + 20  # Extra padding for better visibility

	# For long lists, we add a bit more space for the scrollbar
	if item_count > 15:
		required_height += 10

	# Use the larger of minimum height or required height
	item_list.custom_minimum_size.y = max(min_height, required_height)

	# Request layout update
	item_list.queue_redraw()

func _on_show_source_toggled(button_pressed: bool) -> void:
	_show_source = button_pressed
	_save_settings_to_config()
