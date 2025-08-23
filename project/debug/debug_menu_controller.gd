extends Control
enum ViewLevel { MAIN_CATEGORIES, GROUP_LIST, TEST_LIST, SAVED_STATES }

const DebugOutputServiceClass = preload("res://debug/debug_output_service.gd")
const SaveDebugStateActionClass = preload("res://debug/actions/system/save_debug_state_action.gd")
const LoadDebugStateActionClass = preload("res://debug/actions/system/load_debug_state_action.gd")

const FONT_SIZE_XXL: int = 34
const FONT_SIZE_XL: int = 32
const FONT_SIZE_L: int = 30
const FONT_SIZE_M: int = 24

const UI_COLORS: Dictionary = {
	"background": "#37474F",  # Maintain existing background
	"surface": "#455A64",  # Maintain existing surface
	"muted": "#9E9E9E",  # Muted gray
	"primary": "#64B5F6",  # Soft blue - primary actions
	"secondary": "#81C784",  # Muted green - secondary elements
	"accent": "#FFB74D",  # Amber - used for highlights, warnings, and booleans
	"success": "#81C784",  # Success green - matches secondary
	"warning": "#FFB74D",  # Warning - matches accent
	"danger": "#E57373",  # Soft red - errors
	"info": "#4FC3F7",  # Light blue - informational
	"text_primary": "#FFFFFF",  # Pure white - main content
	"text_secondary": "#CFD8DC",  # Light gray - secondary text
	"text_tertiary": "#90A4AE",  # Muted blue-gray - less important info
	"key": "#FFB74D",  # Property key - matches accent
	"string": "#81C784",  # String value - matches success
	"number": "#4FC3F7",  # Number value - matches info
	"boolean": "#FFB74D",  # Boolean value - matches accent
	"null_value": "#90A4AE",  # Null value - matches text_tertiary
	"border": "#546E7A",  # Border color - subtle separation
	"highlight": "#FFECB3",  # Highlight color - light version of accent
}
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

var _current_executing_action: DebugAction = null
var _run_all_abort_requested: bool = false

var _run_all_actions: Array[ActionExecutionResult] = []
var _run_all_current_index: int = 0
var _run_all_results: Array[Dictionary] = []
var _run_all_scope: String = ""

var _last_action_data: Dictionary = {}
var _is_list_hidden: bool = false  # Track if navigation list is hidden
var _is_test_mode_active: bool = false  # Track if automated test is running
var _ui_hidden_by_test: bool = false  # Track if UI was hidden by test mode (not user)
@onready var status_label: RichTextLabel = %DebugRichTextLabel
@onready var item_list_navigator: ItemList = %DebugItemList
@onready var run_all_button: Button = %RunAllButton  # Add this button to your scene if not already present
@onready var text_toggle_button: Button = %TextToggleButton
@onready var exit_button: Button = %ExitButton


class ActionExecutionResult:
	var action: DebugAction
	var is_manual: bool

	func _init(p_action: DebugAction, p_is_manual: bool) -> void:
		action = p_action
		is_manual = p_is_manual


func _add_list_item(
	text: String, metadata: MenuListItemData = null, tooltip: String = "", disabled: bool = false
) -> int:
	"""Add an item to the navigation list with optional metadata and tooltip"""
	var index: int = item_list_navigator.get_item_count()
	item_list_navigator.add_item(text)

	if metadata:
		item_list_navigator.set_item_metadata(index, metadata)

	if not tooltip.is_empty():
		item_list_navigator.set_item_tooltip(index, tooltip)

	if disabled:
		item_list_navigator.set_item_disabled(index, true)

	return index


func _add_navigation_item(text: String, metadata: MenuListItemData) -> void:
	"""Add a navigation item (back button) to the list"""
	_add_list_item(text, metadata)


func _add_action_item(
	action: DebugAction, category: String, group: String = "", prefix: String = ""
) -> void:
	"""Add a debug action item to the list"""
	var display_text: String = prefix + action.action_name
	var metadata: MenuListItemData = MenuListItemData.create_action(action, category, group)
	_add_list_item(display_text, metadata, action.description)


func _add_group_item(group_name: String, category: String, prefix: String = "▸ ") -> void:
	"""Add a group item to the list"""
	var display_text: String = prefix + group_name
	var metadata: MenuListItemData = MenuListItemData.create_group(category, group_name)
	_add_list_item(display_text, metadata)


func _clear_navigation_state() -> void:
	"""Clear navigation state and reset UI visibility"""
	_last_action_data.clear()
	_is_list_hidden = false
	if is_instance_valid(item_list_navigator):
		item_list_navigator.visible = true
	if is_instance_valid(run_all_button):
		run_all_button.visible = true
	_update_toggle_button_state()


