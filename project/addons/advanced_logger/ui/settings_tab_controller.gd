@tool
class_name SettingsTabController
extends RefCounted

signal settings_saved
signal settings_reset
signal tags_scanned(added_count: int)

var _show_timestamp_check: CheckBox
var _show_tags_check: CheckBox
var _use_colors_check: CheckBox
var _show_source_check: CheckBox
var _buffer_size_spin: SpinBox
var _enable_buffer_dump_check: CheckBox
var _show_editor_debug_check: CheckBox
var _save_button: Button
var _reset_button: Button
var _update_tags_button: Button

var _show_timestamp: bool = true
var _show_tags: bool = true
var _use_colors: bool = true
var _show_source: bool = true
var _buffer_size: int = ConfigManager.DEFAULT_BUFFER_SIZE
var _enable_buffer_dump: bool = ConfigManager.DEFAULT_ENABLE_BUFFER_DUMP
var _show_editor_debug: bool = ConfigManager.DEFAULT_SHOW_EDITOR_DEBUG

var _show_debug: bool = false

var _config: ConfigManager
var _tag_list_controller: TagListController
var _parent_dock: Control


func _init(
	config: ConfigManager, tag_list_controller: TagListController, parent_dock: Control
) -> void:
	_config = config
	_tag_list_controller = tag_list_controller
	_parent_dock = parent_dock


func setup(
	show_timestamp_check: CheckBox,
	show_tags_check: CheckBox,
	use_colors_check: CheckBox,
	show_source_check: CheckBox,
	buffer_size_spin: SpinBox,
	enable_buffer_dump_check: CheckBox,
	show_editor_debug_check: CheckBox,
	save_button: Button,
	reset_button: Button,
	update_tags_button: Button
) -> void:
	_show_timestamp_check = show_timestamp_check
	_show_tags_check = show_tags_check
	_use_colors_check = use_colors_check
	_show_source_check = show_source_check
	_buffer_size_spin = buffer_size_spin
	_enable_buffer_dump_check = enable_buffer_dump_check
	_show_editor_debug_check = show_editor_debug_check
	_save_button = save_button
	_reset_button = reset_button
	_update_tags_button = update_tags_button

	_show_timestamp_check.toggled.connect(_on_show_timestamp_toggled)
	_show_tags_check.toggled.connect(_on_show_tags_toggled)
	_use_colors_check.toggled.connect(_on_use_colors_toggled)
	_show_source_check.toggled.connect(_on_show_source_toggled)
	_buffer_size_spin.value_changed.connect(_on_buffer_size_changed)
	_enable_buffer_dump_check.toggled.connect(_on_enable_buffer_dump_toggled)
	_show_editor_debug_check.toggled.connect(_on_show_editor_debug_toggled)
	_save_button.pressed.connect(_on_save_settings)
	_reset_button.pressed.connect(_on_reset_settings)
	_update_tags_button.pressed.connect(_on_scan_tags)

	_load_settings_from_config()


func _load_settings_from_config() -> void:
	_show_timestamp = _config.get_show_timestamp()
	_show_timestamp_check.button_pressed = _show_timestamp

	_show_tags = _config.get_show_tags()
	_show_tags_check.button_pressed = _show_tags

	_use_colors = _config.get_use_colors()
	_use_colors_check.button_pressed = _use_colors

	_show_source = _config.get_show_source()
	_show_source_check.button_pressed = _show_source

	_buffer_size = _config.get_buffer_size()
	_buffer_size_spin.value = _buffer_size

	_enable_buffer_dump = _config.get_enable_buffer_dump()
	_enable_buffer_dump_check.button_pressed = _enable_buffer_dump

	_show_editor_debug = _config.get_show_editor_debug()
	_show_editor_debug_check.button_pressed = _show_editor_debug

	_show_debug = _show_editor_debug


func _on_scan_tags() -> void:
	if _show_debug:
		print_rich("[color=#%s]Scanning project for Log tags...[/color]" % LoggerColors.INFO_HTML)

	var exclude_dirs: Array[String] = []
	var include_test_tags = ProjectSettings.get_setting("advanced_logger/include_test_tags", false)

	if not include_test_tags:
		exclude_dirs.append("res://tests/")
		if _show_editor_debug:
			print_rich("[color=#%s]Excluding test tags[/color]" % LoggerColors.INFO_HTML)
	elif _show_editor_debug:
		print_rich("[color=#%s]Including test tags[/color]" % LoggerColors.INFO_HTML)

	var added_count = _tag_list_controller.scan_tags(exclude_dirs)

	if _show_debug:
		print_rich(
			(
				"[color=#%s]Tag scan complete. Added %d new tags.[/color]"
				% [LoggerColors.SUCCESS_HTML, added_count]
			)
		)

	if _show_editor_debug:
		_test_platform_logging()

	tags_scanned.emit(added_count)

	_parent_dock.call("_update_startup_message")


func _save_settings_to_config() -> Error:
	_config.set_show_timestamp(_show_timestamp)
	_config.set_show_tags(_show_tags)
	_config.set_use_colors(_use_colors)
	_config.set_show_source(_show_source)

	_config.set_buffer_size(_buffer_size)
	_config.set_enable_buffer_dump(_enable_buffer_dump)

	_config.set_show_editor_debug(_show_editor_debug)

	var result: int = _config.save()

	if result == OK:
		print_rich(
			"[color=#%s]Logger settings saved successfully[/color]" % LoggerColors.SUCCESS_HTML
		)
	else:
		push_error("Failed to save settings: %s" % error_string(result))

	return result


