# project/debug/debug_menu_controller.gd (script for scene_debug.tscn root)

extends Control
enum ViewLevel { MAIN_CATEGORIES, GROUP_LIST, TEST_LIST }

# Constants for metadata
const ITEM_TYPE_CATEGORY: String = "category_item"
const ITEM_TYPE_GROUP: String = "group_item"
const ITEM_TYPE_ACTION: String = "action_item"  # Was TEST_ITEM
const ITEM_TYPE_BACK_TO_MAIN: String = "back_to_main"
const ITEM_TYPE_BACK_TO_GROUPS: String = "back_to_groups"
const ITEM_TYPE_CATEGORY_WITH_ACTIONS: String = "category_with_actions"  # Category that has direct actions

const BACK_TO_MAIN_MENU_TEXT: String = "< Back to Main Menu"
const BACK_TO_GROUPS_TEXT: String = "< Back to Categories"  # Or "Back to Test Groups"

var _current_view_level: ViewLevel = ViewLevel.MAIN_CATEGORIES
var _current_category_name: String = ""
var _current_group_name: String = ""
var _is_executing_all: bool = false

# Navigation list toggle state
var _last_action_data: Dictionary = {}
var _is_list_hidden: bool = false  # Track if navigation list is hidden
# UI References (ensure these paths match your scene_debug.tscn)
@onready var status_label: RichTextLabel = %DebugRichTextLabel
@onready var item_list_navigator: ItemList = %DebugItemList
@onready var run_all_button: Button = %RunAllButton  # Add this button to your scene if not already present
@onready var text_toggle_button: Button = %TextToggleButton
# Navigation State & Constants (similar to original)


# Removed manual action service - now using unified DebugActionRegistry
class ActionExecutionResult:
	var action: DebugAction
	var is_manual: bool

	func _init(p_action: DebugAction, p_is_manual: bool) -> void:
		action = p_action
		is_manual = p_is_manual


func _ready() -> void:
	Log.info("DebugMenuController ready.", {}, ["debug", "ui", "initialization"])

	if (
		not is_instance_valid(item_list_navigator)
		or not is_instance_valid(status_label)
		or not is_instance_valid(run_all_button)
		or not is_instance_valid(text_toggle_button)
	):
		Log.error(
			"Required UI elements not found in scene_debug.tscn!", {}, ["debug", "ui", "error"]
		)
		return

	item_list_navigator.set_deferred("editable", false)
	run_all_button.disabled = true

	item_list_navigator.item_selected.connect(_on_navigator_item_selected)
	run_all_button.pressed.connect(_on_run_all_pressed)
	text_toggle_button.pressed.connect(_on_text_toggle_button_pressed)

	DebugManager.debug_event.connect(_on_global_debug_event)

	_populate_main_categories_view()
	%Panel.gui_input.connect(_on_panel_gui_input)

	# Initialize toggle button state
	_update_toggle_button_state()


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_released():
		_on_button_close_pressed()


func _on_text_toggle_button_pressed() -> void:
	_toggle_result_expansion()


func _toggle_result_expansion() -> void:
	_is_list_hidden = !_is_list_hidden

	# Toggle navigation list visibility
	if is_instance_valid(item_list_navigator):
		item_list_navigator.visible = !_is_list_hidden

	# Toggle run all button visibility
	if is_instance_valid(run_all_button):
		run_all_button.visible = !_is_list_hidden

	_update_toggle_button_state()


