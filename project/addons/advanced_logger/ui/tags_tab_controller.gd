@tool
class_name TagsTabController
extends RefCounted

signal tag_setup_saved(setup_name: String, active_tags: Array[String], ignored_tags: Array[String])
signal tag_setup_requested()

var _level_option: OptionButton
var _available_tags_list: ItemList
var _tags_list: ItemList
var _ignored_tags_list: ItemList
var _setups_list: ItemList
var _save_setup_button: Button

var _config: ConfigManager
var _tag_list_controller: TagListController
var _setup_list_controller: SetupListController
var _parent_dock: Control

var _current_level: int = 1  # INFO level

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

	_setup_list_controller.setup_loaded.connect(_on_setup_loaded)
	_setup_list_controller.setup_renamed.connect(_on_setup_renamed)

func setup(
	level_option: OptionButton,
	available_tags_list: ItemList,
	tags_list: ItemList,
	ignored_tags_list: ItemList,
	setups_list: ItemList,
	save_setup_button: Button
) -> void:
	_level_option = level_option
	_available_tags_list = available_tags_list
	_tags_list = tags_list
	_ignored_tags_list = ignored_tags_list
	_setups_list = setups_list
	_save_setup_button = save_setup_button

	_level_option.item_selected.connect(_on_level_changed)
	_save_setup_button.pressed.connect(_on_save_setup_button_pressed)

	_tag_list_controller.setup(_available_tags_list, _tags_list, _ignored_tags_list)

	_setup_list_controller.setup(_setups_list)

	_load_level_from_config()


func _load_level_from_config() -> void:
	_current_level = _config.get_log_level()
	if _level_option:
		_level_option.select(_current_level)

func get_tag_lists() -> Dictionary:
	return _tag_list_controller.get_tag_lists()

func check_for_initial_scan() -> void:
	var tag_lists = _tag_list_controller.get_tag_lists()
	if tag_lists.available_tags.size() <= 1: # Accounting for possible example tag
		_scan_tags()

func _scan_tags() -> int:
	print_rich("[color=#%s]Scanning project for Log tags...[/color]" % LoggerColors.INFO_HTML)

	var exclude_dirs: Array[String] = []
	var include_test_tags = ProjectSettings.get_setting("advanced_logger/include_test_tags", false)

	if not include_test_tags:
		exclude_dirs.append("res://tests/")
		print_rich("[color=#%s]Excluding test tags[/color]" % LoggerColors.INFO_HTML)
	else:
		print_rich("[color=#%s]Including test tags[/color]" % LoggerColors.INFO_HTML)

	var added_count = _tag_list_controller.scan_tags(exclude_dirs)

	print_rich("[color=#%s]Tag scan complete. Added %d new tags.[/color]" %
		[LoggerColors.SUCCESS_HTML, added_count])

	return added_count


func _on_level_changed(index: int) -> void:
	_current_level = index
	_config.set_log_level(index)

	_config.save()

	if _config.get_show_editor_debug():
		print_rich("[color=#%s]Log level changed to %s[/color]" %
			[LoggerColors.INFO_HTML, ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"][index]])

func _on_tag_moved(tag: String, from_category: String, to_category: String) -> void:
	print_rich(
		"[color=#%s]Moved tag '%s' from %s to %s[/color]"
		% [LoggerColors.SUCCESS_HTML, tag, from_category, to_category]
	)
	_parent_dock.call("_update_startup_message")

func _on_setup_loaded(setup_name: String, active_tags: Array, ignored_tags: Array) -> void:
	if _config.get_show_editor_debug():
		print_rich("[color=#%s]Loading tag setup: %s[/color]" %
			[LoggerColors.INFO_HTML, setup_name])

	if _config.get_show_editor_debug():
		print_rich("[color=#%s]DEBUG: Loading active tags: %s[/color]" %
			[LoggerColors.DEBUG_HTML, active_tags])
		print_rich("[color=#%s]DEBUG: Loading ignored tags: %s[/color]" %
			[LoggerColors.DEBUG_HTML, ignored_tags])

	var active_tags_array: Array[String] = []
	for tag in active_tags:
		if tag is String:
			active_tags_array.append(tag)

	var ignored_tags_array: Array[String] = []
	for tag in ignored_tags:
		if tag is String:
			ignored_tags_array.append(tag)

	if _config.get_show_editor_debug():
		print_rich("[color=#%s]DEBUG: Converted active tags: %s[/color]" %
			[LoggerColors.DEBUG_HTML, active_tags_array])
		print_rich("[color=#%s]DEBUG: Converted ignored tags: %s[/color]" %
			[LoggerColors.DEBUG_HTML, ignored_tags_array])

	_config.set_active_tags(active_tags_array)
	_config.set_ignored_tags(ignored_tags_array)

	var save_result = _config.save()
	if _config.get_show_editor_debug():
		print_rich("[color=#%s]DEBUG: Config save result: %s[/color]" %
			[LoggerColors.DEBUG_HTML, "OK" if save_result == OK else error_string(save_result)])

	_tag_list_controller.set_active_tags(active_tags_array)
	_tag_list_controller.set_ignored_tags(ignored_tags_array)

	_tag_list_controller.refresh_tag_lists()

	var saved_active = _config.get_active_tags()
	var saved_ignored = _config.get_ignored_tags()

	if _config.get_show_editor_debug():
		print_rich("[color=#%s]DEBUG: Saved active tags: %s[/color]" %
			[LoggerColors.DEBUG_HTML, saved_active])
		print_rich("[color=#%s]DEBUG: Saved ignored tags: %s[/color]" %
			[LoggerColors.DEBUG_HTML, saved_ignored])

	if _config.get_show_editor_debug():
		print_rich("[color=#%s]Loaded tag setup: %s[/color]" %
			[LoggerColors.SUCCESS_HTML, setup_name])

	_parent_dock.call("_update_startup_message")

func _on_setup_renamed(old_name: String, new_name: String) -> void:
	if new_name.is_empty():
		_parent_dock.call("_show_rename_dialog", old_name)
	else:
		print_rich("[color=#%s]Renamed tag setup: %s → %s[/color]" %
			[LoggerColors.SUCCESS_HTML, old_name, new_name])

func _on_save_setup_button_pressed() -> void:
	tag_setup_requested.emit()
