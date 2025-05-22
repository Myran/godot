# project/debug/debug_menu_controller.gd (script for scene_debug.tscn root)

extends Control

# UI References (ensure these paths match your scene_debug.tscn)
@onready var status_label: RichTextLabel = %DebugRichTextLabel
@onready var item_list_navigator: ItemList = %DebugItemList
@onready var run_all_button: Button = %RunAllButton  # Add this button to your scene if not already present

# Navigation State & Constants (similar to original)
enum ViewLevel { MAIN_CATEGORIES, GROUP_LIST, TEST_LIST }
var _current_view_level: ViewLevel = ViewLevel.MAIN_CATEGORIES
var _current_category_name: String = ""
var _current_group_name: String = ""

# Constants for metadata
const ITEM_TYPE_CATEGORY: String = "category_item"
const ITEM_TYPE_GROUP: String = "group_item"
const ITEM_TYPE_ACTION: String = "action_item"  # Was TEST_ITEM
const ITEM_TYPE_BACK_TO_MAIN: String = "back_to_main"
const ITEM_TYPE_BACK_TO_GROUPS: String = "back_to_groups"

const BACK_TO_MAIN_MENU_TEXT: String = "< Back to Main Menu"
const BACK_TO_GROUPS_TEXT: String = "< Back to Categories"  # Or "Back to Test Groups"

var _is_executing_all: bool = false


func _ready() -> void:
	Log.info("DebugMenuController ready.", {}, ["debug", "ui", "initialization"])

	if (
		not is_instance_valid(item_list_navigator)
		or not is_instance_valid(status_label)
		or not is_instance_valid(run_all_button)
	):
		Log.error(
			"Required UI elements not found in scene_debug.tscn!", {}, ["debug", "ui", "error"]
		)
		return

	item_list_navigator.set_deferred("editable", false)
	run_all_button.disabled = true

	item_list_navigator.item_selected.connect(_on_navigator_item_selected)
	run_all_button.pressed.connect(_on_run_all_pressed)

	DebugManager.debug_event.connect(_on_global_debug_event)

	_populate_main_categories_view()
	%Panel.gui_input.connect(_on_panel_gui_input)


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_released():
		_on_button_close_pressed()


func _update_status_label_text(text: String, is_error: bool = false) -> void:
	if is_instance_valid(status_label):
		var header_text: String = (
			"OS: %s | Build: %s\nCommit: %s\n\n"
			% [
				OS.get_name(),
				"Debug" if OS.is_debug_build() else "Release",
				Engine.get_version_info()["hash"]
			]
		)
		var color_tag = "[color=red]" if is_error else "[color=palegreen]"  # Use Godot's named colors
		status_label.text = header_text + color_tag + text + "[/color]"


func _populate_main_categories_view() -> void:
	_current_view_level = ViewLevel.MAIN_CATEGORIES
	_current_category_name = ""
	_current_group_name = ""
	item_list_navigator.clear()

	if is_instance_valid(run_all_button):
		run_all_button.visible = false

	Log.debug("Populating main categories view", {}, ["debug_ui"])

	# Try to access the registry in different ways
	var registry = DebugRegistry

	# Get categories with a try/except to catch any runtime errors
	var categories = []

	# Try to get categories safely
	categories = registry.get_categories()
	if categories.is_empty():
		item_list_navigator.add_item("No debug actions registered.")
		item_list_navigator.set_item_disabled(0, true)
		return

	for i in range(categories.size()):
		var category_name = categories[i]
		item_list_navigator.add_item(category_name)
		item_list_navigator.set_item_metadata(
			i, {"type": ITEM_TYPE_CATEGORY, "name": category_name}
		)


func _populate_groups_view(category_name: String) -> void:
	_current_view_level = ViewLevel.GROUP_LIST
	_current_category_name = category_name
	_current_group_name = ""
	item_list_navigator.clear()

	if is_instance_valid(run_all_button):
		run_all_button.text = "Run All in '%s'" % category_name
		run_all_button.visible = true

	Log.debug("Populating groups for category: " + category_name, {}, ["debug_ui"])

	item_list_navigator.add_item(BACK_TO_MAIN_MENU_TEXT)
	item_list_navigator.set_item_metadata(0, {"type": ITEM_TYPE_BACK_TO_MAIN})

	# Try to access the registry in different ways
	var registry = null

	# Try via node path (more reliable in Godot 4)
	if has_node("/root/DebugRegistry"):
		registry = get_node("/root/DebugRegistry")
	# Try via Engine singleton as fallback
	elif Engine.has_singleton("DebugRegistry"):
		registry = Engine.get_singleton("DebugRegistry")

	if not registry:
		_update_status_label_text(
			"ERROR: DebugActionRegistry not found while accessing category groups.", true
		)
		return

	var groups = registry.get_groups_for_category(category_name)
	if groups.is_empty():
		item_list_navigator.add_item("No groups in this category.")
		item_list_navigator.set_item_disabled(1, true)
		return

	for i in range(groups.size()):
		var group_name = groups[i]
		item_list_navigator.add_item(group_name)
		item_list_navigator.set_item_metadata(i + 1, {"type": ITEM_TYPE_GROUP, "name": group_name})


