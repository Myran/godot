@tool
class_name LoggerDock extends Control
## Editor dock for configuring the Advanced Logger settings
##
## Provides configuration UI for the Advanced Logger system with tag filtering,
## drag and drop tag management, and other logger settings.

# Preload required dependencies
const TagScanner = preload("res://addons/advanced_logger/tag_scanner.gd")
const TagManager = preload("res://addons/advanced_logger/tag_manager.gd")
const ConfigManager = preload("res://addons/advanced_logger/config_manager.gd")
const TagSetupManager = preload("res://addons/advanced_logger/tag_setup_manager.gd")

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
	return TagManager.format_tag_for_display(tag)

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


# Tag source constants to replace magic strings
const SOURCE_AVAILABLE: String = "available"
const SOURCE_ACTIVE: String = "active"
const SOURCE_IGNORED: String = "ignored"

# Settings cache
var _current_level: int = 1  # INFO level
var _active_tags: Array[String] = []
var _ignored_tags: Array[String] = []
var _available_tags: Array[String] = []
var _show_timestamp: bool = true
var _show_tags: bool = true
var _use_colors: bool = true
var _show_source: bool = true

# Config manager instance
var _config: ConfigManager = null

# Tag setup manager instance
var _setup_manager: TagSetupManager = null

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

	# Get the config instance
	_config = ConfigManager.get_instance()

	# Create tag setup manager
	_setup_manager = TagSetupManager.new(_config)

	# Register for configuration changes
	_config.config_changed.connect(_on_config_changed)

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

	# Connect setup manager signals
	_setup_manager.setup_changed.connect(_on_setup_changed)
	_setup_manager.setup_deleted.connect(_on_setup_deleted)
	_setup_manager.setup_renamed.connect(_on_setup_renamed)

	# Display startup message
	_update_startup_message()

	# Perform initial tag scan
	call_deferred("_initial_tag_scan")

## Handles configuration changes
func _on_config_changed(section: String, key: String, value: Variant) -> void:
	# Update internal state when config changes
	if section == ConfigManager.SECTION_LOGGER:
		if key == ConfigManager.KEY_LOG_LEVEL:
			_current_level = value
			_level_option.select(_current_level)
		elif key == ConfigManager.KEY_ACTIVE_TAGS:
			_active_tags = value
			_refresh_tags_lists()
		elif key == ConfigManager.KEY_IGNORED_TAGS:
			_ignored_tags = value
			_refresh_tags_lists()
		elif key == ConfigManager.KEY_AVAILABLE_TAGS:
			_available_tags = value
			_refresh_tags_lists()
	elif section == ConfigManager.SECTION_FORMAT:
		if key == ConfigManager.KEY_SHOW_TIMESTAMP:
			_show_timestamp = value
			_show_timestamp_check.button_pressed = _show_timestamp
		elif key == ConfigManager.KEY_SHOW_TAGS:
			_show_tags = value
			_show_tags_check.button_pressed = _show_tags
		elif key == ConfigManager.KEY_USE_COLORS:
			_use_colors = value
			_use_colors_check.button_pressed = _use_colors
		elif key == ConfigManager.KEY_SHOW_SOURCE:
			_show_source = value
			_show_source_check.button_pressed = _show_source
	elif section == ConfigManager.SECTION_SETUPS:
		# A tag setup was changed
		_load_setups_from_config()

	# Update startup message
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


## Loads logger settings from the ConfigManager
func _load_settings_from_config() -> void:
	# Load log level
	_current_level = _config.get_log_level()
	_level_option.select(_current_level)

	# Load available tags
	_available_tags = _config.get_available_tags()

	# Load active tags
	_active_tags = _config.get_active_tags()

	# Load ignored tags
	_ignored_tags = _config.get_ignored_tags()

	# Make sure active and ignored tags are in available tags
	for tag in _active_tags:
		if not _available_tags.has(tag):
			_available_tags.append(tag)

	for tag in _ignored_tags:
		if not _available_tags.has(tag):
			_available_tags.append(tag)

	# Load format settings
	_show_timestamp = _config.get_show_timestamp()
	_show_timestamp_check.button_pressed = _show_timestamp

	_show_tags = _config.get_show_tags()
	_show_tags_check.button_pressed = _show_tags

	_use_colors = _config.get_use_colors()
	_use_colors_check.button_pressed = _use_colors

	_show_source = _config.get_show_source()
	_show_source_check.button_pressed = _show_source

	# Refresh UI
	_refresh_tags_lists()


## Saves logger settings to the ConfigManager
## Returns OK if successful, otherwise returns an error code
func _save_settings_to_config() -> Error:
	# Skip saving during batch operations
	if _batch_operation:
		return OK

	# Set all values in the config
	_config.set_log_level(_current_level)
	_config.set_active_tags(_active_tags)
	_config.set_ignored_tags(_ignored_tags)
	_config.set_available_tags(_available_tags)
	_config.set_show_timestamp(_show_timestamp)
	_config.set_show_tags(_show_tags)
	_config.set_use_colors(_use_colors)
	_config.set_show_source(_show_source)

	# Save the config
	var result = _config.save()

	if result == OK:
		print_rich(
			"[color=#%s]Logger settings saved successfully[/color]" % LoggerColors.SUCCESS_HTML
		)
	else:
		push_error("Failed to save settings: %s" % error_string(result))

	# Update startup message
	_update_startup_message()

	return result


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
	# Set defaults using config default values
	_current_level = ConfigManager.DEFAULT_LOG_LEVEL
	_available_tags.clear()
	_active_tags.clear()
	_ignored_tags.clear()
	_show_timestamp = ConfigManager.DEFAULT_SHOW_TIMESTAMP
	_show_tags = ConfigManager.DEFAULT_SHOW_TAGS
	_use_colors = ConfigManager.DEFAULT_USE_COLORS
	_show_source = ConfigManager.DEFAULT_SHOW_SOURCE

	# Update UI
	_level_option.select(_current_level)
	_show_timestamp_check.button_pressed = _show_timestamp
	_show_tags_check.button_pressed = _show_tags
	_use_colors_check.button_pressed = _use_colors
	_show_source_check.button_pressed = _show_source
	_refresh_tags_lists()

	# Save to config
	_save_settings_to_config()


