@tool
class_name LoggerDock extends Control

const TagScanner = preload("res://addons/advanced_logger/utils/tag_scanner.gd")
const TagManager = preload("res://addons/advanced_logger/utils/tag_manager.gd")
const TagCategories = preload("res://addons/advanced_logger/utils/tag_categories.gd")
const ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")
const TagSetupManager = preload("res://addons/advanced_logger/utils/tag_setup_manager.gd")
const DragDropHelper = preload("res://addons/advanced_logger/ui/drag_drop_helper.gd")
const TagListController = preload("res://addons/advanced_logger/ui/tag_list_controller.gd")
const SetupListController = preload("res://addons/advanced_logger/ui/setup_list_controller.gd")
const TagsTabController = preload("res://addons/advanced_logger/ui/tags_tab_controller.gd")
const SettingsTabController = preload("res://addons/advanced_logger/ui/settings_tab_controller.gd")
const SetupDialogController = preload("res://addons/advanced_logger/ui/setup_dialog_controller.gd")

var _config: ConfigManager = null

var _tag_list_controller: TagListController
var _setup_list_controller: SetupListController
var _drag_drop_helper: DragDropHelper
var _tags_tab_controller: TagsTabController
var _settings_tab_controller: SettingsTabController
var _setup_dialog_controller: SetupDialogController

var _show_editor_debug: bool = false

@onready var _startup_message: Label = $VBoxContainer/StartupMessage

@onready var _level_option: OptionButton = $VBoxContainer/TabContainer/Tags/LevelSection/LevelOption
@onready var _available_tags_list: ItemList = $VBoxContainer/TabContainer/Tags/TagsContainer/AvailableTagsSection/ScrollContainer/TagsList
@onready var _tags_list: ItemList = $VBoxContainer/TabContainer/Tags/TagsContainer/TagsSection/ScrollContainer/TagsList
@onready var _ignored_tags_list: ItemList = $VBoxContainer/TabContainer/Tags/TagsContainer/IgnoredTagsSection/ScrollContainer/IgnoredTagsList
@onready var _setups_list: ItemList = $VBoxContainer/TabContainer/Tags/TagsContainer/SetupsSection/ScrollContainer/SetupsList
@onready var _save_setup_button: Button = $VBoxContainer/TabContainer/Tags/TagsContainer/SetupsSection/HBoxContainer/SaveSetupButton
@onready var _setup_name_dialog: ConfirmationDialog = $SetupNameDialog
@onready var _setup_name_input: LineEdit = $SetupNameDialog/VBoxContainer/SetupNameInput
@onready var _update_tags_button: Button = $VBoxContainer/TabContainer/Settings/ButtonsSection/UpdateTagsButton
@onready var _show_timestamp_check: CheckBox = $VBoxContainer/TabContainer/Settings/FormatSection/ShowTimestampCheck
@onready var _show_tags_check: CheckBox = $VBoxContainer/TabContainer/Settings/FormatSection/ShowTagsCheck
@onready var _use_colors_check: CheckBox = $VBoxContainer/TabContainer/Settings/FormatSection/UseColorsCheck
@onready var _show_source_check: CheckBox = $VBoxContainer/TabContainer/Settings/FormatSection/ShowSourceCheck
@onready var _buffer_size_spin: SpinBox = $VBoxContainer/TabContainer/Settings/FormatSection/BufferSizeContainer/BufferSizeSpinBox
@onready var _enable_buffer_dump_check: CheckBox = $VBoxContainer/TabContainer/Settings/FormatSection/EnableBufferDumpCheck
@onready var _show_editor_debug_check: CheckBox = $VBoxContainer/TabContainer/Settings/FormatSection/ShowEditorDebugCheck
@onready var _save_button: Button = $VBoxContainer/TabContainer/Settings/ButtonsSection/SaveButton
@onready var _reset_button: Button = $VBoxContainer/TabContainer/Settings/ButtonsSection/ResetButton

func _ready() -> void:
	_config = ConfigManager.get_instance()

	_config.config_changed.connect(_on_config_changed)

	_show_editor_debug = _config.get_show_editor_debug()

	if OS.is_debug_build() and _show_editor_debug:
		print_rich("[color=#%s]DEBUG: LoggerDock _ready called[/color]" % [LoggerColors.DEBUG_HTML])

	_initialize_controllers()

	_update_startup_message()

	call_deferred("_initial_tag_scan")

