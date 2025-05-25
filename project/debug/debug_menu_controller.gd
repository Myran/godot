# project/debug/debug_menu_controller.gd (script for scene_debug.tscn root)

extends Control

# Preload service class for manual actions (SOLID: Dependency Inversion)
const ManualActionDataService = preload("res://debug/manual_action_data_service.gd")

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
const ITEM_TYPE_CATEGORY_WITH_ACTIONS: String = "category_with_actions"  # Category that has direct actions

const BACK_TO_MAIN_MENU_TEXT: String = "< Back to Main Menu"
const BACK_TO_GROUPS_TEXT: String = "< Back to Categories"  # Or "Back to Test Groups"

var _is_executing_all: bool = false

# Service for manual action data management (DRY + SOLID principles)
var _manual_action_service: ManualActionDataService


func _ready() -> void:
	Log.info("DebugMenuController ready.", {}, ["debug", "ui", "initialization"])

	# Initialize the manual action service (SOLID: Dependency Injection)
	_manual_action_service = ManualActionDataService.new()

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

	# Log service status for debugging
	var debug_summary: Dictionary = _manual_action_service.get_debug_summary()
	Log.debug("Manual action service initialized", debug_summary, ["debug_ui", "manual_actions"])


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
		var color_tag: String = "[color=red]" if is_error else "[color=palegreen]"  # Use Godot's named colors
		status_label.text = header_text + color_tag + text + "[/color]"