func _apply_defaults() -> void:
	_show_timestamp = ConfigManager.DEFAULT_SHOW_TIMESTAMP
	_show_tags = ConfigManager.DEFAULT_SHOW_TAGS
	_use_colors = ConfigManager.DEFAULT_USE_COLORS
	_show_source = ConfigManager.DEFAULT_SHOW_SOURCE
	_buffer_size = ConfigManager.DEFAULT_BUFFER_SIZE
	_enable_buffer_dump = ConfigManager.DEFAULT_ENABLE_BUFFER_DUMP
	_show_editor_debug = ConfigManager.DEFAULT_SHOW_EDITOR_DEBUG

	_show_timestamp_check.button_pressed = _show_timestamp
	_show_tags_check.button_pressed = _show_tags
	_use_colors_check.button_pressed = _use_colors
	_show_source_check.button_pressed = _show_source
	_buffer_size_spin.value = _buffer_size
	_enable_buffer_dump_check.button_pressed = _enable_buffer_dump
	_show_editor_debug_check.button_pressed = _show_editor_debug

	var tag_lists = _tag_list_controller.get_tag_lists()
	tag_lists.available_tags.clear()
	tag_lists.active_tags.clear()
	tag_lists.ignored_tags.clear()
	_tag_list_controller.refresh_tag_lists()

	_save_settings_to_config()
	_tag_list_controller.save_tags_to_config()


func _test_platform_logging() -> void:
	print_rich("\n[color=#%s]=== TESTING PLATFORM LOGGING ===[/color]" % LoggerColors.INFO_HTML)

	var platform_test = load("res://addons/advanced_logger/utils/platform_test.gd")
	if platform_test:
		platform_test.run_all_tests()
		print_rich("[color=#%s]Platform tests completed[/color]" % LoggerColors.SUCCESS_HTML)
	else:
		print_rich("[color=#%s]Platform test module not found[/color]" % LoggerColors.ERROR_HTML)

	var ios_test = load("res://addons/advanced_logger/utils/ios_test.gd")
	if ios_test:
		ios_test.run_tests()
		print_rich("[color=#%s]iOS formatting tests completed[/color]" % LoggerColors.SUCCESS_HTML)
	else:
		print_rich("[color=#%s]iOS test module not found[/color]" % LoggerColors.ERROR_HTML)

	var current_platform = OS.get_name()

	print_rich("[color=#%s]Current platform: %s[/color]" % [LoggerColors.INFO_HTML, current_platform])
	print_rich("[color=#%s]Testing platform-specific logging...[/color]" % LoggerColors.INFO_HTML)

	var ios_helper = null
	var android_helper = null

	if FileAccess.file_exists("res://addons/advanced_logger/utils/ios_logger_helper.gd"):
		ios_helper = load("res://addons/advanced_logger/utils/ios_logger_helper.gd")
		print_rich("[color=#%s]iOS helper loaded[/color]" % LoggerColors.SUCCESS_HTML)

	if FileAccess.file_exists("res://addons/advanced_logger/utils/android_logger_helper.gd"):
		android_helper = load("res://addons/advanced_logger/utils/android_logger_helper.gd")
		print_rich("[color=#%s]Android helper loaded[/color]" % LoggerColors.SUCCESS_HTML)

	print("\n--- Testing logger with simple text ---")
	Log.debug("Platform Logger Test - Debug Message", {"platform": current_platform}, ["test", "platform"])
	Log.info("Platform Logger Test - Info Message", {"platform": current_platform}, ["test", "platform"])
	Log.warning("Platform Logger Test - Warning Message", {"platform": current_platform}, ["test", "platform"])
	Log.error("Platform Logger Test - Error Message", {"platform": current_platform}, ["test", "platform"])

	print_rich("[color=#%s]=== PLATFORM LOGGING TEST COMPLETE ===[/color]\n" % LoggerColors.INFO_HTML)



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


func _on_buffer_size_changed(value: float) -> void:
	_buffer_size = int(value)

	if _show_editor_debug:
		print_rich(
			(
				"[color=#%s]DEBUG: Buffer size changed to %d[/color]"
				% [LoggerColors.DEBUG_HTML, _buffer_size]
			)
		)

	_config.set_buffer_size(_buffer_size)
	var save_result = _config.save()

	if _show_editor_debug:
		if save_result == OK:
			print_rich(
				(
					"[color=#%s]DEBUG: Buffer size saved successfully[/color]"
					% [LoggerColors.DEBUG_HTML]
				)
			)
		else:
			print_rich(
				(
					"[color=#%s]DEBUG: Failed to save buffer size: %s[/color]"
					% [LoggerColors.ERROR_HTML, error_string(save_result)]
				)
			)


func _on_enable_buffer_dump_toggled(button_pressed: bool) -> void:
	_enable_buffer_dump = button_pressed
	_config.set_enable_buffer_dump(button_pressed)
	_config.save()


func _on_show_editor_debug_toggled(button_pressed: bool) -> void:
	_show_editor_debug = button_pressed
	_show_debug = button_pressed  # Update local reference
	_config.set_show_editor_debug(button_pressed)
	_config.save()


func _on_save_settings() -> void:
	if _show_debug:
		print_rich("[color=#%s]Attempting to save settings...[/color]" % LoggerColors.INFO_HTML)

	var result := _save_settings_to_config()

	if result == OK:
		if _show_debug:
			print_rich("[color=#%s]Settings saved successfully[/color]" % LoggerColors.SUCCESS_HTML)
		settings_saved.emit()
	else:
		if _show_debug:
			print_rich(
				(
					"[color=#%s]Failed to save settings: %s[/color]"
					% [LoggerColors.ERROR_HTML, error_string(result)]
				)
			)


func _on_reset_settings() -> void:
	_apply_defaults()
	if _show_debug:
		print_rich("[color=#%s]Logger settings reset to defaults[/color]" % LoggerColors.INFO_HTML)
	settings_reset.emit()

	_parent_dock.call("_update_startup_message")