func _initialize_controllers() -> void:
	var setup_manager = TagSetupManager.new(_config)
	_drag_drop_helper = DragDropHelper.new(TagManager)
	_tag_list_controller = TagListController.new(TagManager, _config)
	_setup_list_controller = SetupListController.new(setup_manager)

	_tag_list_controller.tag_moved.connect(_on_tag_moved)

	call_deferred("_configure_item_lists_for_drag_drop")

	call_deferred("_connect_drag_drop_signals")

	_setup_dialog_controller = SetupDialogController.new(
		_config,
		_tag_list_controller,
		_setup_list_controller
	)
	_setup_dialog_controller.setup(
		_setup_name_dialog,
		_setup_name_input
	)
	_setup_dialog_controller.setup_saved.connect(_on_setup_saved)
	_setup_dialog_controller.setup_renamed.connect(_on_setup_renamed)

	_tags_tab_controller = TagsTabController.new(
		_config,
		_tag_list_controller,
		_setup_list_controller,
		self
	)
	_tags_tab_controller.setup(
		_level_option,
		_available_tags_list,
		_tags_list,
		_ignored_tags_list,
		_setups_list,
		_save_setup_button
	)
	_tags_tab_controller.tag_setup_requested.connect(_on_tag_setup_requested)

	_settings_tab_controller = SettingsTabController.new(
		_config,
		_tag_list_controller,
		self
	)
	_settings_tab_controller.setup(
		_show_timestamp_check,
		_show_tags_check,
		_use_colors_check,
		_show_source_check,
		_buffer_size_spin,
		_enable_buffer_dump_check,
		_show_editor_debug_check,
		_save_button,
		_reset_button,
		_update_tags_button
	)
	_settings_tab_controller.settings_saved.connect(_on_settings_saved)
	_settings_tab_controller.settings_reset.connect(_on_settings_reset)
	_settings_tab_controller.tags_scanned.connect(_on_tags_scanned)

func _get_drag_data(at_position: Vector2) -> Variant:
	var available_pos = _available_tags_list.get_global_transform().affine_inverse() * get_global_transform() * at_position
	var active_pos = _tags_list.get_global_transform().affine_inverse() * get_global_transform() * at_position
	var ignored_pos = _ignored_tags_list.get_global_transform().affine_inverse() * get_global_transform() * at_position

	if _available_tags_list.is_visible_in_tree() and Rect2(Vector2.ZERO, _available_tags_list.size).has_point(available_pos):
		var drag_data = _drag_drop_helper.get_drag_data_for_list(_available_tags_list, TagCategories.category_to_string(TagCategories.Category.AVAILABLE))
		if drag_data:
			if OS.is_debug_build() and _show_editor_debug:
				print_rich("[color=#%s]DEBUG: Dragging tag from available: %s[/color]" %
					[LoggerColors.DEBUG_HTML, drag_data.tag])
			set_drag_preview(_drag_drop_helper.create_drag_preview(
				TagManager.format_tag_for_display(drag_data.tag)))
		return drag_data

	if _tags_list.is_visible_in_tree() and Rect2(Vector2.ZERO, _tags_list.size).has_point(active_pos):
		var drag_data = _drag_drop_helper.get_drag_data_for_list(_tags_list, TagCategories.category_to_string(TagCategories.Category.ACTIVE))
		if drag_data:
			if OS.is_debug_build() and _show_editor_debug:
				print_rich("[color=#%s]DEBUG: Dragging tag from active: %s[/color]" %
					[LoggerColors.DEBUG_HTML, drag_data.tag])
			set_drag_preview(_drag_drop_helper.create_drag_preview(
				TagManager.format_tag_for_display(drag_data.tag)))
		return drag_data

	if _ignored_tags_list.is_visible_in_tree() and Rect2(Vector2.ZERO, _ignored_tags_list.size).has_point(ignored_pos):
		var drag_data = _drag_drop_helper.get_drag_data_for_list(_ignored_tags_list, TagCategories.category_to_string(TagCategories.Category.IGNORED))
		if drag_data:
			if OS.is_debug_build() and _show_editor_debug:
				print_rich("[color=#%s]DEBUG: Dragging tag from ignored: %s[/color]" %
					[LoggerColors.DEBUG_HTML, drag_data.tag])
			set_drag_preview(_drag_drop_helper.create_drag_preview(
				TagManager.format_tag_for_display(drag_data.tag)))
		return drag_data

	return null