func _populate_actions_view(category_name: String, group_name: String) -> void:
	_current_view_level = ViewLevel.TEST_LIST
	_current_category_name = category_name
	_current_group_name = group_name
	item_list_navigator.clear()

	if is_instance_valid(run_all_button):
		run_all_button.text = "Run All in Group '%s'" % group_name
		run_all_button.visible = true

	Log.debug(
		"Populating actions for group: %s -> %s" % [category_name, group_name], {}, ["debug_ui"]
	)

	item_list_navigator.add_item(BACK_TO_GROUPS_TEXT)
	item_list_navigator.set_item_metadata(0, {"type": ITEM_TYPE_BACK_TO_GROUPS})

	# Try to access the registry in different ways
	var registry = null

	# Try via node path (more reliable in Godot 4)
	if has_node("/root/DebugRegistry"):
		registry = get_node("/root/DebugRegistry")
	# Try via Engine singleton as fallback
	elif Engine.has_singleton("DebugRegistry"):
		registry = Engine.get_singleton("DebugRegistry")

	if not registry:
		_update_status_label_text(
			"ERROR: DebugActionRegistry not found while accessing group actions.", true
		)
		return

	var actions_in_group = registry.get_actions_for_group(category_name, group_name)
	if actions_in_group.is_empty():
		item_list_navigator.add_item("No actions in this group.")
		item_list_navigator.set_item_disabled(1, true)
		return

	for i in range(actions_in_group.size()):
		var action: DebugAction = actions_in_group[i]
		item_list_navigator.add_item(action.action_name)
		item_list_navigator.set_item_tooltip(i + 1, action.description)
		item_list_navigator.set_item_metadata(
			i + 1, {"type": ITEM_TYPE_ACTION, "action_instance": action}
		)


func _on_navigator_item_selected(index: int) -> void:
	if _is_executing_all:
		Log.warning(
			"Attempted item selection while 'Run All' is active. Ignored.", {}, ["debug_ui"]
		)
		return
	if index < 0 or index >= item_list_navigator.item_count:
		return

	var metadata = item_list_navigator.get_item_metadata(index)
	if not metadata is Dictionary:
		return

	var item_type = metadata.get("type")
	match item_type:
		ITEM_TYPE_CATEGORY:
			_populate_groups_view(metadata.get("name"))
		ITEM_TYPE_GROUP:
			_populate_actions_view(_current_category_name, metadata.get("name"))
		ITEM_TYPE_ACTION:
			var action: DebugAction = metadata.get("action_instance")
			if action:
				_execute_single_action(action)
		ITEM_TYPE_BACK_TO_MAIN:
			_populate_main_categories_view()
		ITEM_TYPE_BACK_TO_GROUPS:
			_populate_groups_view(_current_category_name)


func _on_run_all_pressed() -> void:
	if _is_executing_all:
		Log.warning("Run All already in progress.", {}, ["debug_ui"])
		return

	# Try to access the registry in different ways
	var registry = null

	# Try via node path (more reliable in Godot 4)
	if has_node("/root/DebugRegistry"):
		registry = get_node("/root/DebugRegistry")
	# Try via Engine singleton as fallback
	elif Engine.has_singleton("DebugRegistry"):
		registry = Engine.get_singleton("DebugRegistry")

	if not registry:
		_update_status_label_text(
			"ERROR: DebugActionRegistry not found while running group actions.", true
		)
		return

	var actions_to_run: Array[DebugAction]
	var scope_name: String
	if _current_view_level == ViewLevel.GROUP_LIST:  # Run all in category
		scope_name = _current_category_name
		for group_name in registry.get_groups_for_category(_current_category_name):
			actions_to_run.append_array(
				registry.get_actions_for_group(_current_category_name, group_name)
			)

	elif _current_view_level == ViewLevel.TEST_LIST:  # Run all in group
		scope_name = "%s / %s" % [_current_category_name, _current_group_name]
		actions_to_run = registry.get_actions_for_group(_current_category_name, _current_group_name)

	else:
		Log.warning("Run All pressed in an unsupported view level.", {}, ["debug_ui"])
		return

	if actions_to_run.is_empty():
		_update_status_label_text("No actions to run in '%s'." % scope_name)
		return

	_execute_multiple_actions(actions_to_run, "All in '%s'" % scope_name)