func _set_run_all_button_text(text: String, _is_visible: bool = true) -> void:
	"""Update the run all button text and visibility"""
	if is_instance_valid(run_all_button):
		run_all_button.text = text
		run_all_button.visible = _is_visible


func _ready() -> void:
	Log.info("DebugMenuController ready.", {}, [Log.TAG_DEBUG, Log.TAG_UI, Log.TAG_INITIALIZATION])

	if (
		not is_instance_valid(item_list_navigator)
		or not is_instance_valid(status_label)
		or not is_instance_valid(run_all_button)
		or not is_instance_valid(text_toggle_button)
	):
		Log.error(
			"Required UI elements not found in scene_debug.tscn!",
			{},
			[Log.TAG_DEBUG, Log.TAG_UI, Log.TAG_ERROR]
		)
		return

	_configure_ui_elements()

	item_list_navigator.set_deferred("editable", false)
	run_all_button.disabled = true

	item_list_navigator.item_selected.connect(_on_navigator_item_selected)
	run_all_button.pressed.connect(_on_run_all_pressed)
	text_toggle_button.pressed.connect(_on_text_toggle_button_pressed)
	exit_button.pressed.connect(_on_button_close_pressed)
	DebugManager.debug_event.connect(_on_global_debug_event)

	add_to_group("debug_menu")

	_populate_main_categories_view()

	_update_toggle_button_state()

	_start_test_mode_monitoring()


func _configure_ui_elements() -> void:
	if is_instance_valid(status_label):
		status_label.bbcode_enabled = true
		status_label.scroll_following = true
		status_label.fit_content = true
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		status_label.scroll_active = true

		status_label.clip_contents = false

	if is_instance_valid(item_list_navigator):
		item_list_navigator.auto_height = true

	if is_instance_valid(text_toggle_button):
		text_toggle_button.flat = false


func _on_text_toggle_button_pressed() -> void:
	_toggle_result_expansion()


func _toggle_result_expansion() -> void:
	_is_list_hidden = !_is_list_hidden

	if is_instance_valid(item_list_navigator):
		item_list_navigator.visible = !_is_list_hidden

	if is_instance_valid(run_all_button):
		run_all_button.visible = !_is_list_hidden

	_update_toggle_button_state()


func _update_toggle_button_state() -> void:
	if not is_instance_valid(text_toggle_button):
		return

	text_toggle_button.visible = true
	text_toggle_button.disabled = false

	if _is_test_mode_active:
		if _is_list_hidden:
			text_toggle_button.text = "🧪 Test View"
		else:
			text_toggle_button.text = "🧪 Test Menu"
	else:
		if _is_list_hidden:
			text_toggle_button.text = "Debug Menu"
		else:
			text_toggle_button.text = "Debug Menu"


func _update_status_label_text(text: String, is_error: bool = false) -> void:
	if is_instance_valid(status_label):
		status_label.bbcode_enabled = true
		status_label.scroll_following = true
		status_label.fit_content = true

		var header: String = _build_styled_header()

		var styled_content: String = ""
		if is_error:
			styled_content = _apply_error_styling(text)
		else:
			styled_content = _apply_success_styling(text)

		status_label.text = header + "\n" + styled_content

		await get_tree().process_frame
		if status_label.get_v_scroll_bar():
			status_label.get_v_scroll_bar().value = status_label.get_v_scroll_bar().max_value


func _build_styled_header() -> String:
	var build_type: String = "Debug" if OS.is_debug_build() else "Release"
	var commit_hash: String = Engine.get_version_info().get("hash", "unknown")
	var shortened_hash: String = (
		commit_hash.substr(0, 8) if commit_hash.length() > 8 else commit_hash
	)

	return (
		(
			"[font_size=%s][color=%s]━━━ DEBUG CONSOLE ━━━[/color][/font_size]\n"
			% [FONT_SIZE_XL, UI_COLORS.info]
		)
		+ (
			"[font_size=%s][color=%s]%s • %s • %s[/color][/font_size]"
			% [FONT_SIZE_M, UI_COLORS.text_secondary, OS.get_name(), build_type, shortened_hash]
		)
	)


func _apply_error_styling(text: String) -> String:
	return (
		"[font_size=%s][color=%s]⚠ ERROR[/color][/font_size]\n" % [FONT_SIZE_XL, UI_COLORS.danger]
		+ (
			"[font_size=%s][color=%s]%s[/color][/font_size]"
			% [FONT_SIZE_L, UI_COLORS.text_primary, text]
		)
	)