func _configure_item_lists_for_drag_drop() -> void:
	for list in [_available_tags_list, _tags_list, _ignored_tags_list]:
		if list:
			list.mouse_filter = Control.MOUSE_FILTER_PASS
			list.focus_mode = Control.FOCUS_ALL
			list.select_mode = ItemList.SELECT_SINGLE

			if OS.is_debug_build() and _show_editor_debug:
				print_rich("[color=#%s]DEBUG: Configured drag-drop for %s[/color]" % [LoggerColors.DEBUG_HTML, list.name])

func _connect_drag_drop_signals() -> void:
	if OS.is_debug_build() and _show_editor_debug:
		print_rich("[color=#%s]DEBUG: Using Control's built-in drag-drop handling[/color]" % [LoggerColors.DEBUG_HTML])

func _get_target_category_at_position(at_position: Vector2) -> int:
	var global_pos: Vector2 = get_global_transform() * at_position

	if _available_tags_list.is_visible_in_tree() and _available_tags_list.get_global_rect().has_point(global_pos):
		if OS.is_debug_build() and _show_editor_debug:
			print_rich("[color=#%s]DEBUG: Target identified as AVAILABLE[/color]" % [LoggerColors.DEBUG_HTML])
		return TagCategories.Category.AVAILABLE

	if _tags_list.is_visible_in_tree() and _tags_list.get_global_rect().has_point(global_pos):
		if OS.is_debug_build() and _show_editor_debug:
			print_rich("[color=#%s]DEBUG: Target identified as ACTIVE[/color]" % [LoggerColors.DEBUG_HTML])
		return TagCategories.Category.ACTIVE

	if _ignored_tags_list.is_visible_in_tree() and _ignored_tags_list.get_global_rect().has_point(global_pos):
		if OS.is_debug_build() and _show_editor_debug:
			print_rich("[color=#%s]DEBUG: Target identified as IGNORED[/color]" % [LoggerColors.DEBUG_HTML])
		return TagCategories.Category.IGNORED

	if OS.is_debug_build() and _show_editor_debug:
		print_rich("[color=#%s]DEBUG: No valid target list found at position[/color]" % [LoggerColors.WARNING_HTML])
	return -1 # No valid target list found

func _get_list_for_category(category: int) -> ItemList:
	match category:
		TagCategories.Category.AVAILABLE: return _available_tags_list
		TagCategories.Category.ACTIVE: return _tags_list
		TagCategories.Category.IGNORED: return _ignored_tags_list
	return null

func _on_config_changed(section: String, key: String, value: Variant) -> void:
	if section == ConfigManager.SECTION_LOGGER and (
		key == ConfigManager.KEY_ACTIVE_TAGS or
		key == ConfigManager.KEY_IGNORED_TAGS or
		key == ConfigManager.KEY_AVAILABLE_TAGS
	):
		_update_startup_message()

	if section == ConfigManager.SECTION_SETUPS:
		_setup_list_controller.refresh_setups_list()

	if section == ConfigManager.SECTION_FORMAT and key == ConfigManager.KEY_SHOW_EDITOR_DEBUG:
		_show_editor_debug = value

func _update_startup_message() -> void:
	var active_tags = _config.get_active_tags()
	var ignored_tags = _config.get_ignored_tags()

	var message: String = ""

	if _show_editor_debug:
		if active_tags.size() > 0:
			message += "Active filter tags: " + ", ".join(active_tags)
		else:
			message += "No active filter tags (showing all logs except ignored)"

		if ignored_tags.size() > 0:
			message += "\nIgnored tags: " + ", ".join(ignored_tags)
		else:
			message += "\nNo ignored tags"

		print_rich("[color=#%s]Advanced Logger Tags:[/color]" % LoggerColors.INFO_HTML)
		print_rich("[color=#%s]%s[/color]" % [LoggerColors.INFO_HTML, message])
	else:
		message = "Logger initialized. Enable 'Show Editor Debug' in Settings tab for detailed logging tests."

	_startup_message.text = message

	_update_level_tag_tooltips()

func _update_level_tag_tooltips() -> void:
	_update_tooltip_for_tag_list(_available_tags_list)
	_update_tooltip_for_tag_list(_tags_list)
	_update_tooltip_for_tag_list(_ignored_tags_list)

