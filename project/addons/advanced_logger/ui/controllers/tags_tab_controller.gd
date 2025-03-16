@tool
class_name TagsTabController
extends RefCounted
## Controller for managing the Tags tab UI
##
## Handles tag list management, drag and drop operations, and
## tag setup functionality for the Advanced Logger dock.

# Signals
signal tag_moved(tag: String, from_category: String, to_category: String)
signal tag_setup_saved(setup_name: String)
signal tag_setup_loaded(setup_name: String)
signal tag_setup_renamed(old_name: String, new_name: String)

# Dependencies
var _config: ConfigManager
var _tag_list_controller: TagListController
var _setup_list_controller: SetupListController
var _drag_drop_helper: DragDropHelper

# UI Components
var _level_option: OptionButton
var _available_tags_list: ItemList
var _tags_list: ItemList
var _ignored_tags_list: ItemList
var _setups_list: ItemList
var _save_setup_button: Button
var _setup_name_dialog: ConfirmationDialog
var _setup_name_input: LineEdit

# Tag level
var _current_level: int = 1  # INFO level

# Initialize the controller
func _init(config: ConfigManager) -> void:
	_config = config
	
# Setup UI components and connect signals
func setup(
	level_option: OptionButton,
	available_tags_list: ItemList,
	tags_list: ItemList,
	ignored_tags_list: ItemList,
	setups_list: ItemList,
	save_setup_button: Button,
	setup_name_dialog: ConfirmationDialog,
	setup_name_input: LineEdit
) -> void:
	# Store UI references
	_level_option = level_option
	_available_tags_list = available_tags_list
	_tags_list = tags_list
	_ignored_tags_list = ignored_tags_list
	_setups_list = setups_list
	_save_setup_button = save_setup_button
	_setup_name_dialog = setup_name_dialog
	_setup_name_input = setup_name_input
	
	# Initialize sub-controllers
	var setup_manager = TagSetupManager.new(_config)
	_drag_drop_helper = DragDropHelper.new(TagManager)
	_tag_list_controller = TagListController.new(TagManager, _config)
	_setup_list_controller = SetupListController.new(setup_manager)
	
	# Setup sub-controllers
	_tag_list_controller.setup(_available_tags_list, _tags_list, _ignored_tags_list)
	_setup_list_controller.setup(_setups_list)
	
	# Connect signals
	_level_option.item_selected.connect(_on_level_changed)
	_save_setup_button.pressed.connect(_on_save_setup_button_pressed)
	_setup_name_dialog.confirmed.connect(_on_setup_name_dialog_confirmed)
	
	# Connect sub-controller signals
	_tag_list_controller.tag_moved.connect(_on_tag_moved)
	_setup_list_controller.setup_loaded.connect(_on_setup_loaded)
	_setup_list_controller.setup_renamed.connect(_on_setup_renamed)
	
	# Load data
	_load_from_config()
	_tag_list_controller.load_tags_from_config()
	_setup_list_controller.load_setups()

## Load settings from config
func _load_from_config() -> void:
	_current_level = _config.get_log_level()
	_level_option.select(_current_level)

## Process drag and drop operations
func get_drag_data(at_position: Vector2, source_control: Control) -> Variant:
	# Get global mouse position
	var global_pos = source_control.get_global_mouse_position()

	# Figure out which list we're dragging from
	if _available_tags_list.get_global_rect().has_point(global_pos):
		var drag_data = _drag_drop_helper.get_drag_data_for_list(_available_tags_list, "available")
		if drag_data:
			source_control.set_drag_preview(_drag_drop_helper.create_drag_preview(
				TagManager.format_tag_for_display(drag_data.tag)))
		return drag_data
	elif _tags_list.get_global_rect().has_point(global_pos):
		var drag_data = _drag_drop_helper.get_drag_data_for_list(_tags_list, "active")
		if drag_data:
			source_control.set_drag_preview(_drag_drop_helper.create_drag_preview(
				TagManager.format_tag_for_display(drag_data.tag)))
		return drag_data
	elif _ignored_tags_list.get_global_rect().has_point(global_pos):
		var drag_data = _drag_drop_helper.get_drag_data_for_list(_ignored_tags_list, "ignored")
		if drag_data:
			source_control.set_drag_preview(_drag_drop_helper.create_drag_preview(
				TagManager.format_tag_for_display(drag_data.tag)))
		return drag_data

	return null