func _apply_success_styling(text: String) -> String:
	return (
		"[font_size=%s][color=%s]%s[/color][/font_size]"
		% [FONT_SIZE_L, UI_COLORS.text_primary, text]
	)


func _populate_main_categories_view() -> void:
	_current_view_level = ViewLevel.MAIN_CATEGORIES
	_current_category_name = ""
	_current_group_name = ""
	item_list_navigator.clear()

	_clear_navigation_state()
	_set_run_all_button_text("", false)

	Log.debug("Populating main categories view", {}, [Log.TAG_DEBUG_UI])

	if not _validate_navigation_state("_populate_main_categories_view"):
		return

	var categories: Array[String] = []
	if DebugRegistry:
		categories = DebugRegistry.get_categories()
		Log.debug(
			"Retrieved categories from DebugRegistry",
			{"categories": categories, "count": categories.size()},
			[Log.TAG_DEBUG_UI]
		)
	else:
		Log.error("DebugRegistry autoload not found", {}, [Log.TAG_DEBUG_UI, Log.TAG_ERROR])
		return

	if categories.is_empty():
		_add_list_item("No debug actions registered.", null, "", true)
		return

	var categories_with_direct_actions: Array[String] = []
	var categories_with_only_groups: Array[String] = []

	for category_name: String in categories:
		if DebugRegistry.has_ungrouped_actions(category_name):
			categories_with_direct_actions.append(category_name)
		else:
			categories_with_only_groups.append(category_name)

	categories_with_direct_actions.sort()
	categories_with_only_groups.sort()

	var sorted_categories: Array[String] = (
		categories_with_direct_actions + categories_with_only_groups
	)

	for i: int in range(sorted_categories.size()):
		var category_name: String = sorted_categories[i]
		_add_category_item_to_list(category_name, i)

	# Add saved states category after existing categories
	_add_list_item(
		"Saved States",
		MenuListItemData.create_saved_states(),
		"Load captured gamestate for replay testing"
	)

	Log.info(
		"Main categories populated",
		{
			"total_categories": sorted_categories.size(),
			"direct_actions": categories_with_direct_actions.size(),
			"submenus": categories_with_only_groups.size()
		},
		[Log.TAG_DEBUG_UI]
	)


func _populate_groups_view(category_name: String) -> void:
	_current_view_level = ViewLevel.GROUP_LIST
	_current_category_name = category_name
	_current_group_name = ""
	item_list_navigator.clear()

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

	Log.debug("Populating groups for category: " + category_name, {}, [Log.TAG_DEBUG_UI])

	if not _validate_navigation_state("_populate_groups_view"):
		_update_status_label_text("ERROR: Invalid navigation state.", true)
		return

	var category_exists: bool = false

	if DebugRegistry:
		var debug_categories: Array[String] = DebugRegistry.get_categories()
		var category_found: bool = debug_categories.has(category_name)
		if category_found:
			category_exists = true

	if not category_exists:
		_update_status_label_text(
			"ERROR: Category '%s' not found in debug system." % category_name, true
		)
		Log.error(
			"Category validation failed",
			{"category": category_name},
			[Log.TAG_DEBUG_UI, Log.TAG_ERROR]
		)
		return

	item_list_navigator.add_item(BACK_TO_MAIN_MENU_TEXT)
	item_list_navigator.set_item_metadata(0, MenuListItemData.create_back_to_main())

	var has_ungrouped: bool = DebugRegistry.has_ungrouped_actions(category_name)

	if has_ungrouped:
		Log.debug(
			"Category has ungrouped actions, redirecting to category_with_actions view",
			{"category": category_name},
			[Log.TAG_DEBUG_UI]
		)
		item_list_navigator.clear()
		_populate_category_with_actions_view(category_name)
		return

	var groups: Array[String] = []
	if DebugRegistry:
		groups = DebugRegistry.get_groups_for_category(category_name)
	else:
		Log.error("DebugRegistry autoload not found", {}, [Log.TAG_DEBUG_UI, Log.TAG_ERROR])
		return

	if groups.is_empty():
		item_list_navigator.add_item("No groups in this category.")
		item_list_navigator.set_item_disabled(1, true)
		return

	for i: int in range(groups.size()):
		var group_name: String = groups[i]
		item_list_navigator.add_item(group_name)
		item_list_navigator.set_item_metadata(
			i + 1, MenuListItemData.create_group(category_name, group_name)
		)

	Log.info(
		"Groups populated for category",
		{"category": category_name, "total_groups": groups.size()},
		[Log.TAG_DEBUG_UI]
	)


