@tool
class_name TagsTabController
extends RefCounted
## Controller for the Tags tab in the Logger dock
##
## Manages the Tags tab UI, including level selection, tag management,
## and tag setup operations.

signal tag_setup_saved(setup_name: String, active_tags: Array[String], ignored_tags: Array[String])
signal tag_setup_requested()

# UI Components (set via setup method)
var _level_option: OptionButton
var _available_tags_list: ItemList
var _tags_list: ItemList
var _ignored_tags_list: ItemList
var _setups_list: ItemList
var _save_setup_button: Button

# Dependencies (injected in constructor)
var _config: ConfigManager
var _tag_list_controller: TagListController
var _setup_list_controller: SetupListController
var _parent_dock: Control

# Current log level
var _current_level: int = 1  # INFO level

# Constructor with dependency injection
func _init(
	config: ConfigManager, 
	tag_list_controller: TagListController,
	setup_list_controller: SetupListController,
	parent_dock: Control
) -> void:
	_config = config
	_tag_list_controller = tag_list_controller
	_setup_list_controller = setup_list_controller
	_parent_dock = parent_dock
	
	# Connect controller signals - but not to UI yet
	_setup_list_controller.setup_loaded.connect(_on_setup_loaded)
	_setup_list_controller.setup_renamed.connect(_on_setup_renamed)

## Setup UI components - called by the main dock
func setup(
	level_option: OptionButton,
	available_tags_list: ItemList,
	tags_list: ItemList,
	ignored_tags_list: ItemList,
	setups_list: ItemList,
	save_setup_button: Button
) -> void:
	# Store references to UI components
	_level_option = level_option
	_available_tags_list = available_tags_list
	_tags_list = tags_list
	_ignored_tags_list = ignored_tags_list
	_setups_list = setups_list
	_save_setup_button = save_setup_button
	
	# Connect UI signals
	_level_option.item_selected.connect(_on_level_changed)
	_save_setup_button.pressed.connect(_on_save_setup_button_pressed)
	
	# Setup the tag list controller with UI references
	_tag_list_controller.setup(_available_tags_list, _tags_list, _ignored_tags_list)
	
	# Setup the setup list controller with UI references
	_setup_list_controller.setup(_setups_list)
	
	# Load initial data
	_load_level_from_config()
	
	# Note: tag_list_controller.load_tags_from_config() is now called by LoggerDock
	# Note: setup_list_controller.load_setups() is now called by LoggerDock

## Load the log level from config
func _load_level_from_config() -> void:
	_current_level = _config.get_log_level()
	if _level_option:
		_level_option.select(_current_level)

## Get the current tag lists
func get_tag_lists() -> Dictionary:
	return _tag_list_controller.get_tag_lists()

## Perform an initial tag scan if needed
func check_for_initial_scan() -> void:
	var tag_lists = _tag_list_controller.get_tag_lists()
	if tag_lists.available_tags.size() <= 1: # Accounting for possible example tag
		_scan_tags()

## Scan for tags with optional directory exclusion
func _scan_tags() -> int:
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

	# Let the controller handle the scan
	var added_count = _tag_list_controller.scan_tags(exclude_dirs)

	print_rich("[color=#%s]Tag scan complete. Added %d new tags.[/color]" %
		[LoggerColors.SUCCESS_HTML, added_count])
		
	return added_count

# Signal handlers

## Handler for level option change
func _on_level_changed(index: int) -> void:
	_current_level = index
	_config.set_log_level(index)

	# Save the configuration immediately so the change takes effect
	_config.save()

	print_rich("[color=#%s]Log level changed to %s[/color]" %
		[LoggerColors.INFO_HTML, ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"][index]])

## Handler for tag movement - this will be connected in the LoggerDock
func _on_tag_moved(tag: String, from_category: String, to_category: String) -> void:
	print_rich(
		"[color=#%s]Moved tag '%s' from %s to %s[/color]"
		% [LoggerColors.SUCCESS_HTML, tag, from_category, to_category]
	)
	# Signal that the startup message should be updated
	_parent_dock.call("_update_startup_message")

## Handler for setup loaded
func _on_setup_loaded(setup_name: String, active_tags: Array, ignored_tags: Array) -> void:
	print_rich("[color=#%s]Loading tag setup: %s[/color]" %
		[LoggerColors.INFO_HTML, setup_name])

	# Debug the incoming tags
	print_rich("[color=#%s]DEBUG: Loading active tags: %s[/color]" %
		[LoggerColors.DEBUG_HTML, active_tags])
	print_rich("[color=#%s]DEBUG: Loading ignored tags: %s[/color]" %
		[LoggerColors.DEBUG_HTML, ignored_tags])

	# 1. Directly convert the arrays for safety
	var active_tags_array: Array[String] = []
	for tag in active_tags:
		if tag is String:
			active_tags_array.append(tag)

	var ignored_tags_array: Array[String] = []
	for tag in ignored_tags:
		if tag is String:
			ignored_tags_array.append(tag)

	print_rich("[color=#%s]DEBUG: Converted active tags: %s[/color]" %
		[LoggerColors.DEBUG_HTML, active_tags_array])
	print_rich("[color=#%s]DEBUG: Converted ignored tags: %s[/color]" %
		[LoggerColors.DEBUG_HTML, ignored_tags_array])

	# 2. Set directly in the config
	_config.set_active_tags(active_tags_array)
	_config.set_ignored_tags(ignored_tags_array)

	# 3. Force save
	var save_result = _config.save()
	print_rich("[color=#%s]DEBUG: Config save result: %s[/color]" %
		[LoggerColors.DEBUG_HTML, "OK" if save_result == OK else error_string(save_result)])

	# 4. Update controller with the same values
	_tag_list_controller.set_active_tags(active_tags_array)
	_tag_list_controller.set_ignored_tags(ignored_tags_array)

	# 5. Force UI refresh
	_tag_list_controller.refresh_tag_lists()

	# 6. Verify what got set in config
	var saved_active = _config.get_active_tags()
	var saved_ignored = _config.get_ignored_tags()

	print_rich("[color=#%s]DEBUG: Saved active tags: %s[/color]" %
		[LoggerColors.DEBUG_HTML, saved_active])
	print_rich("[color=#%s]DEBUG: Saved ignored tags: %s[/color]" %
		[LoggerColors.DEBUG_HTML, saved_ignored])

	print_rich("[color=#%s]Loaded tag setup: %s[/color]" %
		[LoggerColors.SUCCESS_HTML, setup_name])

	# Signal that the startup message should be updated
	_parent_dock.call("_update_startup_message")

## Handler for setup renamed
func _on_setup_renamed(old_name: String, new_name: String) -> void:
	# If name is empty, signal to show the rename dialog
	if new_name.is_empty():
		# Signal to the main dock to show the rename dialog
		_parent_dock.call("_show_rename_dialog", old_name)
	else:
		print_rich("[color=#%s]Renamed tag setup: %s → %s[/color]" %
			[LoggerColors.SUCCESS_HTML, old_name, new_name])

## Handler for save setup button pressed
func _on_save_setup_button_pressed() -> void:
	# Signal to the main dock to show the setup dialog
	tag_setup_requested.emit()