func _update_toggle_button_state() -> void:
	if not is_instance_valid(text_toggle_button):
		return

	# Always show the toggle button
	text_toggle_button.visible = true
	text_toggle_button.disabled = false

	if _is_list_hidden:
		text_toggle_button.text = "▲ Show Navigation"
	else:
		text_toggle_button.text = "▼ Hide Navigation"


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

	# Clear last action data and reset navigation visibility
	_last_action_data.clear()
	_is_list_hidden = false
	if is_instance_valid(item_list_navigator):
		item_list_navigator.visible = true
	if is_instance_valid(run_all_button):
		run_all_button.visible = true
	_update_toggle_button_state()

	if is_instance_valid(run_all_button):
		run_all_button.visible = false

	Log.debug("Populating main categories view", {}, ["debug_ui"])

	# Validate state before population
	if not _validate_navigation_state("_populate_main_categories_view"):
		return

	# Get categories from debug registry (now includes all actions)
	var categories: Array[String] = []
	if DebugRegistry:
		categories = DebugRegistry.get_categories()
		Log.debug(
			"Retrieved categories from DebugRegistry",
			{"categories": categories, "count": categories.size()},
			["debug_ui"]
		)
	else:
		Log.error("DebugRegistry autoload not found", {}, ["debug_ui", "error"])
		return

	if categories.is_empty():
		item_list_navigator.add_item("No debug actions registered.")
		item_list_navigator.set_item_disabled(0, true)
		return

	# Sort categories: direct actions first, then submenus
	var categories_with_direct_actions: Array[String] = []
	var categories_with_only_groups: Array[String] = []

	for category_name: String in categories:
		if DebugRegistry.has_ungrouped_actions(category_name):
			categories_with_direct_actions.append(category_name)
		else:
			categories_with_only_groups.append(category_name)

	# Sort each group alphabetically
	categories_with_direct_actions.sort()
	categories_with_only_groups.sort()

	# Combine: direct actions first, then submenus
	var sorted_categories: Array[String] = (
		categories_with_direct_actions + categories_with_only_groups
	)

	# Populate category items in sorted order
	for i: int in range(sorted_categories.size()):
		var category_name: String = sorted_categories[i]
		_add_category_item_to_list(category_name, i)

	Log.info(
		"Main categories populated",
		{
			"total_categories": sorted_categories.size(),
			"direct_actions": categories_with_direct_actions.size(),
			"submenus": categories_with_only_groups.size()
		},
		["debug_ui"]
	)


func _populate_groups_view(category_name: String) -> void:
	_current_view_level = ViewLevel.GROUP_LIST
	_current_category_name = category_name
	_current_group_name = ""
	item_list_navigator.clear()

	# Clear last action data and reset navigation visibility
	_last_action_data.clear()
	_is_list_hidden = false
	if is_instance_valid(item_list_navigator):
		item_list_navigator.visible = true
	if is_instance_valid(run_all_button):
		run_all_button.visible = true
	_update_toggle_button_state()

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
		var category_found: bool = debug_categories.has(category_name)
		if category_found:
			category_exists = true

	# Category exists check is now sufficient with unified registry

	if not category_exists:
		_update_status_label_text(
			"ERROR: Category '%s' not found in debug system." % category_name, true
		)
		Log.error("Category validation failed", {"category": category_name}, ["debug_ui", "error"])
		return

	item_list_navigator.add_item(BACK_TO_MAIN_MENU_TEXT)
	item_list_navigator.set_item_metadata(0, {"type": ITEM_TYPE_BACK_TO_MAIN})

	# **CRITICAL FIX: Check if category has ungrouped actions - if so, use category_with_actions view**
	var has_ungrouped: bool = DebugRegistry.has_ungrouped_actions(category_name)

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

	# Groups are now all in DebugRegistry

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
		{"category": category_name, "total_groups": groups.size()},
		["debug_ui"]
	)


func _populate_category_with_actions_view(category_name: String) -> void:
	"""Show a category that has both direct actions and groups"""
	_current_view_level = ViewLevel.GROUP_LIST
	_current_category_name = category_name
	_current_group_name = ""
	item_list_navigator.clear()

	# Clear last action data and reset navigation visibility
	_last_action_data.clear()
	_is_list_hidden = false
	if is_instance_valid(item_list_navigator):
		item_list_navigator.visible = true
	if is_instance_valid(run_all_button):
		run_all_button.visible = true
	_update_toggle_button_state()

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

	# Get ungrouped actions from unified registry
	var ungrouped_actions: Array[DebugAction] = DebugRegistry.get_ungrouped_actions(category_name)

	if ungrouped_actions.size() > 0:
		# Add ungrouped actions directly
		for action: DebugAction in ungrouped_actions:
			item_list_navigator.add_item("• " + action.action_name)  # Bullet to show it's an action
			item_list_navigator.set_item_tooltip(item_index, action.description)
			item_list_navigator.set_item_metadata(
				item_index, {"type": ITEM_TYPE_ACTION, "action_instance": action}
			)
			item_index += 1

		# No separator needed - direct actions and groups flow naturally

	# Add groups using service (DRY principle)
	var all_groups: Array[String] = []

	# Get debug registry groups
	if DebugRegistry:
		all_groups = DebugRegistry.get_groups_for_category(category_name)

	# All groups already retrieved from DebugRegistry above

	# Populate group items
	for group_name: String in all_groups:
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
			"total_groups": all_groups.size()
		},
		["debug_ui"]
	)