func _update_tooltip_for_tag_list(list: ItemList) -> void:
	if not list:
		return

	for i in range(list.get_item_count()):
		var tag = list.get_item_metadata(i)
		if tag is String and tag.begins_with("level:"):
			var tooltip = "Level Tag: Overrides the log level dropdown when active.\n"
			match tag:
				"level:debug":
					tooltip += "Shows DEBUG level messages."
				"level:info":
					tooltip += "Shows INFO level messages."
				"level:warning":
					tooltip += "Shows WARNING level messages."
				"level:error":
					tooltip += "Shows ERROR level messages."
				"level:critical":
					tooltip += "Shows CRITICAL level messages."
			list.set_item_tooltip(i, tooltip)

func _initial_tag_scan() -> void:
	var tag_lists = _tag_list_controller.get_tag_lists()
	if tag_lists.available_tags.size() <= 1: # Accounting for possible example tag
		_on_scan_tags()

func _show_rename_dialog(old_name: String) -> void:
	_setup_dialog_controller.show_rename_dialog(old_name)


func _on_tag_setup_requested() -> void:
	_setup_dialog_controller.show_save_dialog()

func _on_tag_moved(_tag: String, _from_category: int, _to_category: int) -> void:
	_update_startup_message()

func _on_setup_loaded(setup_name: String, active_tags: Array, ignored_tags: Array) -> void:
	_tags_tab_controller._on_setup_loaded(setup_name, active_tags, ignored_tags)
	_update_startup_message()

func _on_setup_saved(_setup_name: String) -> void:
	_update_startup_message()

func _on_setup_renamed(old_name: String, new_name: String) -> void:
	if new_name.is_empty():
		_show_rename_dialog(old_name)
	else:
		_update_startup_message()

func _on_scan_tags() -> void:
	_settings_tab_controller._on_scan_tags()

func _on_tags_scanned(_added_count: int) -> void:
	_update_startup_message()

func _on_settings_saved() -> void:
	_update_startup_message()

func _on_settings_reset() -> void:
	_update_startup_message()

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("type") or data["type"] != "tag" or not data.has("tag"):
		if OS.is_debug_build() and _show_editor_debug:
			print_rich("[color=#%s]DEBUG: Invalid drag data for drop validation[/color]" % [LoggerColors.DEBUG_HTML])
		return false

	var tag = data["tag"]
	var source = data.get("source", "")

	var target_category = _get_target_category_at_position(at_position)

	if OS.is_debug_build() and _show_editor_debug:
		print_rich("[color=#%s]DEBUG: Can drop check - Tag: %s, Source: %s, Target: %s[/color]" % [
			LoggerColors.DEBUG_HTML,
			tag,
			source,
			TagCategories.category_to_string(target_category) if target_category >= 0 else "INVALID"
		])

	if target_category < 0:
		return false

	var tag_lists = _tag_list_controller.get_tag_lists()

	var source_category = TagCategories.from_string(source)
	var can_drop = _drag_drop_helper.can_drop_tag(
		tag,
		source_category,
		target_category,
		tag_lists.active_tags,
		tag_lists.ignored_tags
	)

	if OS.is_debug_build() and _show_editor_debug:
		print_rich("[color=#%s]DEBUG: Can drop result: %s[/color]" % [LoggerColors.DEBUG_HTML, can_drop])

	return can_drop

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary or not data.has("type") or data["type"] != "tag" or not data.has("tag"):
		if OS.is_debug_build() and _show_editor_debug:
			print_rich("[color=#%s]DEBUG: Invalid drag data for drop[/color]" % [LoggerColors.ERROR_HTML])
		return

	var tag = data["tag"]
	var source = data.get("source", "")

	var target_category = _get_target_category_at_position(at_position)

	if OS.is_debug_build() and _show_editor_debug:
		print_rich("[color=#%s]DEBUG: Drop data - Tag: %s, Source: %s, Target: %s[/color]" % [
			LoggerColors.DEBUG_HTML,
			tag,
			source,
			TagCategories.category_to_string(target_category) if target_category >= 0 else "INVALID"
		])

	if target_category < 0:
		return

	var target_list = _get_list_for_category(target_category)

	if target_list:
		target_list.add_theme_color_override("font_selected_color", Color.GREEN)
		await get_tree().create_timer(0.2).timeout
		target_list.add_theme_color_override("font_selected_color", Color.WHITE)

	var source_category = TagCategories.from_string(source)

	if OS.is_debug_build() and _show_editor_debug:
		print_rich("[color=#%s]DEBUG: Moving tag '%s' from %s to %s[/color]" % [
			LoggerColors.INFO_HTML,
			tag,
			TagCategories.category_to_string(source_category),
			TagCategories.category_to_string(target_category)
		])

	_tag_list_controller.move_tag(tag, source_category, target_category)