func _populate_category_with_actions_view(category_name: String) -> void:
	"""Show a category that has both direct actions and groups"""
	_current_view_level = ViewLevel.GROUP_LIST
	_current_category_name = category_name
	_current_group_name = ""
	item_list_navigator.clear()

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

	Log.debug("Populating category with direct actions: " + category_name, {}, [Log.TAG_DEBUG_UI])

	if not _validate_navigation_state("_populate_category_with_actions_view"):
		return

	item_list_navigator.add_item(BACK_TO_MAIN_MENU_TEXT)
	item_list_navigator.set_item_metadata(0, MenuListItemData.create_back_to_main())

	var item_index: int = 1

	var ungrouped_actions: Array[DebugAction] = DebugRegistry.get_ungrouped_actions(category_name)

	if ungrouped_actions.size() > 0:
		for action: DebugAction in ungrouped_actions:
			item_list_navigator.add_item("• " + action.action_name)  # Bullet to show it's an action
			item_list_navigator.set_item_tooltip(item_index, action.description)
			item_list_navigator.set_item_metadata(
				item_index, MenuListItemData.create_action(action, category_name, "")
			)
			item_index += 1

	var all_groups: Array[String] = []

	if DebugRegistry:
		all_groups = DebugRegistry.get_groups_for_category(category_name)

	for group_name: String in all_groups:
		item_list_navigator.add_item("▸ " + group_name)  # Arrow to show it's expandable
		item_list_navigator.set_item_metadata(
			item_index, MenuListItemData.create_group(category_name, group_name)
		)
		item_index += 1

	Log.info(
		"Category with actions populated",
		{
			"category": category_name,
			"ungrouped_actions": ungrouped_actions.size(),
			"total_groups": all_groups.size()
		},
		[Log.TAG_DEBUG_UI]
	)


func _populate_actions_view(category_name: String, group_name: String) -> void:
	_current_view_level = ViewLevel.TEST_LIST
	_current_category_name = category_name
	_current_group_name = group_name
	item_list_navigator.clear()

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
		"Populating actions for group: %s -> %s" % [category_name, group_name],
		{},
		[Log.TAG_DEBUG_UI]
	)

	item_list_navigator.add_item(BACK_TO_GROUPS_TEXT)
	item_list_navigator.set_item_metadata(
		0, MenuListItemData.create_back_to_groups(_current_category_name)
	)

	if not DebugRegistry:
		_update_status_label_text(
			"ERROR: DebugRegistry autoload not found while accessing group actions.", true
		)
		return
	var registry: DebugActionRegistry = DebugRegistry

	var actions_in_group: Array[DebugAction] = registry.get_actions_for_group(
		category_name, group_name
	)

	if actions_in_group.is_empty():
		item_list_navigator.add_item("No actions in this group.")
		item_list_navigator.set_item_disabled(1, true)
		return

	var item_index: int = 1
	for i: int in range(actions_in_group.size()):
		var action: DebugAction = actions_in_group[i]
		item_list_navigator.add_item(action.action_name)
		item_list_navigator.set_item_tooltip(item_index, action.description)
		item_list_navigator.set_item_metadata(
			item_index, MenuListItemData.create_action(action, category_name, group_name)
		)
		item_index += 1


func _populate_saved_states_view() -> void:
	"""Show available saved debug states with load options"""
	_current_view_level = ViewLevel.SAVED_STATES
	_current_category_name = "Saved States"
	_current_group_name = ""
	item_list_navigator.clear()

	# Add back navigation
	_add_navigation_item("< Back to Main Menu", MenuListItemData.create_back_to_main())

	# Add save current state option
	var save_action: SaveDebugStateActionClass = SaveDebugStateActionClass.new()
	_add_action_item(save_action, "System", "Debug", "")

	# Scan for saved states using centralized path management
	var saved_states_dir: String = DebugConfigReader.get_saved_states_dir()
	_scan_and_add_saved_states(saved_states_dir)