## Validates a tag name is properly formatted
## Returns true if the tag is valid, false otherwise
func _validate_tag_name(tag: String) -> bool:
	return TagManager.is_valid_tag(tag)


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
	if not TagManager.is_valid_tag(tag) or from_source == to_target:
		return

	_begin_batch_operation()

	# Use the TagManager for handling tag movement
	var result = TagManager.move_tag(
		tag,
		from_source,
		to_target,
		_available_tags,
		_active_tags,
		_ignored_tags
	)

	# Update arrays with the result
	_available_tags = result.available_tags
	_active_tags = result.active_tags
	_ignored_tags = result.ignored_tags

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
	_config.set_show_timestamp(button_pressed)
	_save_settings_to_config()


func _on_show_tags_toggled(button_pressed: bool) -> void:
	_show_tags = button_pressed
	_config.set_show_tags(button_pressed)
	_save_settings_to_config()


func _on_use_colors_toggled(button_pressed: bool) -> void:
	_use_colors = button_pressed
	_config.set_use_colors(button_pressed)
	_save_settings_to_config()


func _on_save_settings() -> void:
	print_rich("[color=#%s]Attempting to save settings...[/color]" % LoggerColors.INFO_HTML)
	var result := _save_settings_to_config()

	if result == OK:
		print_rich(
			"[color=#%s]Settings saved successfully[/color]" % LoggerColors.SUCCESS_HTML
		)
	else:
		print_rich(
			"[color=#%s]Failed to save settings: %s[/color]" %
			[LoggerColors.ERROR_HTML, error_string(result)]
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
	_config.set_log_level(index)
	_save_settings_to_config()

func _on_show_source_toggled(button_pressed: bool) -> void:
	_show_source = button_pressed
	_config.set_show_source(button_pressed)
	_save_settings_to_config()

## Loads tag setups and refreshes the UI
func _load_setups_from_config() -> void:
	# If no setups exist, create defaults
	if _setup_manager.get_all_setups().is_empty():
		_setup_manager.create_default_setups()

	# Refresh the setups list
	_refresh_setups_list()

## Refreshes the tag setups list UI
func _refresh_setups_list() -> void:
	_setups_list.clear()

	# Get all setups from the manager
	var setups = _setup_manager.get_all_setups()
	# Sort setup names alphabetically for consistency
	var sorted_names = setups.keys()
	sorted_names.sort()

	for setup_name in sorted_names:
		# Assign icons based on setup content
		var icon_index = 0 # Default icon
		var setup = setups[setup_name]

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

	# Save the setup using the manager
	var result = _setup_manager.save_setup(setup_name, _active_tags, _ignored_tags)

	if result == OK:
		print_rich("[color=#%s]Saved tag setup: %s[/color]" %
			[LoggerColors.SUCCESS_HTML, setup_name])
	else:
		push_error("Failed to save tag setup: %s" % error_string(result))

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
	if _setup_manager == null:
		return

	var setup = _setup_manager.get_setup(setup_name)
	if setup.is_empty():
		push_warning("Tag setup not found: %s" % setup_name)
		return

	_begin_batch_operation()

	_active_tags.clear()
	_ignored_tags.clear()

	if setup.has("active_tags"):
		for tag in setup["active_tags"]:
			_active_tags.append(tag)

	if setup.has("ignored_tags"):
		for tag in setup["ignored_tags"]:
			_ignored_tags.append(tag)

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
			var result = _setup_manager.rename_setup(old_name, new_name)
			if result != OK:
				push_error("Failed to rename setup: %s" % error_string(result))

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
	if _setup_manager == null:
		return

	var result = _setup_manager.delete_setup(setup_name)
	if result != OK && result != ERR_DOES_NOT_EXIST:
		push_error("Failed to delete setup: %s" % error_string(result))

## Signal handler for setup_changed event from TagSetupManager
func _on_setup_changed(setup_name: String, is_new: bool) -> void:
	# Refresh the setups list
	_refresh_setups_list()

	# Log message based on whether it's a new setup or update
	if is_new:
		print_rich("[color=#%s]Created new tag setup: %s[/color]" %
			[LoggerColors.SUCCESS_HTML, setup_name])
	else:
		print_rich("[color=#%s]Updated tag setup: %s[/color]" %
			[LoggerColors.SUCCESS_HTML, setup_name])

## Signal handler for setup_deleted event from TagSetupManager
func _on_setup_deleted(setup_name: String) -> void:
	# Refresh the setups list
	_refresh_setups_list()

	print_rich("[color=#%s]Deleted tag setup: %s[/color]" %
		[LoggerColors.SUCCESS_HTML, setup_name])

## Signal handler for setup_renamed event from TagSetupManager
func _on_setup_renamed(old_name: String, new_name: String) -> void:
	# Refresh the setups list
	_refresh_setups_list()

	print_rich("[color=#%s]Renamed tag setup: %s → %s[/color]" %
		[LoggerColors.SUCCESS_HTML, old_name, new_name])