func _populate_actions_view(category_name: String, group_name: String) -> void:
	_current_view_level = ViewLevel.TEST_LIST
	_current_category_name = category_name
	_current_group_name = group_name
	item_list_navigator.clear()

	# Clear last action data and reset navigation visibility
	_last_action_data.clear()
	_is_list_hidden = false
	if is_instance_valid(item_list_navigator):
		item_list_navigator.visible = true
	if is_instance_valid(run_all_button):
		run_all_button.visible = true
	_update_toggle_button_state()

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
	var registry: DebugActionRegistry = DebugRegistry

	var actions_in_group: Array[DebugAction] = registry.get_actions_for_group(
		category_name, group_name
	)

	# All actions now come from unified registry
	if actions_in_group.is_empty():
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

	# All actions are now handled uniformly through DebugRegistry


func _on_navigator_item_selected(index: int) -> void:
	if _is_executing_all:
		Log.warning(
			"Attempted item selection while 'Run All' is active. Ignored.", {}, ["debug_ui"]
		)
		return
	if index < 0 or index >= item_list_navigator.item_count:
		return

	var metadata: Dictionary = item_list_navigator.get_item_metadata(index)
	var item_type: String = metadata.get("type")
	match item_type:
		ITEM_TYPE_CATEGORY:
			var category_name: String = metadata.get("name")
			_populate_groups_view(category_name)
		ITEM_TYPE_CATEGORY_WITH_ACTIONS:
			var category_name: String = metadata.get("name")
			_populate_category_with_actions_view(category_name)
		ITEM_TYPE_GROUP:
			var group_name: String = metadata.get("name")
			_populate_actions_view(_current_category_name, group_name)
		ITEM_TYPE_ACTION:
			var action: DebugAction = metadata.get("action_instance")
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
	var registry: DebugActionRegistry = DebugRegistry

	var actions_to_run: Array[ActionExecutionResult] = []
	var scope_name: String = ""

	if _current_view_level == ViewLevel.GROUP_LIST:  # Run all in category
		scope_name = _current_category_name
		for group_name: String in registry.get_groups_for_category(_current_category_name):
			var debug_actions: Array[DebugAction] = registry.get_actions_for_group(
				_current_category_name, group_name
			)
			for action: DebugAction in debug_actions:
				var result_item: ActionExecutionResult = ActionExecutionResult.new(action, false)
				actions_to_run.append(result_item)

		# Add ungrouped actions from unified registry
		var ungrouped_actions: Array[DebugAction] = registry.get_ungrouped_actions(
			_current_category_name
		)
		for action: DebugAction in ungrouped_actions:
			var result_item: ActionExecutionResult = ActionExecutionResult.new(action, false)
			actions_to_run.append(result_item)

	elif _current_view_level == ViewLevel.TEST_LIST:  # Run all in group
		scope_name = "%s / %s" % [_current_category_name, _current_group_name]
		var debug_actions: Array[DebugAction] = registry.get_actions_for_group(
			_current_category_name, _current_group_name
		)
		for action: DebugAction in debug_actions:
			var result_item: ActionExecutionResult = ActionExecutionResult.new(action, false)
			actions_to_run.append(result_item)

		# All actions now come from unified registry

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
	@warning_ignore("redundant_await")
	var result: Array = await action.execute()
	var success_variant: Variant = result[0]
	var success: bool = success_variant
	var payload: Variant = result[1]

	# Disconnect after execution
	action.status_updated.disconnect(_on_action_status_updated)

	# Store action data for toggle functionality
	_last_action_data = {"action": action, "success": success, "payload": payload}

	# Always show full detailed report
	var report: String = _build_single_action_report(action, success, payload)
	_update_status_label_text(report, not success)
	_update_toggle_button_state()

	_set_ui_for_execution(false)
	_is_executing_all = false


# Handler for action status updates
func _on_action_status_updated(text: String, is_error: bool) -> void:
	_update_status_label_text(text, is_error)