func _scan_and_add_saved_states(directory_path: String) -> void:
	"""Scan directory and add load buttons for each JSON file"""
	var dir: DirAccess = DirAccess.open(directory_path)
	if not dir:
		_add_list_item(
			"📁 No saved states found",
			null,
			"Create saved states by using 'Save State' during gameplay",
			true
		)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var state_files: Array[String] = []

	while file_name != "":
		if file_name.ends_with(".json") and not file_name.begins_with("."):
			state_files.append(file_name)
		file_name = dir.get_next()

	if state_files.is_empty():
		_add_list_item(
			"📁 No saved states found",
			null,
			"Use 'just capture-gamestate NAME' to create saved states",
			true
		)
		return

	state_files.sort()

	# Add load option for each saved state
	for state_file: String in state_files:
		var display_name: String = "Load: " + state_file.get_basename()
		var full_path: String = directory_path + "/" + state_file
		var load_action: LoadDebugStateActionClass = LoadDebugStateActionClass.create_for_file(
			full_path
		)
		var metadata: MenuListItemData = MenuListItemData.create_action(
			load_action, "System", "Debug"
		)
		var tooltip: String = (
			"Load '" + state_file.get_basename() + "' as starting point for new recording session"
		)
		_add_list_item(display_name, metadata, tooltip)


func _abort_current_execution_if_needed() -> void:
	"""Abort current action execution or Run All operation"""
	if not _is_executing_all:
		return

	Log.info(
		"Aborting current execution to start new action", {}, [Log.TAG_DEBUG_UI, Log.TAG_ABORTION]
	)

	if _current_executing_action != null:
		_abort_single_action(_current_executing_action)

	if not _run_all_actions.is_empty():
		_abort_run_all_execution()

	_reset_execution_state()


func _abort_single_action(action: DebugAction) -> void:
	"""Abort a single action execution"""
	Log.debug(
		"Aborting single action: %s" % action.action_name, {}, [Log.TAG_DEBUG_UI, Log.TAG_ABORTION]
	)

	if action.status_updated.is_connected(_on_action_status_updated):
		action.status_updated.disconnect(_on_action_status_updated)
	if action.execution_completed.is_connected(_on_action_execution_completed):
		action.execution_completed.disconnect(_on_action_execution_completed)

	_current_executing_action = null


func _abort_run_all_execution() -> void:
	"""Abort Run All execution"""
	Log.debug(
		"Aborting Run All execution with %d actions" % _run_all_actions.size(),
		{},
		[Log.TAG_DEBUG_UI, Log.TAG_ABORTION]
	)

	_run_all_abort_requested = true

	for action_result: ActionExecutionResult in _run_all_actions:
		var action: DebugAction = action_result.action
		if action.execution_completed.is_connected(_on_run_all_action_completed):
			action.execution_completed.disconnect(_on_run_all_action_completed)

	_run_all_actions.clear()


func _reset_execution_state() -> void:
	"""Reset all execution state variables"""
	_is_executing_all = false
	_current_executing_action = null
	_run_all_actions.clear()
	_run_all_current_index = 0
	_run_all_results.clear()
	_run_all_scope = ""
	_run_all_abort_requested = false

	_set_ui_for_execution(false)

	_last_action_data.clear()

	Log.debug(
		"Execution state reset - ready for new actions", {}, [Log.TAG_DEBUG_UI, Log.TAG_ABORTION]
	)


func _on_navigator_item_selected(index: int) -> void:
	if index < 0 or index >= item_list_navigator.item_count:
		return

	var metadata: MenuListItemData = item_list_navigator.get_item_metadata(index)

	match metadata.type:
		MenuListItemData.ItemType.CATEGORY:
			_abort_current_execution_if_needed()
			_populate_groups_view(metadata.category_name)
		MenuListItemData.ItemType.ACTION:
			_abort_current_execution_if_needed()
			_execute_single_action(metadata.action_instance)
		MenuListItemData.ItemType.GROUP:
			_abort_current_execution_if_needed()
			_populate_actions_view(_current_category_name, metadata.group_name)
		MenuListItemData.ItemType.BACK_TO_MAIN:
			_abort_current_execution_if_needed()
			_populate_main_categories_view()
		MenuListItemData.ItemType.BACK_TO_GROUPS:
			_abort_current_execution_if_needed()
			_populate_groups_view(_current_category_name)
		MenuListItemData.ItemType.SAVED_STATES:
			_abort_current_execution_if_needed()
			_populate_saved_states_view()


func _on_run_all_pressed() -> void:
	_abort_current_execution_if_needed()

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

	else:
		Log.warning("Run All pressed in an unsupported view level.", {}, [Log.TAG_DEBUG_UI])
		return

	if actions_to_run.is_empty():
		_update_status_label_text("No actions to run in '%s'." % scope_name)
		return

	_execute_multiple_actions(actions_to_run, "All in '%s'" % scope_name)