func _execute_single_action(action: DebugAction) -> void:
	if _is_executing_all:
		return  # Prevent single execution during "Run All"

	_is_executing_all = true  # Use the same flag to disable UI temporarily
	_set_ui_for_execution(true)
	_update_status_label_text("Executing: %s..." % action.action_name)
	Log.info("Executing single action: %s" % action.action_name, {}, ["debug", "test"])

	var result: Array = await action.execute(self)  # Pass self for status updates
	var success: bool = result[0]
	var payload = result[1]

	if success:
		_update_status_label_text("PASS: %s\nResult: %s" % [action.action_name, str(payload)])
	else:
		_update_status_label_text("FAIL: %s\nError: %s" % [action.action_name, str(payload)], true)

	_set_ui_for_execution(false)
	_is_executing_all = false


func _execute_multiple_actions(
	actions_to_run: Array[DebugAction], scope_description: String
) -> void:
	_is_executing_all = true
	_set_ui_for_execution(true)
	_update_status_label_text(
		"Running %s actions for: %s" % [actions_to_run.size(), scope_description]
	)
	Log.info(
		(
			"Starting execution of %d actions for scope: %s"
			% [actions_to_run.size(), scope_description]
		),
		{},
		["debug", "test"]
	)

	var passed_count := 0
	var failed_count := 0
	var summary_lines: Array[String] = []

	for i in range(actions_to_run.size()):
		var action: DebugAction = actions_to_run[i]
		_update_status_label_text(
			"Running (%d/%d): %s..." % [i + 1, actions_to_run.size(), action.action_name]
		)
		Log.info(
			"Executing action [%d/%d]: %s" % [i + 1, actions_to_run.size(), action.action_name],
			{},
			["debug", "test"]
		)

		var result: Array = await action.execute(self)
		var success: bool = result[0]
		var payload = result[1]

		if success:
			passed_count += 1
			summary_lines.append(
				(
					"[color=palegreen]PASS: %s[/color] - Result: %s"
					% [action.action_name, str(payload)]
				)
			)
		else:
			failed_count += 1
			summary_lines.append(
				"[color=red]FAIL: %s[/color] - Error: %s" % [action.action_name, str(payload)]
			)

		# Small delay to allow UI to update if many tests run quickly
		if OS.has_feature("web"):  # Browsers might need more aggressive yielding
			await get_tree().process_frame
		else:
			await get_tree().create_timer(0.01).timeout

	var final_summary = (
		"Execution Complete for '%s':\n%d Passed, %d Failed.\n\n"
		% [scope_description, passed_count, failed_count]
	)
	final_summary += "\n".join(summary_lines)
	_update_status_label_text(final_summary, failed_count > 0)
	Log.info(
		final_summary.replace("[color=palegreen]", "").replace("[color=red]", "").replace(
			"[/color]", ""
		),
		{},
		["debug", "test"]
	)

	_set_ui_for_execution(false)
	_is_executing_all = false


func _set_ui_for_execution(is_executing: bool) -> void:
	if is_instance_valid(item_list_navigator):
		item_list_navigator.set_deferred("editable", !is_executing)
	if is_instance_valid(run_all_button):
		run_all_button.disabled = is_executing


func _on_button_close_pressed() -> void:
	DebugManager.action(DebugManager.DebugEventType.EVENT_CLOSE_DEBUG_MENU)


# Handle global debug events if needed
func _on_global_debug_event(event_type: DebugManager.DebugEventType, args: Array = []) -> void:
	if event_type == DebugManager.DebugEventType.EVENT_OPEN_DEBUG_MENU:
		show()
		Log.debug("Debug menu opened via global event.", {}, ["debug", "ui"])
	elif event_type == DebugManager.DebugEventType.EVENT_CLOSE_DEBUG_MENU:
		hide()
		Log.debug("Debug menu closed via global event.", {}, ["debug", "ui"])


# For showing the menu programmatically
func show_menu_content() -> void:
	show()
	Log.debug("Debug menu shown via direct call.", {}, ["debug", "ui"])