func _execute_multiple_actions(
	actions_to_run: Array[ActionExecutionResult], scope_description: String
) -> void:
	_is_executing_all = true
	_set_ui_for_execution(true)
	_update_status_label_text(
		(
			"Running %s actions for: %s\n\n[color=gray]Progress will be shown below...[/color]"
			% [actions_to_run.size(), scope_description]
		)
	)
	Log.info(
		(
			"Starting execution of %d actions for scope: %s"
			% [actions_to_run.size(), scope_description]
		),
		{},
		["debug", "test"]
	)

	var passed_count: int = 0
	var failed_count: int = 0
	var failed_actions: Array[Dictionary] = []  # Store more detailed failure info
	var passed_actions: Array[String] = []
	var progress_text: String = ""

	for i: int in range(actions_to_run.size()):
		var action_result: ActionExecutionResult = actions_to_run[i]
		var action: DebugAction = action_result.action
		var action_name: String = action.action_name

		# Show concise progress instead of full details
		progress_text += "[color=yellow]◐[/color] %s..." % action_name
		_update_status_label_text(
			(
				"Running %s actions for: %s\n\n%s"
				% [actions_to_run.size(), scope_description, progress_text]
			)
		)

		Log.info(
			"Executing action [%d/%d]: %s" % [i + 1, actions_to_run.size(), action_name],
			{},
			["debug", "test"]
		)

		# Execute action
		if action.status_updated.is_connected(_on_action_status_updated):
			action.status_updated.disconnect(_on_action_status_updated)
		action.status_updated.connect(_on_action_status_updated)
		@warning_ignore("redundant_await")
		var result: Array = await action.execute()
		var success_variant: Variant = result[0]
		var success: bool = success_variant
		var payload: Variant = result[1]

		# Disconnect after execution
		action.status_updated.disconnect(_on_action_status_updated)

		# Update progress with result
		if success:
			passed_count += 1
			passed_actions.append(action_name)
			# Replace the loading indicator with success
			progress_text = progress_text.replace(
				"[color=yellow]◐[/color] %s..." % action_name,
				"[color=palegreen]✓[/color] %s" % action_name
			)
		else:
			failed_count += 1
			var error_summary: String = _format_error_message(payload)
			failed_actions.append({"name": action_name, "error": error_summary, "payload": payload})  # Keep for detailed logging
			# Replace the loading indicator with failure
			progress_text = progress_text.replace(
				"[color=yellow]◐[/color] %s..." % action_name,
				"[color=red]✗[/color] %s" % action_name
			)

		progress_text += "\n"

		# Small delay to allow UI to update
		if OS.has_feature("web"):
			await get_tree().process_frame
		else:
			await get_tree().create_timer(0.01).timeout

	var final_summary: String = _build_execution_summary(
		scope_description, passed_count, failed_count, passed_actions, failed_actions
	)
	_update_status_label_text(final_summary, failed_count > 0)
	Log.info(
		(
			final_summary
			. replace("[color=palegreen]", "")
			. replace("[color=red]", "")
			. replace("[color=orange]", "")
			. replace("[color=gray]", "")
			. replace("[/color]", "")
		),
		{},
		["debug", "test"]
	)

	_set_ui_for_execution(false)
	_is_executing_all = false


func _set_ui_for_execution(is_executing: bool) -> void:
	if is_instance_valid(item_list_navigator):
		item_list_navigator.set_deferred("editable", !is_executing)
		# Respect the user's collapse preference when restoring after execution
		if not is_executing:
			item_list_navigator.visible = !_is_list_hidden
	if is_instance_valid(run_all_button):
		run_all_button.disabled = is_executing
		# Respect the user's collapse preference when restoring after execution
		if not is_executing:
			run_all_button.visible = !_is_list_hidden

	# Update toggle button state when restoring after execution
	if not is_executing:
		_update_toggle_button_state()


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