func _populate_main_categories_view() -> void:
	_current_view_level = ViewLevel.MAIN_CATEGORIES
	_current_category_name = ""
	_current_group_name = ""
	item_list_navigator.clear()

	if is_instance_valid(run_all_button):
		run_all_button.visible = false

	Log.debug("Populating main categories view", {}, ["debug_ui"])

	# Validate state before population
	if not _validate_navigation_state("_populate_main_categories_view"):
		return

	# Get categories from debug registry
	var categories: Array[String] = []
	if DebugRegistry:
		categories = DebugRegistry.get_categories()
	else:
		Log.error("DebugRegistry autoload not found", {}, ["debug_ui", "error"])
		return

	# Add manual action categories using service (DRY principle)
	var manual_categories: Array[String] = _manual_action_service.get_categories()
	for cat_name in manual_categories:
		if not categories.has(cat_name):
			categories.append(cat_name)

	if categories.is_empty():
		item_list_navigator.add_item("No debug actions registered.")
		item_list_navigator.set_item_disabled(0, true)
		return

	# Populate category items
	for i: int in range(categories.size()):
		var category_name: String = categories[i]
		_add_category_item_to_list(category_name, i)

	Log.info(
		"Main categories populated",
		{"total_categories": categories.size(), "manual_categories": manual_categories.size()},
		["debug_ui"]
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

	# Validate state
	if not _validate_navigation_state("_populate_groups_view"):
		_update_status_label_text("ERROR: Invalid navigation state.", true)
		return

	# Validate category exists in either DebugRegistry or Manual Actions
	var category_exists: bool = false

	# Check if category exists in DebugRegistry
	if DebugRegistry:
		var debug_categories: Array[String] = DebugRegistry.get_categories()
		if debug_categories.has(category_name):
			category_exists = true

	# Check if category exists in Manual Actions (if not found in DebugRegistry)
	if not category_exists:
		category_exists = _manual_action_service.validate_category(category_name)

	if not category_exists:
		_update_status_label_text(
			"ERROR: Category '%s' not found in debug system." % category_name, true
		)
		Log.error("Category validation failed", {"category": category_name}, ["debug_ui", "error"])
		return

	item_list_navigator.add_item(BACK_TO_MAIN_MENU_TEXT)
	item_list_navigator.set_item_metadata(0, {"type": ITEM_TYPE_BACK_TO_MAIN})

	# **CRITICAL FIX: Check if category has ungrouped actions - if so, use category_with_actions view**
	var has_ungrouped: bool = _manual_action_service.has_ungrouped_actions(category_name)

	if has_ungrouped:
		Log.debug(
			"Category has ungrouped actions, redirecting to category_with_actions view",
			{"category": category_name},
			["debug_ui", "navigation"]
		)
		# Clear the back button we just added and delegate to the proper view
		item_list_navigator.clear()
		_populate_category_with_actions_view(category_name)
		return

	# Get groups from debug registry
	var groups: Array[String] = []
	if DebugRegistry:
		groups = DebugRegistry.get_groups_for_category(category_name)
	else:
		Log.error("DebugRegistry autoload not found", {}, ["debug_ui", "error"])
		return

	# Add manual action groups using service (DRY principle)
	var manual_groups: Array[String] = _manual_action_service.get_groups_for_category(category_name)
	for group_name in manual_groups:
		if not groups.has(group_name):
			groups.append(group_name)

	if groups.is_empty():
		item_list_navigator.add_item("No groups in this category.")
		item_list_navigator.set_item_disabled(1, true)
		return

	# Populate group items
	for i: int in range(groups.size()):
		var group_name: String = groups[i]
		item_list_navigator.add_item(group_name)
		item_list_navigator.set_item_metadata(i + 1, {"type": ITEM_TYPE_GROUP, "name": group_name})

	Log.info(
		"Groups populated for category",
		{
			"category": category_name,
			"total_groups": groups.size(),
			"debug_groups": groups.size() - manual_groups.size(),
			"manual_groups": manual_groups.size()
		},
		["debug_ui"]
	)


func _populate_category_with_actions_view(category_name: String) -> void:
	"""Show a category that has both direct actions and groups"""
	_current_view_level = ViewLevel.GROUP_LIST
	_current_category_name = category_name
	_current_group_name = ""
	item_list_navigator.clear()

	if is_instance_valid(run_all_button):
		run_all_button.text = "Run All in '%s'" % category_name
		run_all_button.visible = true

	Log.debug("Populating category with direct actions: " + category_name, {}, ["debug_ui"])

	# Validate state
	if not _validate_navigation_state("_populate_category_with_actions_view"):
		return

	# Note: Category validation for this method is implicit since it's only called
	# for categories with verified ungrouped actions

	item_list_navigator.add_item(BACK_TO_MAIN_MENU_TEXT)
	item_list_navigator.set_item_metadata(0, {"type": ITEM_TYPE_BACK_TO_MAIN})

	var item_index: int = 1

	# Get ungrouped actions using service (DRY principle)
	var ungrouped_actions: Array[ManualDebugAction] = _manual_action_service.get_ungrouped_actions(
		category_name
	)

	if ungrouped_actions.size() > 0:
		# Add ungrouped actions directly
		for action in ungrouped_actions:
			item_list_navigator.add_item("• " + action.action_name)  # Bullet to show it's an action
			item_list_navigator.set_item_tooltip(item_index, action.description)
			item_list_navigator.set_item_metadata(
				item_index, {"type": ITEM_TYPE_ACTION, "action_instance": action, "is_manual": true}
			)
			item_index += 1

		# Check if we have groups to add separator
		var debug_groups: Array[String] = []
		var manual_groups: Array[String] = []

		if DebugRegistry:
			debug_groups = DebugRegistry.get_groups_for_category(category_name)

		manual_groups = _manual_action_service.get_groups_for_category(category_name)

		var has_groups: bool = debug_groups.size() > 0 or manual_groups.size() > 0

		if has_groups:
			item_list_navigator.add_item("─── Groups ───")
			item_list_navigator.set_item_disabled(item_index, true)
			item_index += 1

	# Add groups using service (DRY principle)
	var all_groups: Array[String] = []

	# Get debug registry groups
	if DebugRegistry:
		all_groups = DebugRegistry.get_groups_for_category(category_name)

	# Add manual groups
	var manual_groups: Array[String] = _manual_action_service.get_groups_for_category(category_name)
	for group_name in manual_groups:
		if not all_groups.has(group_name):
			all_groups.append(group_name)

	# Populate group items
	for group_name in all_groups:
		item_list_navigator.add_item("▸ " + group_name)  # Arrow to show it's expandable
		item_list_navigator.set_item_metadata(
			item_index, {"type": ITEM_TYPE_GROUP, "name": group_name}
		)
		item_index += 1

	Log.info(
		"Category with actions populated",
		{
			"category": category_name,
			"ungrouped_actions": ungrouped_actions.size(),
			"total_groups": all_groups.size(),
			"manual_groups": manual_groups.size()
		},
		["debug_ui"]
	)


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

	# Access the registry via autoload (fast-failing)
	if not DebugRegistry:
		_update_status_label_text(
			"ERROR: DebugRegistry autoload not found while accessing group actions.", true
		)
		return
	var registry = DebugRegistry

	var actions_in_group: Array[DebugAction] = registry.get_actions_for_group(
		category_name, group_name
	)

	# Get manual actions for this group using service (DRY principle)
	var manual_actions_to_add: Array = _manual_action_service.get_actions_for_group(
		category_name, group_name
	)

	if actions_in_group.is_empty() and manual_actions_to_add.is_empty():
		item_list_navigator.add_item("No actions in this group.")
		item_list_navigator.set_item_disabled(1, true)
		return

	# Add regular debug actions
	var item_index: int = 1
	for i: int in range(actions_in_group.size()):
		var action: DebugAction = actions_in_group[i]
		item_list_navigator.add_item(action.action_name)
		item_list_navigator.set_item_tooltip(item_index, action.description)
		item_list_navigator.set_item_metadata(
			item_index, {"type": ITEM_TYPE_ACTION, "action_instance": action}
		)
		item_index += 1

	# Add manual actions with a separator if we have both types
	if actions_in_group.size() > 0 and manual_actions_to_add.size() > 0:
		item_list_navigator.add_item("--- Manual Actions ---")
		item_list_navigator.set_item_disabled(item_index, true)
		item_index += 1

	# Add manual actions
	for manual_action in manual_actions_to_add:
		item_list_navigator.add_item(manual_action.action_name)
		item_list_navigator.set_item_tooltip(item_index, manual_action.description)
		item_list_navigator.set_item_metadata(
			item_index,
			{"type": ITEM_TYPE_ACTION, "action_instance": manual_action, "is_manual": true}
		)
		item_index += 1


func _on_navigator_item_selected(index: int) -> void:
	if _is_executing_all:
		Log.warning(
			"Attempted item selection while 'Run All' is active. Ignored.", {}, ["debug_ui"]
		)
		return
	if index < 0 or index >= item_list_navigator.item_count:
		return

	var metadata: Variant = item_list_navigator.get_item_metadata(index)
	if not metadata is Dictionary:
		return

	var item_type: Variant = metadata.get("type")
	match item_type:
		ITEM_TYPE_CATEGORY:
			_populate_groups_view(metadata.get("name"))
		ITEM_TYPE_CATEGORY_WITH_ACTIONS:
			_populate_category_with_actions_view(metadata.get("name"))
		ITEM_TYPE_GROUP:
			_populate_actions_view(_current_category_name, metadata.get("name"))
		ITEM_TYPE_ACTION:
			var action = metadata.get("action_instance")
			var is_manual: bool = metadata.get("is_manual", false)
			if action:
				if is_manual:
					_execute_manual_action(action)
				else:
					_execute_single_action(action)
		ITEM_TYPE_BACK_TO_MAIN:
			_populate_main_categories_view()
		ITEM_TYPE_BACK_TO_GROUPS:
			_populate_groups_view(_current_category_name)


func _on_run_all_pressed() -> void:
	if _is_executing_all:
		Log.warning("Run All already in progress.", {}, ["debug_ui"])
		return

	# Access the registry via autoload (fast-failing)
	if not DebugRegistry:
		_update_status_label_text(
			"ERROR: DebugRegistry autoload not found while running group actions.", true
		)
		return
	var registry = DebugRegistry

	var actions_to_run: Array = []  # Can contain both DebugAction and ManualDebugAction
	var scope_name: String = ""

	if _current_view_level == ViewLevel.GROUP_LIST:  # Run all in category
		scope_name = _current_category_name
		for group_name in registry.get_groups_for_category(_current_category_name):
			var debug_actions = registry.get_actions_for_group(_current_category_name, group_name)
			for action in debug_actions:
				actions_to_run.append({"action": action, "is_manual": false})

		# Add manual actions for this category using service (DRY principle)
		var all_manual_actions: Dictionary = _manual_action_service.get_all_actions_for_category(
			_current_category_name
		)

		# Add grouped manual actions
		for group_name in all_manual_actions.grouped:
			for manual_action in all_manual_actions.grouped[group_name]:
				actions_to_run.append({"action": manual_action, "is_manual": true})

		# Add ungrouped manual actions
		for manual_action in all_manual_actions.ungrouped:
			actions_to_run.append({"action": manual_action, "is_manual": true})

	elif _current_view_level == ViewLevel.TEST_LIST:  # Run all in group
		scope_name = "%s / %s" % [_current_category_name, _current_group_name]
		var debug_actions = registry.get_actions_for_group(
			_current_category_name, _current_group_name
		)
		for action in debug_actions:
			actions_to_run.append({"action": action, "is_manual": false})

		# Add manual actions for this group using service (DRY principle)
		var group_manual_actions: Array = _manual_action_service.get_actions_for_group(
			_current_category_name, _current_group_name
		)
		for manual_action in group_manual_actions:
			actions_to_run.append({"action": manual_action, "is_manual": true})

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

	# Connect to action's status signal
	if action.status_updated.is_connected(_on_action_status_updated):
		action.status_updated.disconnect(_on_action_status_updated)
	action.status_updated.connect(_on_action_status_updated)

	var result: Array = await action.execute()  # No target_node parameter
	var success: bool = result[0]
	var payload: Variant = result[1]

	# Disconnect after execution
	action.status_updated.disconnect(_on_action_status_updated)

	if success:
		_update_status_label_text("PASS: %s\nResult: %s" % [action.action_name, str(payload)])
	else:
		_update_status_label_text("FAIL: %s\nError: %s" % [action.action_name, str(payload)], true)

	_set_ui_for_execution(false)
	_is_executing_all = false


# Handler for action status updates
func _on_action_status_updated(text: String, is_error: bool) -> void:
	_update_status_label_text(text, is_error)


func _execute_manual_action(action: ManualDebugAction) -> void:
	if _is_executing_all:
		return  # Prevent single execution during "Run All"

	_is_executing_all = true  # Use the same flag to disable UI temporarily
	_set_ui_for_execution(true)
	_update_status_label_text("Executing Manual: %s..." % action.action_name)
	Log.info("Executing manual action: %s" % action.action_name, {}, ["debug", "manual"])

	# Manual actions don't return success/fail, they just execute
	action.execute()

	# Show completion message
	_update_status_label_text("Completed: %s\n%s" % [action.action_name, action.description])

	_set_ui_for_execution(false)
	_is_executing_all = false


func _execute_multiple_actions(actions_to_run: Array, scope_description: String) -> void:
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
		var action_data: Dictionary = actions_to_run[i]
		var action = action_data.action
		var is_manual: bool = action_data.is_manual
		var action_name: String = action.action_name

		_update_status_label_text(
			"Running (%d/%d): %s..." % [i + 1, actions_to_run.size(), action_name]
		)
		Log.info(
			"Executing action [%d/%d]: %s" % [i + 1, actions_to_run.size(), action_name],
			{},
			["debug", "test"]
		)

		if is_manual:
			# Manual actions don't return success/fail
			action.execute()
			passed_count += 1
			summary_lines.append(
				"[color=palegreen]EXEC: %s[/color] - %s" % [action_name, "Manual action completed"]
			)
		else:
			# Regular debug actions - connect to signals
			if action.status_updated.is_connected(_on_action_status_updated):
				action.status_updated.disconnect(_on_action_status_updated)
			action.status_updated.connect(_on_action_status_updated)

			var result: Array = await action.execute()
			var success: bool = result[0]
			var payload = result[1]

			# Disconnect after execution
			action.status_updated.disconnect(_on_action_status_updated)

			if success:
				passed_count += 1
				summary_lines.append(
					"[color=palegreen]PASS: %s[/color] - Result: %s" % [action_name, str(payload)]
				)
			else:
				failed_count += 1
				summary_lines.append(
					"[color=red]FAIL: %s[/color] - Error: %s" % [action_name, str(payload)]
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
func _on_global_debug_event(event_type: DebugManager.DebugEventType, _args: Array = []) -> void:
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


# SOLID Principle: Single Responsibility - Helper methods for specific tasks


## Validate navigation state before population (prevents errors)
func _validate_navigation_state(caller_method: String) -> bool:
	if not _manual_action_service:
		Log.error(
			"Manual action service not initialized",
			{"caller": caller_method},
			["debug_ui", "error"]
		)
		return false

	if not DebugRegistry:
		Log.error(
			"DebugRegistry autoload not found", {"caller": caller_method}, ["debug_ui", "error"]
		)
		return false

	return true


## Add a category item to the list with proper metadata (DRY principle)
func _add_category_item_to_list(category_name: String, index: int) -> void:
	# Check if this category has ungrouped actions
	var has_direct_actions: bool = _manual_action_service.has_ungrouped_actions(category_name)

	# Add visual indicator for categories with direct actions
	var display_name: String = category_name
	if has_direct_actions:
		display_name = category_name + " ►"  # Arrow indicates expandable

	item_list_navigator.add_item(display_name)

	# Use different metadata type for categories with direct actions
	if has_direct_actions:
		item_list_navigator.set_item_metadata(
			index, {"type": ITEM_TYPE_CATEGORY_WITH_ACTIONS, "name": category_name}
		)
	else:
		item_list_navigator.set_item_metadata(
			index, {"type": ITEM_TYPE_CATEGORY, "name": category_name}
		)

	Log.debug(
		"Added category item",
		{"category": category_name, "has_direct_actions": has_direct_actions, "index": index},
		["debug_ui"]
	)
