@tool
class_name LoggerDock extends Control
## Editor dock for configuring the Advanced Logger settings
##
## Coordinates controllers that manage different aspects of the logger UI.
## Acts as a facade for the more specialized controller classes.

# Preload required dependencies
const TagScanner = preload("res://addons/advanced_logger/utils/tag_scanner.gd")
const TagManager = preload("res://addons/advanced_logger/utils/tag_manager.gd")
const ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")
const TagSetupManager = preload("res://addons/advanced_logger/utils/tag_setup_manager.gd")
const DragDropHelper = preload("res://addons/advanced_logger/ui/drag_drop_helper.gd")
const TagListController = preload("res://addons/advanced_logger/ui/tag_list_controller.gd")
const SetupListController = preload("res://addons/advanced_logger/ui/setup_list_controller.gd")
const TagsTabController = preload("res://addons/advanced_logger/ui/tags_tab_controller.gd")
const SettingsTabController = preload("res://addons/advanced_logger/ui/settings_tab_controller.gd")
const SetupDialogController = preload("res://addons/advanced_logger/ui/setup_dialog_controller.gd")

# Manager instances
var _config: ConfigManager = null

# Controller instances
var _tag_list_controller: TagListController
var _setup_list_controller: SetupListController
var _drag_drop_helper: DragDropHelper
var _tags_tab_controller: TagsTabController
var _settings_tab_controller: SettingsTabController
var _setup_dialog_controller: SetupDialogController

# UI Components
@onready var _startup_message: Label = $VBoxContainer/StartupMessage

# UI reference shortcuts
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
@onready var _save_button: Button = $VBoxContainer/TabContainer/Settings/ButtonsSection/SaveButton
@onready var _reset_button: Button = $VBoxContainer/TabContainer/Settings/ButtonsSection/ResetButton

func _ready() -> void:
	print_rich("[color=#%s]DEBUG: LoggerDock _ready called[/color]" % [LoggerColors.DEBUG_HTML])

	# Get config instance
	_config = ConfigManager.get_instance()

	# Register for configuration changes
	_config.config_changed.connect(_on_config_changed)

	# Create and initialize controllers
	_initialize_controllers()

	# Display startup message
	_update_startup_message()

	# Perform initial tag scan if needed
	call_deferred("_initial_tag_scan")

## Initialize all controllers
func _initialize_controllers() -> void:
	# Create base controllers first - but don't set them up yet
	var setup_manager = TagSetupManager.new(_config)
	_drag_drop_helper = DragDropHelper.new(TagManager)
	_tag_list_controller = TagListController.new(TagManager, _config)
	_setup_list_controller = SetupListController.new(setup_manager)

	# Initialize the tag list controller
	# We'll connect this one signal here, but let the tab controllers handle the rest
	_tag_list_controller.tag_moved.connect(_on_tag_moved)

	# Initialize the setup dialog controller
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

	# Initialize tab controllers
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
		_save_button,
		_reset_button,
		_update_tags_button
	)
	_settings_tab_controller.settings_saved.connect(_on_settings_saved)
	_settings_tab_controller.settings_reset.connect(_on_settings_reset)
	_settings_tab_controller.tags_scanned.connect(_on_tags_scanned)

## Override drag and drop methods for Godot 4
func _get_drag_data(at_position: Vector2) -> Variant:
	# Get global mouse position
	var global_pos = get_global_mouse_position()

	# Figure out which list we're dragging from and delegate to the drag drop helper
	if _available_tags_list.get_global_rect().has_point(global_pos):
		var drag_data = _drag_drop_helper.get_drag_data_for_list(_available_tags_list, "available")
		if drag_data:
			# Debug info
			print_rich("[color=#%s]DEBUG: Dragging tag from available: %s[/color]" %
				[LoggerColors.DEBUG_HTML, drag_data.tag])

			set_drag_preview(_drag_drop_helper.create_drag_preview(
				TagManager.format_tag_for_display(drag_data.tag)))
		return drag_data
	elif _tags_list.get_global_rect().has_point(global_pos):
		var drag_data = _drag_drop_helper.get_drag_data_for_list(_tags_list, "active")
		if drag_data:
			set_drag_preview(_drag_drop_helper.create_drag_preview(
				TagManager.format_tag_for_display(drag_data.tag)))
		return drag_data
	elif _ignored_tags_list.get_global_rect().has_point(global_pos):
		var drag_data = _drag_drop_helper.get_drag_data_for_list(_ignored_tags_list, "ignored")
		if drag_data:
			set_drag_preview(_drag_drop_helper.create_drag_preview(
				TagManager.format_tag_for_display(drag_data.tag)))
		return drag_data

	return null