## Pretty-print a value with proper formatting and colors
func _pretty_print_value(value: Variant, indent_level: int = 0, max_depth: int = 5) -> String:
	if indent_level > max_depth:
		return "[color=gray]<too deep>[/color]"

	if value == null:
		return "[color=gray]null[/color]"

	if value is Dictionary:
		var val_dic : Dictionary = value
		return _format_dictionary(val_dic, indent_level, max_depth)

	elif value is Array:
		var val_array : Array = value
		return _format_array(val_array, indent_level, max_depth)
	elif value is String:
		var str_val: String = value
		if str_val.length() > 200:
			return '"%s..."' % str_val.substr(0, 197)
		else:
			return '"%s"' % str_val
	elif value is bool:
		return "[color=orange]%s[/color]" % str(value)
	elif value is int or value is float:
		return "[color=cyan]%s[/color]" % str(value)
	else:
		var str_val: String = str(value)
		if str_val.length() > 100:
			return "%s..." % str_val.substr(0, 97)
		else:
			return str_val


## Format dictionary with proper indentation and structure
func _format_dictionary(dict: Dictionary, indent_level: int = 0, max_depth: int = 5) -> String:
	if dict.is_empty():
		return "[color=gray]{ }[/color]"

	if indent_level > max_depth:
		return "[color=gray]{ ... }[/color]"

	var indent: String = "  ".repeat(indent_level)
	var child_indent: String = "  ".repeat(indent_level + 1)
	var result: String = "{\n"

	var keys: Array = dict.keys()
	keys.sort()  # Sort keys for consistent display

	var max_items: int = 25 if indent_level == 0 else 15
	var items_shown: int = 0

	for key: Variant in keys:
		if items_shown >= max_items:
			result += (
				child_indent
				+ "[color=gray]... (%d more items)[/color]\n" % (keys.size() - max_items)
			)
			break

		var value: Variant = dict[key]
		var key_str: String = "[color=yellow]%s[/color]" % str(key)
		var value_str: String = _pretty_print_value(value, indent_level + 1, max_depth)

		# Handle multiline values
		if "\n" in value_str:
			result += (
				child_indent
				+ (
					"%s:\n%s%s\n"
					% [
						key_str,
						"  ".repeat(indent_level + 2),
						value_str.replace("\n", "\n" + "  ".repeat(indent_level + 2))
					]
				)
			)
		else:
			result += child_indent + "%s: %s\n" % [key_str, value_str]

		items_shown += 1

	result += indent + "}"
	return result


## Format array with proper structure and readability
func _format_array(array: Array, indent_level: int = 0, max_depth: int = 5) -> String:
	if array.is_empty():
		return "[color=gray][ ][/color]"

	if indent_level > max_depth:
		return "[color=gray][ ... ][/color]"

	# For small arrays of simple values, show inline
	if array.size() <= 3 and indent_level > 0:
		var all_simple: bool = true
		for item: Variant in array:
			if item is Dictionary or item is Array:
				all_simple = false
				break

		if all_simple:
			var items: Array[String] = []
			for item: Variant in array:
				items.append(_pretty_print_value(item, indent_level + 1, max_depth))
			return "[ %s ]" % ", ".join(items)

	var indent: String = "  ".repeat(indent_level)
	var child_indent: String = "  ".repeat(indent_level + 1)
	var result: String = "[\n"

	var max_items: int = 20 if indent_level == 0 else 10
	var items_shown: int = 0

	for i: int in range(array.size()):
		if items_shown >= max_items:
			result += (
				child_indent
				+ "[color=gray]... (%d more items)[/color]\n" % (array.size() - max_items)
			)
			break

		var item: Variant = array[i]
		var item_str: String = _pretty_print_value(item, indent_level + 1, max_depth)

		# Handle multiline items
		if "\n" in item_str:
			result += (
				child_indent
				+ (
					"[%d]: \n%s%s\n"
					% [
						i,
						"  ".repeat(indent_level + 2),
						item_str.replace("\n", "\n" + "  ".repeat(indent_level + 2))
					]
				)
			)
		else:
			result += child_indent + "[%d]: %s\n" % [i, item_str]

		items_shown += 1

	result += indent + "]"
	return result