func _execute_single_action(action: DebugAction) -> void:
	_current_executing_action = action
	_is_executing_all = true
	_set_ui_for_execution(true)

	DebugOutputServiceClass.start_action_execution(action)
	Log.info("Executing single action: %s" % action.action_name, {}, [Log.TAG_DEBUG, Log.TAG_TEST])

	if action.status_updated.is_connected(_on_action_status_updated):
		action.status_updated.disconnect(_on_action_status_updated)
	action.status_updated.connect(_on_action_status_updated)

	if action.execution_completed.is_connected(_on_action_execution_completed):
		action.execution_completed.disconnect(_on_action_execution_completed)
	action.execution_completed.connect(_on_action_execution_completed)

	_last_action_data = {"action": action, "success": false, "payload": null}

	action.execute()


func _on_action_execution_completed(success: bool, payload: Variant) -> void:
	var action: DebugAction = _last_action_data.get("action", null)
	if not action:
		return

	if action != _current_executing_action:
		Log.debug(
			"Ignoring completion for aborted action: %s" % action.action_name,
			{},
			[Log.TAG_DEBUG_UI, Log.TAG_ABORTION]
		)
		return

	if action.status_updated.is_connected(_on_action_status_updated):
		action.status_updated.disconnect(_on_action_status_updated)
	if action.execution_completed.is_connected(_on_action_execution_completed):
		action.execution_completed.disconnect(_on_action_execution_completed)

	_last_action_data = {"action": action, "success": success, "payload": payload}

	DebugOutputServiceClass.output_action_result(action, success, payload)
	_update_toggle_button_state()

	# Restart handling is now done through central event system (EVENT_RESTART_GAME)
	# No special restart handling needed here anymore

	_current_executing_action = null
	_set_ui_for_execution(false)
	_is_executing_all = false


func _on_action_status_updated(_text: String, _is_error: bool) -> void:
	pass


func _execute_multiple_actions(
	actions_to_run: Array[ActionExecutionResult], scope_description: String
) -> void:
	if actions_to_run.is_empty():
		_update_status_label_text("No actions to execute in %s." % scope_description)
		return

	_run_all_abort_requested = false
	_is_executing_all = true
	_set_ui_for_execution(true)

	Log.info(
		"Starting Run All execution",
		{"scope": scope_description, "action_count": actions_to_run.size()},
		[Log.TAG_DEBUG, Log.TAG_UI, Log.TAG_RUN_ALL]
	)

	var execution_results: Array[Dictionary] = []
	var current_action_index: int = 0

	_update_status_label_text(
		"Running %d actions in %s..." % [actions_to_run.size(), scope_description]
	)

	_execute_next_action_in_sequence(
		actions_to_run, current_action_index, execution_results, scope_description
	)


func _execute_next_action_in_sequence(
	actions_to_run: Array[ActionExecutionResult],
	current_index: int,
	results: Array[Dictionary],
	scope_description: String
) -> void:
	_run_all_actions = actions_to_run
	_run_all_current_index = current_index
	_run_all_results = results
	_run_all_scope = scope_description

	if _run_all_abort_requested:
		Log.info(
			"Run All execution aborted by user",
			{},
			[Log.TAG_DEBUG_UI, Log.TAG_RUN_ALL, Log.TAG_ABORTION]
		)
		_reset_execution_state()
		_update_status_label_text("Run All execution aborted.")
		return

	if current_index >= actions_to_run.size():
		_complete_run_all_execution(results, scope_description)
		return

	var action_result: ActionExecutionResult = actions_to_run[current_index]
	var action: DebugAction = action_result.action

	_update_status_label_text(
		"Running %d/%d: %s..." % [current_index + 1, actions_to_run.size(), action.action_name]
	)

	Log.debug(
		"Executing action in sequence",
		{"index": current_index + 1, "total": actions_to_run.size(), "action": action.action_name},
		[Log.TAG_DEBUG, Log.TAG_RUN_ALL]
	)

	if action.execution_completed.is_connected(_on_run_all_action_completed):
		action.execution_completed.disconnect(_on_run_all_action_completed)
	action.execution_completed.connect(_on_run_all_action_completed, CONNECT_ONE_SHOT)

	action.execute()


func _on_run_all_action_completed(success: bool, payload: Variant) -> void:
	if _run_all_abort_requested:
		Log.debug(
			"Ignoring completion for aborted Run All action",
			{},
			[Log.TAG_DEBUG_UI, Log.TAG_RUN_ALL, Log.TAG_ABORTION]
		)
		return

	var result_data: Dictionary = {
		"action_name": _run_all_actions[_run_all_current_index].action.action_name,
		"success": success,
		"payload": payload,
		"index": _run_all_current_index
	}
	_run_all_results.append(result_data)

	_execute_next_action_in_sequence(
		_run_all_actions, _run_all_current_index + 1, _run_all_results, _run_all_scope
	)