## Check if drag data can be dropped
func can_drop_data(at_position: Vector2, data: Variant, target_control: Control) -> bool:
	# Validate the data
	if not data is Dictionary or not data.has("type") or data["type"] != "tag" or not data.has("tag"):
		return false

	var tag = data["tag"]
	var source = data.get("source", "")
	var mouse_pos = target_control.get_global_mouse_position()

	# Get tag lists from the controller
	var tag_lists = _tag_list_controller.get_tag_lists()

	# Determine target list type
	var target_type = ""
	if _available_tags_list.get_global_rect().has_point(mouse_pos):
		target_type = "available"
	elif _tags_list.get_global_rect().has_point(mouse_pos):
		target_type = "active"
	elif _ignored_tags_list.get_global_rect().has_point(mouse_pos):
		target_type = "ignored"
	else:
		return false

	return _drag_drop_helper.can_drop_tag(tag, source, target_type,
		tag_lists.active_tags, tag_lists.ignored_tags)

## Handle dropped data
func drop_data(at_position: Vector2, data: Variant, target_control: Control) -> void:
	# Validate the data
	if not data is Dictionary or not data.has("type") or data["type"] != "tag" or not data.has("tag"):
		return

	var tag = data["tag"]
	var source = data.get("source", "")
	var mouse_pos = target_control.get_global_mouse_position()

	# Determine target list type
	var target_type = ""
	var target_list = null

	if _available_tags_list.get_global_rect().has_point(mouse_pos):
		target_type = "available"
		target_list = _available_tags_list
	elif _tags_list.get_global_rect().has_point(mouse_pos):
		target_type = "active"
		target_list = _tags_list
	elif _ignored_tags_list.get_global_rect().has_point(mouse_pos):
		target_type = "ignored"
		target_list = _ignored_tags_list
	else:
		return

	# Visual feedback
	if target_list:
		target_list.add_theme_color_override("font_selected_color", Color.GREEN)
		await target_control.get_tree().create_timer(0.2).timeout
		target_list.add_theme_color_override("font_selected_color", Color.WHITE)

	# Use the tag list controller to handle the move
	_tag_list_controller.move_tag(tag, source, target_type)

## Get the current tag lists
func get_tag_lists() -> Dictionary:
	return _tag_list_controller.get_tag_lists()
	
## Scan for tags in the project
func scan_tags(exclude_dirs: Array[String] = []) -> int:
	return _tag_list_controller.scan_tags(exclude_dirs)

## Handler for tag movement
func _on_tag_moved(tag: String, from_category: String, to_category: String) -> void:
	print_rich(
		"[color=#%s]Moved tag '%s' from %s to %s[/color]"
		% [LoggerColors.SUCCESS_HTML, tag, from_category, to_category]
	)
	tag_moved.emit(tag, from_category, to_category)

## Log level change handler
func _on_level_changed(index: int) -> void:
	_current_level = index
	_config.set_log_level(index)

	# Save the configuration immediately so the change takes effect
	_config.save()

	print_rich("[color=#%s]Log level changed to %s[/color]" %
		[LoggerColors.INFO_HTML, ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"][index]])

## Setup dialog handlers

## Shows the setup name dialog
func _on_save_setup_button_pressed() -> void:
	_setup_name_input.text = ""
	_setup_name_dialog.title = "Save Tag Setup"
	_setup_name_dialog.dialog_text = "Enter a name for this tag setup:"
	_setup_name_dialog.popup_centered()
	_setup_name_input.grab_focus()

## Handles the confirmation of the setup name dialog
func _on_setup_name_dialog_confirmed() -> void:
	var setup_name = _setup_name_input.text.strip_edges()
	if setup_name.is_empty():
		push_warning("Setup name cannot be empty")
		return

	# Get current tags
	var tag_lists = _tag_list_controller.get_tag_lists()

	# Save the setup
	var result = _setup_list_controller.save_setup(
		setup_name,
		tag_lists.active_tags,
		tag_lists.ignored_tags
	)

	if result != OK:
		push_error("Failed to save tag setup: %s" % error_string(result))
	else:
		tag_setup_saved.emit(setup_name)

## Shows the rename dialog
func show_rename_dialog(old_name: String) -> void:
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
			var result = _setup_list_controller.rename_setup(old_name, new_name)
			if result != OK:
				push_error("Failed to rename setup: %s" % error_string(result))
			else:
				tag_setup_renamed.emit(old_name, new_name)

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
	
	tag_setup_loaded.emit(setup_name)

## Handler for setup renamed
func _on_setup_renamed(old_name: String, new_name: String) -> void:
	# Show the rename dialog if name is empty (signal from context menu)
	if new_name.is_empty():
		show_rename_dialog(old_name)
	else:
		print_rich("[color=#%s]Renamed tag setup: %s → %s[/color]" %
			[LoggerColors.SUCCESS_HTML, old_name, new_name])
		tag_setup_renamed.emit(old_name, new_name)