## Extract key information from complex payloads for display
func _format_payload_summary(payload: Variant) -> String:
	if payload == null:
		return "No result data"

	# Handle dictionary payloads (common from Firebase actions)
	if payload is Dictionary:
		var dict_payload: Dictionary = payload

		# Firebase operation result
		if dict_payload.has("operation") and dict_payload.has("result"):
			var operation: String = str(dict_payload.get("operation"))
			var result_data: Variant = dict_payload.get("result")
			var path_data: Variant = dict_payload.get("path", "")

			var summary: String = "Operation: %s\n" % operation
			if (
				path_data != null
				and (
					(path_data is Array and path_data.size() > 0)
					or (path_data is String and path_data != "")
				)
			):
				var path_str: String = ""
				if path_data is Array:
					var path_array: Array = path_data
					var string_array: PackedStringArray = PackedStringArray()
					for item: Variant in path_array:
						string_array.append(str(item))
					path_str = "/".join(string_array)  # Convert array to path-like string
				else:
					path_str = str(path_data)
				summary += "Path: %s\n" % path_str

			# Pretty-print result data for better readability
			summary += "Result:\n"
			var formatted_result: String = _pretty_print_value(result_data, 1, 5)
			summary += "  %s" % formatted_result.replace("\n", "\n  ")

			return summary

		# Generic dictionary - use pretty-printing for better readability
		else:
			return "Result:\n  %s" % _pretty_print_value(dict_payload, 1, 5).replace("\n", "\n  ")

	# Handle simple types with pretty-printing
	return "Result: %s" % _pretty_print_value(payload, 0, 5)


## Format error message from payload, extracting meaningful info instead of raw dict
func _format_error_message(payload: Variant) -> String:
	if payload == null:
		return "Unknown error"

	# Handle dictionary errors (common from Firebase)
	if payload is Dictionary:
		var dict_payload: Dictionary = payload

		# Firebase error with structured info
		if dict_payload.has("error"):
			var error_data: Variant = dict_payload.get("error")
			var error_str: String = str(error_data)

			# Extract meaningful error messages
			if error_str.contains("PERMISSION_DENIED"):
				return "Permission denied - check Firebase rules"
			elif error_str.contains("NETWORK_ERROR"):
				return "Network connection issue"
			elif error_str.contains("DATABASE_ERROR"):
				return "Database operation failed"
			elif error_str.contains("timeout") or error_str.contains("TIMEOUT"):
				return "Operation timed out"
			elif error_str.contains("not found") or error_str.contains("NOT_FOUND"):
				return "Resource not found"
			elif error_str.length() > 60:
				return error_str.substr(0, 57) + "..."
			else:
				return error_str

		# Generic dictionary error
		elif dict_payload.size() <= 3:
			return str(dict_payload)
		else:
			return "Complex error (see logs for details)"

	var payload_str: String = str(payload)

	# Try to extract meaningful error info from string patterns
	if payload_str.contains("FirebaseDatabase"):
		return "Firebase connection issue"
	elif payload_str.contains("timeout"):
		return "Operation timed out"
	elif payload_str.contains("permission"):
		return "Permission denied"
	elif payload_str.contains("not found"):
		return "Resource not found"
	elif payload_str.length() > 80:
		# If it's a long string (probably a dict), truncate it
		return payload_str.substr(0, 77) + "..."
	else:
		return payload_str


## Build a professional single action execution report
func _build_single_action_report(action: DebugAction, success: bool, payload: Variant) -> String:
	var report: String = ""

	# Header with action info
	if success:
		report += "[color=palegreen]✅ ACTION COMPLETED[/color]\n"
	else:
		report += "[color=red]❌ ACTION FAILED[/color]\n"

	report += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
	report += "Action: [color=cyan]%s[/color]\n" % action.action_name
	report += "Category: [color=yellow]%s[/color]" % action.category
	if action.group != "":
		report += " / [color=yellow]%s[/color]" % action.group
	report += "\n"

	if action.description != "":
		report += "Description: [color=gray]%s[/color]\n" % action.description

	report += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

	# Results section
	if success:
		report += "[color=palegreen]🎯 RESULT:[/color]\n"
		if payload == null:
			report += "  [color=palegreen]✓ Operation completed successfully[/color]\n"
		else:
			# Use pretty-printing for better result display
			var formatted_result: String = _pretty_print_value(payload, 1, 5)
			report += "  %s\n" % formatted_result.replace("\n", "\n  ")

		report += "\n[color=palegreen]✨ Action executed successfully![/color]\n"
	else:
		report += "[color=red]💥 ERROR DETAILS:[/color]\n"
		var error_msg: String = _format_error_message(payload)
		report += "  [color=red]✗ %s[/color]\n\n" % error_msg

		# Add troubleshooting hints based on error type
		var hint: String = _get_error_hint(error_msg)
		if hint != "":
			report += "[color=orange]💡 TROUBLESHOOTING HINT:[/color]\n"
			report += "  [color=gray]%s[/color]\n" % hint

	return report


