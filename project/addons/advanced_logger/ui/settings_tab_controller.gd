@tool
class_name SettingsTabController
extends RefCounted
## Controller for the Settings tab in the Logger dock
##
## Manages the Settings tab UI, including format settings,
## tag scanning, and general logger configuration.

signal settings_saved
signal settings_reset
signal tags_scanned(added_count: int)

# UI Components (set via setup method)
var _show_timestamp_check: CheckBox
var _show_tags_check: CheckBox
var _use_colors_check: CheckBox
var _show_source_check: CheckBox
var _save_button: Button
var _reset_button: Button
var _update_tags_button: Button

# Settings cache
var _show_timestamp: bool = true
var _show_tags: bool = true
var _use_colors: bool = true
var _show_source: bool = true

# Dependencies (injected in constructor)
var _config: ConfigManager
var _tag_list_controller: TagListController
var _parent_dock: Control

# Constructor with dependency injection
func _init(
	config: ConfigManager, 
	tag_list_controller: TagListController, 
	parent_dock: Control
) -> void:
	_config = config
	_tag_list_controller = tag_list_controller
	_parent_dock = parent_dock

## Setup UI components - called by the main dock
func setup(
	show_timestamp_check: CheckBox,
	show_tags_check: CheckBox,
	use_colors_check: CheckBox,
	show_source_check: CheckBox,
	save_button: Button,
	reset_button: Button,
	update_tags_button: Button
) -> void:
	# Store references to UI components
	_show_timestamp_check = show_timestamp_check
	_show_tags_check = show_tags_check
	_use_colors_check = use_colors_check
	_show_source_check = show_source_check
	_save_button = save_button
	_reset_button = reset_button
	_update_tags_button = update_tags_button
	
	# Connect UI signals
	_show_timestamp_check.toggled.connect(_on_show_timestamp_toggled)
	_show_tags_check.toggled.connect(_on_show_tags_toggled)
	_use_colors_check.toggled.connect(_on_use_colors_toggled)
	_show_source_check.toggled.connect(_on_show_source_toggled)
	_save_button.pressed.connect(_on_save_settings)
	_reset_button.pressed.connect(_on_reset_settings)
	_update_tags_button.pressed.connect(_on_scan_tags)
	
	# Load current settings from config
	_load_settings_from_config()

## Load settings from the ConfigManager
func _load_settings_from_config() -> void:
	# Load format settings
	_show_timestamp = _config.get_show_timestamp()
	_show_timestamp_check.button_pressed = _show_timestamp

	_show_tags = _config.get_show_tags()
	_show_tags_check.button_pressed = _show_tags

	_use_colors = _config.get_use_colors()
	_use_colors_check.button_pressed = _use_colors

	_show_source = _config.get_show_source()
	_show_source_check.button_pressed = _show_source

## Scan for tags in the project
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

	# Let the controller handle the scan
	var added_count = _tag_list_controller.scan_tags(exclude_dirs)

	print_rich("[color=#%s]Tag scan complete. Added %d new tags.[/color]" %
		[LoggerColors.SUCCESS_HTML, added_count])
	
	# Signal the results
	tags_scanned.emit(added_count)
	
	# Update the startup message
	_parent_dock.call("_update_startup_message")

## Save settings to config
func _save_settings_to_config() -> Error:
	# Save format settings
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

	return result

## Apply default settings
func _apply_defaults() -> void:
	# Set defaults using config default values
	_show_timestamp = ConfigManager.DEFAULT_SHOW_TIMESTAMP
	_show_tags = ConfigManager.DEFAULT_SHOW_TAGS
	_use_colors = ConfigManager.DEFAULT_USE_COLORS
	_show_source = ConfigManager.DEFAULT_SHOW_SOURCE

	# Update UI
	_show_timestamp_check.button_pressed = _show_timestamp
	_show_tags_check.button_pressed = _show_tags
	_use_colors_check.button_pressed = _use_colors
	_show_source_check.button_pressed = _show_source

	# Clear tag lists through the tag list controller
	var tag_lists = _tag_list_controller.get_tag_lists()
	tag_lists.available_tags.clear()
	tag_lists.active_tags.clear()
	tag_lists.ignored_tags.clear()
	_tag_list_controller.refresh_tag_lists()

	# Save to config
	_save_settings_to_config()
	_tag_list_controller.save_tags_to_config()

# Signal handlers for UI events

func _on_show_timestamp_toggled(button_pressed: bool) -> void:
	_show_timestamp = button_pressed
	_config.set_show_timestamp(button_pressed)
	_config.save()

func _on_show_tags_toggled(button_pressed: bool) -> void:
	_show_tags = button_pressed
	_config.set_show_tags(button_pressed)
	_config.save()

func _on_use_colors_toggled(button_pressed: bool) -> void:
	_use_colors = button_pressed
	_config.set_use_colors(button_pressed)
	_config.save()

func _on_show_source_toggled(button_pressed: bool) -> void:
	_show_source = button_pressed
	_config.set_show_source(button_pressed)
	_config.save()

func _on_save_settings() -> void:
	print_rich("[color=#%s]Attempting to save settings...[/color]" % LoggerColors.INFO_HTML)
	var result := _save_settings_to_config()

	if result == OK:
		print_rich(
			"[color=#%s]Settings saved successfully[/color]" % LoggerColors.SUCCESS_HTML
		)
		settings_saved.emit()
	else:
		print_rich(
			"[color=#%s]Failed to save settings: %s[/color]" %
			[LoggerColors.ERROR_HTML, error_string(result)]
		)

func _on_reset_settings() -> void:
	_apply_defaults()
	print_rich("[color=#%s]Logger settings reset to defaults[/color]" % LoggerColors.INFO_HTML)
	settings_reset.emit()
	
	# Update the startup message
	_parent_dock.call("_update_startup_message")