## Can drop data implementation - determines if the drop is valid
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# Validate the data
	if not data is Dictionary or not data.has("type") or data["type"] != "tag" or not data.has("tag"):
		return false

	var tag = data["tag"]
	var source = data.get("source", "")
	var mouse_pos = get_global_mouse_position()

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

## Drop data implementation - handles the drop
func _drop_data(at_position: Vector2, data: Variant) -> void:
	# Validate the data
	if not data is Dictionary or not data.has("type") or data["type"] != "tag" or not data.has("tag"):
		return

	var tag = data["tag"]
	var source = data.get("source", "")
	var mouse_pos = get_global_mouse_position()

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
		await get_tree().create_timer(0.2).timeout
		target_list.add_theme_color_override("font_selected_color", Color.WHITE)

	# Use the tag list controller to handle the move
	_tag_list_controller.move_tag(tag, source, target_type)

## Handles configuration changes - update UI based on changes
func _on_config_changed(section: String, key: String, value: Variant) -> void:
	# Refresh tags if they've changed
	if section == ConfigManager.SECTION_LOGGER and (
		key == ConfigManager.KEY_ACTIVE_TAGS or
		key == ConfigManager.KEY_IGNORED_TAGS or
		key == ConfigManager.KEY_AVAILABLE_TAGS
	):
		_update_startup_message()

	# Refresh setups if they've changed
	if section == ConfigManager.SECTION_SETUPS:
		_setup_list_controller.refresh_setups_list()

## Updates the startup message with current tag status
func _update_startup_message() -> void:
	# Get current tag lists directly from config to ensure we're seeing the saved state
	var active_tags = _config.get_active_tags()
	var ignored_tags = _config.get_ignored_tags()

	# Create message about current active and ignored tags
	var message: String = ""

	if active_tags.size() > 0:
		message += "Active filter tags: " + ", ".join(active_tags)
	else:
		message += "No active filter tags (showing all logs except ignored)"

	if ignored_tags.size() > 0:
		message += "\nIgnored tags: " + ", ".join(ignored_tags)
	else:
		message += "\nNo ignored tags"

	_startup_message.text = message

	# Also print to console for convenience
	print_rich("[color=#%s]Advanced Logger Tags:[/color]" % LoggerColors.INFO_HTML)
	print_rich("[color=#%s]%s[/color]" % [LoggerColors.INFO_HTML, message])

	# Update tooltips for level tags
	_update_level_tag_tooltips()

## Update tooltips for level tag items in lists
func _update_level_tag_tooltips() -> void:
	_update_tooltip_for_tag_list(_available_tags_list)
	_update_tooltip_for_tag_list(_tags_list)
	_update_tooltip_for_tag_list(_ignored_tags_list)

## Helper to update tooltips for a specific list
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

## Performs an initial tag scan when the plugin is loaded
func _initial_tag_scan() -> void:
	# Check if we need to do an initial scan
	var tag_lists = _tag_list_controller.get_tag_lists()
	if tag_lists.available_tags.size() <= 1: # Accounting for possible example tag
		_on_scan_tags()

## Shows the rename dialog
func _show_rename_dialog(old_name: String) -> void:
	# Delegate to the setup dialog controller
	_setup_dialog_controller.show_rename_dialog(old_name)

#
# Signal handlers
#

## Handler for tag setup request
func _on_tag_setup_requested() -> void:
	_setup_dialog_controller.show_save_dialog()

## Handler for tag movement
func _on_tag_moved(tag: String, from_category: String, to_category: String) -> void:
	_update_startup_message()

## Handler for setup loaded
func _on_setup_loaded(setup_name: String, active_tags: Array, ignored_tags: Array) -> void:
	# Let the tags tab controller handle this
	_tags_tab_controller._on_setup_loaded(setup_name, active_tags, ignored_tags)
	_update_startup_message()

## Handler for setup saved
func _on_setup_saved(setup_name: String) -> void:
	_update_startup_message()

## Handler for setup renamed
func _on_setup_renamed(old_name: String, new_name: String) -> void:
	# If new_name is empty, it's a request to show the rename dialog
	if new_name.is_empty():
		_show_rename_dialog(old_name)
	else:
		_update_startup_message()

## Handler for tag scanning
func _on_scan_tags() -> void:
	_settings_tab_controller._on_scan_tags()

## Handler for tags scanned
func _on_tags_scanned(added_count: int) -> void:
	_update_startup_message()

## Handler for settings saved
func _on_settings_saved() -> void:
	_update_startup_message()

## Handler for settings reset
func _on_settings_reset() -> void:
	_update_startup_message()