## Get troubleshooting hints for common error types
func _get_error_hint(error_msg: String) -> String:
	var error_lower: String = error_msg.to_lower()

	if error_lower.contains("permission") or error_lower.contains("denied"):
		return "Check Firebase security rules or authentication status"
	elif error_lower.contains("network") or error_lower.contains("connection"):
		return "Verify internet connection and Firebase configuration"
	elif error_lower.contains("timeout"):
		return "Try again or check if the service is responding slowly"
	elif error_lower.contains("not found") or error_lower.contains("missing"):
		return "Verify the resource exists and the path is correct"
	elif error_lower.contains("firebase"):
		return "Check Firebase project setup and API keys"
	else:
		return ""


## Build a clean, summarized execution report
func _build_execution_summary(
	scope: String,
	passed: int,
	failed: int,
	passed_actions: Array[String],
	failed_actions: Array[Dictionary]
) -> String:
	var summary: String = ""
	var total: int = passed + failed
	var success_rate: float = (float(passed) / float(total)) * 100.0 if total > 0 else 0.0

	# Header with overall results and success rate
	if failed == 0:
		summary += "[color=palegreen]🎉 ALL ACTIONS PASSED[/color]\n"
	else:
		summary += "[color=orange]⚠️ EXECUTION COMPLETE[/color]\n"

	summary += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
	summary += "Scope: [color=cyan]%s[/color]\n" % scope
	summary += (
		"Success Rate: [color=palegreen]%.1f%%[/color] ([color=palegreen]%d passed[/color], [color=red]%d failed[/color])\n"
		% [success_rate, passed, failed]
	)
	summary += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

	# Show failed actions in detail (high priority)
	if failed > 0:
		summary += "[color=red]🚨 FAILED ACTIONS:[/color]\n"
		for i: int in range(failed_actions.size()):
			var failure: Dictionary = failed_actions[i]
			var action_name: String = failure.get("name", "Unknown")
			var error_msg: String = failure.get("error", "Unknown error")
			summary += "  [color=red]%d.[/color] [color=red]✗ %s[/color]\n" % [i + 1, action_name]
			summary += "     [color=gray]└─ %s[/color]\n" % error_msg
		summary += "\n"

	# Show passed actions summary (lower priority)
	if passed > 0:
		# Always show all passed actions, formatted compactly
		summary += "[color=palegreen]✅ PASSED ACTIONS (%d):[/color]\n" % passed
		var line: String = "  "
		for i: int in range(passed_actions.size()):
			var action_name: String = passed_actions[i]
			var short_name: String = action_name
			if short_name.length() > 20:
				short_name = short_name.substr(0, 17) + "..."

			line += "[color=palegreen]✓[/color] %s" % short_name
			if i < passed_actions.size() - 1:
				line += ", "

			# Break line if getting too long
			if line.length() > 70:
				summary += line + "\n  "
				line = ""

		if line.strip_edges() != "":
			summary += line + "\n"

	# Add quick action hint
	if failed > 0:
		summary += "\n[color=gray]💡 Focus on fixing the failed actions above[/color]\n"
	else:
		summary += "\n[color=palegreen]🎯 All systems working correctly![/color]\n"

	return summary


## Validate navigation state before population (prevents errors)
func _validate_navigation_state(caller_method: String) -> bool:
	if not DebugRegistry:
		Log.error(
			"DebugRegistry autoload not found", {"caller": caller_method}, ["debug_ui", "error"]
		)
		return false

	return true


## Add a category item to the list with proper metadata (DRY principle)
func _add_category_item_to_list(category_name: String, index: int) -> void:
	# Check if this category has ungrouped actions
	var has_direct_actions: bool = DebugRegistry.has_ungrouped_actions(category_name)

	# Add visual indicator for categories with direct actions vs submenus only
	var display_name: String = category_name
	if has_direct_actions:
		display_name = "• " + category_name  # Bullet indicates direct actions available
	else:
		display_name = "▸ " + category_name  # Arrow indicates submenus only

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