func _complete_run_all_execution(results: Array[Dictionary], scope_description: String) -> void:
	_run_all_actions.clear()
	_run_all_abort_requested = false
	_is_executing_all = false
	_set_ui_for_execution(false)

	var total_actions: int = results.size()
	var successful_actions: int = 0
	var failed_actions: int = 0

	for result: Dictionary in results:
		if result.get("success", false):
			successful_actions += 1
		else:
			failed_actions += 1

	var summary: String = _build_run_all_summary(
		results, scope_description, successful_actions, failed_actions
	)
	var has_failures: bool = failed_actions > 0

	_update_status_label_text(summary, has_failures)

	Log.info(
		"Run All execution completed",
		{
			"scope": scope_description,
			"total": total_actions,
			"successful": successful_actions,
			"failed": failed_actions
		},
		[Log.TAG_DEBUG, Log.TAG_RUN_ALL, Log.TAG_SUMMARY]
	)


func _build_run_all_summary(
	results: Array[Dictionary], scope_description: String, successful: int, failed: int
) -> String:
	var total: int = results.size()
	var summary: String = ""

	summary += "[font_size=%s][b]RUN ALL COMPLETE[/b][/font_size]\n" % FONT_SIZE_XXL
	summary += (
		"[font_size=%s][color=%s]%s[/color][/font_size]\n\n"
		% [FONT_SIZE_XL, UI_COLORS.accent, scope_description]
	)

	summary += (
		"[font_size=%s][color=%s]SUMMARY[/color][/font_size]\n" % [FONT_SIZE_XL, UI_COLORS.info]
	)
	summary += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	summary += (
		"[color=%s]Total Actions:[/color] [color=%s]%d[/color]\n"
		% [UI_COLORS.text_secondary, UI_COLORS.number, total]
	)
	summary += (
		"[color=%s]Successful:[/color] [color=%s]%d[/color]\n"
		% [UI_COLORS.text_secondary, UI_COLORS.success, successful]
	)
	summary += (
		"[color=%s]Failed:[/color] [color=%s]%d[/color]\n\n"
		% [UI_COLORS.text_secondary, UI_COLORS.danger if failed > 0 else UI_COLORS.muted, failed]
	)

	var success_rate: float = (float(successful) / float(total)) * 100.0 if total > 0 else 0.0
	var rate_color: String = (
		UI_COLORS.success
		if success_rate >= 80.0
		else (UI_COLORS.warning if success_rate >= 50.0 else UI_COLORS.danger)
	)
	summary += (
		"[color=%s]Success Rate:[/color] [color=%s]%.1f%%[/color]\n\n"
		% [UI_COLORS.text_secondary, rate_color, success_rate]
	)

	summary += (
		"[font_size=%s][color=%s]DETAILED RESULTS[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	summary += "[color=%s]" % UI_COLORS.surface + "─".repeat(40) + "[/color]\n"

	for i: int in range(results.size()):
		var result: Dictionary = results[i]
		var action_name: String = result.get("action_name", "Unknown Action")
		var success: bool = result.get("success", false)
		var payload: Variant = result.get("payload", null)

		var status_icon: String = "✓" if success else "✗"
		var status_color: String = UI_COLORS.success if success else UI_COLORS.danger
		var index_str: String = "[color=%s][%02d][/color]" % [UI_COLORS.number, i + 1]

		summary += (
			"%s [color=%s]%s[/color] [color=%s]%s[/color]"
			% [index_str, status_color, status_icon, UI_COLORS.text_primary, action_name]
		)

		if not success and payload != null:
			var error_summary: String = _extract_concise_error(payload)
			if not error_summary.is_empty():
				summary += " [color=%s]- %s[/color]" % [UI_COLORS.danger, error_summary]

		summary += "\n"

	summary += (
		"\n[color=%s]Execution completed at %s[/color]"
		% [UI_COLORS.text_secondary, Time.get_datetime_string_from_system()]
	)

	return summary


func _extract_concise_error(payload: Variant) -> String:
	if payload == null:
		return ""

	var payload_str: String = str(payload)

	if payload_str.contains("PERMISSION_DENIED"):
		return "Permission denied"
	elif payload_str.contains("NETWORK_ERROR"):
		return "Network error"
	elif payload_str.contains("timeout"):
		return "Timeout"
	elif payload_str.contains("not found"):
		return "Not found"
	elif payload_str.contains("Firebase"):
		return "Firebase error"
	elif payload_str.length() > 50:
		return payload_str.substr(0, 50) + "..."
	else:
		return payload_str


func _set_ui_for_execution(is_executing: bool) -> void:
	if is_instance_valid(item_list_navigator):
		item_list_navigator.set_deferred("editable", !is_executing)
		if not is_executing:
			item_list_navigator.visible = !_is_list_hidden
	if is_instance_valid(run_all_button):
		run_all_button.disabled = is_executing
		if not is_executing:
			run_all_button.visible = !_is_list_hidden

	if not is_executing:
		_update_toggle_button_state()


func _on_button_close_pressed() -> void:
	DebugManager.action(DebugManager.DebugEventType.EVENT_CLOSE_DEBUG_MENU)


func _on_global_debug_event(
	event_type: DebugManager.DebugEventType, _args: Array[Variant] = []
) -> void:
	if event_type == DebugManager.DebugEventType.EVENT_TOGGLE_DEBUG_MENU_LIST:
		_toggle_result_expansion()


func show_menu_content() -> void:
	show()
	Log.debug("Debug menu shown via direct call.", {}, [Log.TAG_DEBUG, Log.TAG_UI])


func clear_output_for_new_action(_action: DebugAction) -> void:
	"""Clear output display when a new action starts"""
	if is_instance_valid(status_label):
		status_label.text = ""
		status_label.bbcode_enabled = true
		status_label.scroll_following = true
		status_label.fit_content = true


func display_output_from_service(text: String, _is_error: bool = false) -> void:
	if is_instance_valid(status_label):
		status_label.bbcode_enabled = true
		status_label.scroll_following = true
		status_label.fit_content = true

		if text.contains("📱 DEVICE CONTEXT") or text.contains("🔄 ACTION EXECUTION"):
			status_label.text = text
		else:
			var current_text: String = status_label.text
			if current_text.is_empty():
				status_label.text = text
			else:
				status_label.text = text + current_text

		await get_tree().process_frame
		if status_label.get_v_scroll_bar():
			status_label.get_v_scroll_bar().value = 0

	if not visible:
		show()
		Log.debug("Debug menu opened to display execution results", {}, [Log.TAG_DEBUG, Log.TAG_UI])


func _validate_navigation_state(context: String) -> bool:
	"""Validate that DebugRegistry is available and functional"""
	if not DebugRegistry:
		Log.error(
			"DebugRegistry not available in context: " + context,
			{},
			[Log.TAG_DEBUG, Log.TAG_UI, Log.TAG_ERROR]
		)
		_update_status_label_text("ERROR: Debug system not properly initialized.", true)
		return false
	return true


func _add_category_item_to_list(category_name: String, index: int) -> void:
	var has_ungrouped: bool = DebugRegistry.has_ungrouped_actions(category_name)
	var display_name: String = ""

	if has_ungrouped:
		display_name = "• " + category_name  # Bullet indicates direct actions available
	else:
		display_name = "▸ " + category_name  # Arrow indicates submenu only

	item_list_navigator.add_item(display_name)
	item_list_navigator.set_item_metadata(
		index, MenuListItemData.create_category(category_name, true)
	)


func _build_single_action_report(action: DebugAction, success: bool, payload: Variant) -> String:
	"""Generate a comprehensive, beautifully formatted report for a single action execution"""
	return DebugOutputService.format_completion_report(action, success, payload)


func _start_test_mode_monitoring() -> void:
	"""Start monitoring for test mode changes to auto-hide UI during tests"""
	var timer: Timer = Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(_check_test_mode_status)
	timer.autostart = true
	add_child(timer)


func _check_test_mode_status() -> void:
	"""Check if test mode status has changed and update UI accordingly"""
	var current_test_active: bool = DebugAction.is_test_active()

	if current_test_active != _is_test_mode_active:
		_is_test_mode_active = current_test_active

		if _is_test_mode_active:
			_enter_test_mode()
		else:
			_exit_test_mode()


func _enter_test_mode() -> void:
	"""Automatically hide UI elements when entering test mode"""
	if not _is_list_hidden:
		_ui_hidden_by_test = true
		_toggle_result_expansion()

		_update_status_label_text("🧪 Test Mode Active - UI Hidden for Clean Output View")

		Log.debug(
			"Entered test mode - UI hidden automatically",
			{},
			[Log.TAG_DEBUG, Log.TAG_UI, Log.TAG_TEST]
		)


func _exit_test_mode() -> void:
	"""Restore UI elements when exiting test mode"""
	if _ui_hidden_by_test and _is_list_hidden:
		_ui_hidden_by_test = false
		_toggle_result_expansion()

		Log.debug(
			"Exited test mode - UI restored automatically",
			{},
			[Log.TAG_DEBUG, Log.TAG_UI, Log.TAG_TEST]
		)
