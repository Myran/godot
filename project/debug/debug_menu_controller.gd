extends Control
enum ViewLevel {MAIN_CATEGORIES, GROUP_LIST, TEST_LIST, SAVED_STATES, ALLIED_LINEUPS, ENEMY_LINEUPS}

const DebugOutputServiceClass = preload("res://debug/debug_output_service.gd")
const SaveDebugStateActionClass = preload("res://debug/actions/system/save_debug_state_action.gd")
const LoadDebugStateActionClass = preload("res://debug/actions/system/load_debug_state_action.gd")
const SaveAlliedLineupActionClass = preload(
	"res://debug/actions/system/save_allied_lineup_action.gd"
)
const SaveEnemyLineupActionClass = preload("res://debug/actions/system/save_enemy_lineup_action.gd")
const LoadAlliedLineupActionClass = preload(
	"res://debug/actions/system/load_allied_lineup_action.gd"
)
const LoadEnemyLineupActionClass = preload("res://debug/actions/system/load_enemy_lineup_action.gd")

const ITEM_TYPE_CATEGORY: String = "category_item"
const ITEM_TYPE_GROUP: String = "group_item"
const ITEM_TYPE_ACTION: String = "action_item"
const ITEM_TYPE_BACK_TO_MAIN: String = "back_to_main"
const ITEM_TYPE_BACK_TO_GROUPS: String = "back_to_groups"
const ITEM_TYPE_CATEGORY_WITH_ACTIONS: String = "category_with_actions"

const BACK_TO_MAIN_MENU_TEXT: String = "< Back to Main Menu"
const BACK_TO_GROUPS_TEXT: String = "< Back to Categories"

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
@onready var run_all_button: Button = %RunAllButton
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
	_add_list_item(text, metadata)


func _add_action_item(
	action: DebugAction, category: String, group: String = "", prefix: String = ""
) -> void:
	var display_text: String = DebugMenuUtilities.generate_action_display_name(
		action.action_name, prefix
	)
	var metadata: MenuListItemData = MenuListItemData.create_action(action, category, group)
	_add_list_item(display_text, metadata, action.description)


func _add_group_item(group_name: String, category: String, prefix: String = "▸ ") -> void:
	var display_text: String = DebugMenuUtilities.generate_group_display_name(group_name, prefix)
	var metadata: MenuListItemData = MenuListItemData.create_group(category, group_name)
	_add_list_item(display_text, metadata)


func _clear_navigation_state() -> void:
	_last_action_data.clear()
	_is_list_hidden = false
	DebugMenuUtilities.setup_navigation_ui_visibility(item_list_navigator, run_all_button)
	_update_toggle_button_state()


func _set_run_all_button_text(text: String, _is_visible: bool = true) -> void:
	if is_instance_valid(run_all_button):
		run_all_button.text = text
		run_all_button.visible = _is_visible


func _ready() -> void:
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

		var header: String = DebugMenuUtilities.build_styled_header()

		var styled_content: String = ""
		if is_error:
			styled_content = DebugMenuUtilities.apply_error_styling(text)
		else:
			styled_content = DebugMenuUtilities.apply_success_styling(text)

		status_label.text = header + "\n" + styled_content

		await get_tree().process_frame
		if status_label.get_v_scroll_bar():
			status_label.get_v_scroll_bar().value = status_label.get_v_scroll_bar().max_value


func _populate_main_categories_view() -> void:
	_current_view_level = ViewLevel.MAIN_CATEGORIES
	_current_category_name = ""
	_current_group_name = ""
	item_list_navigator.clear()

	_clear_navigation_state()
	_set_run_all_button_text("", false)

	if not _validate_navigation_state("_populate_main_categories_view"):
		return

	var categories: Array[String] = DebugRegistry.get_categories()

	if categories.is_empty():
		_add_list_item("No debug actions registered.", null, "", true)
		return

	var sorted_categories: Array[String] = DebugMenuUtilities.organize_categories_by_type(
		categories
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

	# Add lineup categories for designer testing
	_add_list_item(
		"Allied Lineups",
		MenuListItemData.create_allied_lineups(),
		"Save and load allied lineups for battle testing"
	)
	_add_list_item(
		"Enemy Lineups",
		MenuListItemData.create_enemy_lineups(),
		"Save and load enemy lineups for battle testing"
	)


func _populate_groups_view(category_name: String) -> void:
	_current_view_level = ViewLevel.GROUP_LIST
	_current_category_name = category_name
	_current_group_name = ""
	item_list_navigator.clear()

	_last_action_data.clear()
	_is_list_hidden = false
	DebugMenuUtilities.setup_navigation_ui_visibility(item_list_navigator, run_all_button)
	_update_toggle_button_state()

	if is_instance_valid(run_all_button):
		run_all_button.text = "Run All in '%s'" % category_name
		run_all_button.visible = true

	if not _validate_navigation_state("_populate_groups_view"):
		_update_status_label_text("ERROR: Invalid navigation state.", true)
		return

	var debug_categories: Array[String] = DebugRegistry.get_categories()
	var category_exists: bool = debug_categories.has(category_name)

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
		item_list_navigator.clear()
		_populate_category_with_actions_view(category_name)
		return

	var groups: Array[String] = DebugRegistry.get_groups_for_category(category_name)

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


func _populate_category_with_actions_view(category_name: String) -> void:
	_current_view_level = ViewLevel.GROUP_LIST
	_current_category_name = category_name
	_current_group_name = ""
	item_list_navigator.clear()

	_last_action_data.clear()
	_is_list_hidden = false
	DebugMenuUtilities.setup_navigation_ui_visibility(item_list_navigator, run_all_button)
	_update_toggle_button_state()

	if is_instance_valid(run_all_button):
		run_all_button.text = "Run All in '%s'" % category_name
		run_all_button.visible = true

	if not _validate_navigation_state("_populate_category_with_actions_view"):
		return

	item_list_navigator.add_item(BACK_TO_MAIN_MENU_TEXT)
	item_list_navigator.set_item_metadata(0, MenuListItemData.create_back_to_main())

	var item_index: int = 1

	var ungrouped_actions: Array[DebugAction] = DebugRegistry.get_ungrouped_actions(category_name)

	if ungrouped_actions.size() > 0:
		for action: DebugAction in ungrouped_actions:
			item_list_navigator.add_item(
				DebugMenuUtilities.generate_action_display_name(action.action_name, "• ")
			)
			item_list_navigator.set_item_tooltip(item_index, action.description)
			item_list_navigator.set_item_metadata(
				item_index, MenuListItemData.create_action(action, category_name, "")
			)
			item_index += 1

	var all_groups: Array[String] = DebugRegistry.get_groups_for_category(category_name)

	for group_name: String in all_groups:
		item_list_navigator.add_item(DebugMenuUtilities.generate_group_display_name(group_name))
		item_list_navigator.set_item_metadata(
			item_index, MenuListItemData.create_group(category_name, group_name)
		)
		item_index += 1


func _populate_actions_view(category_name: String, group_name: String) -> void:
	_current_view_level = ViewLevel.TEST_LIST
	_current_category_name = category_name
	_current_group_name = group_name
	item_list_navigator.clear()

	_last_action_data.clear()
	_is_list_hidden = false
	DebugMenuUtilities.setup_navigation_ui_visibility(item_list_navigator, run_all_button)
	_update_toggle_button_state()

	if is_instance_valid(run_all_button):
		run_all_button.text = "Run All in Group '%s'" % group_name
		run_all_button.visible = true

	item_list_navigator.add_item(BACK_TO_GROUPS_TEXT)
	item_list_navigator.set_item_metadata(
		0, MenuListItemData.create_back_to_groups(_current_category_name)
	)

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


func _populate_allied_lineups_view() -> void:
	_current_view_level = ViewLevel.ALLIED_LINEUPS
	_current_category_name = "Allied Lineups"
	_current_group_name = ""
	item_list_navigator.clear()

	# Add back navigation
	_add_navigation_item("< Back to Main Menu", MenuListItemData.create_back_to_main())

	# Add save current allied lineup option
	var save_action: SaveAlliedLineupActionClass = SaveAlliedLineupActionClass.new()
	_add_action_item(save_action, "System", "Lineup", "")

	# Scan for lineup saves using centralized path management
	var saved_states_dir: String = DebugConfigReader.get_saved_states_dir()
	_scan_and_add_lineup_saves(saved_states_dir, "line-", "allied")


func _populate_enemy_lineups_view() -> void:
	_current_view_level = ViewLevel.ENEMY_LINEUPS
	_current_category_name = "Enemy Lineups"
	_current_group_name = ""
	item_list_navigator.clear()

	# Add back navigation
	_add_navigation_item("< Back to Main Menu", MenuListItemData.create_back_to_main())

	# Add save current enemy lineup option
	var save_action: SaveEnemyLineupActionClass = SaveEnemyLineupActionClass.new()
	_add_action_item(save_action, "System", "Lineup", "")

	# Scan for lineup saves using centralized path management
	var saved_states_dir: String = DebugConfigReader.get_saved_states_dir()
	_scan_and_add_lineup_saves(saved_states_dir, "line-", "enemy")


func _scan_and_add_lineup_saves(
	directory_path: String, prefix: String, lineup_type: String
) -> void:
	var dir: DirAccess = DirAccess.open(directory_path)
	if not dir:
		_add_list_item(
			"📁 No lineup saves found",
			null,
			(
				"Create lineup saves by using 'Save %s Lineup' during gameplay"
				% lineup_type.capitalize()
			),
			true
		)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var lineup_files: Array[String] = []

	while file_name != "":
		if (
			file_name.ends_with(".json")
			and file_name.begins_with(prefix)
			and not file_name.begins_with(".")
		):
			lineup_files.append(file_name)
		file_name = dir.get_next()

	if lineup_files.is_empty():
		_add_list_item(
			"📁 No %s lineup saves found" % lineup_type,
			null,
			"Use 'just capture-lineup-%s NAME' to create lineup saves" % lineup_type,
			true
		)
		return

	lineup_files.sort()

	# Add load option for each lineup save
	for lineup_file: String in lineup_files:
		var display_name: String = "Load: " + lineup_file.get_basename()
		var full_path: String = directory_path + "/" + lineup_file
		var load_action: DebugAction

		if lineup_type == "allied":
			load_action = LoadAlliedLineupActionClass.create_for_file(full_path)
		else:
			load_action = LoadEnemyLineupActionClass.create_for_file(full_path)

		var metadata: MenuListItemData = MenuListItemData.create_action(
			load_action, "System", "Lineup"
		)
		var tooltip: String = (
			"Load '%s' as %s lineup for battle testing (flexible loading)"
			% [lineup_file.get_basename(), lineup_type]
		)
		_add_list_item(display_name, metadata, tooltip)


func _abort_current_execution_if_needed() -> void:
	if not _is_executing_all:
		return

	if _current_executing_action != null:
		_abort_single_action(_current_executing_action)

	if not _run_all_actions.is_empty():
		_abort_run_all_execution()

	_reset_execution_state()


func _abort_single_action(action: DebugAction) -> void:
	if action.status_updated.is_connected(_on_action_status_updated):
		action.status_updated.disconnect(_on_action_status_updated)
	if action.execution_completed.is_connected(_on_action_execution_completed):
		action.execution_completed.disconnect(_on_action_execution_completed)

	_current_executing_action = null


func _abort_run_all_execution() -> void:
	_run_all_abort_requested = true

	for action_result: ActionExecutionResult in _run_all_actions:
		var action: DebugAction = action_result.action
		if action.execution_completed.is_connected(_on_run_all_action_completed):
			action.execution_completed.disconnect(_on_run_all_action_completed)

	_run_all_actions.clear()


func _reset_execution_state() -> void:
	_is_executing_all = false
	_current_executing_action = null
	_run_all_actions.clear()
	_run_all_current_index = 0
	_run_all_results.clear()
	_run_all_scope = ""
	_run_all_abort_requested = false

	_set_ui_for_execution(false)

	_last_action_data.clear()


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
		MenuListItemData.ItemType.ALLIED_LINEUPS:
			_abort_current_execution_if_needed()
			_populate_allied_lineups_view()
		MenuListItemData.ItemType.ENEMY_LINEUPS:
			_abort_current_execution_if_needed()
			_populate_enemy_lineups_view()


func _on_run_all_pressed() -> void:
	_abort_current_execution_if_needed()

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

	if action.execution_completed.is_connected(_on_run_all_action_completed):
		action.execution_completed.disconnect(_on_run_all_action_completed)
	action.execution_completed.connect(_on_run_all_action_completed, CONNECT_ONE_SHOT)

	action.execute()


func _on_run_all_action_completed(success: bool, payload: Variant) -> void:
	if _run_all_abort_requested:
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


func _build_run_all_summary(
	results: Array[Dictionary], scope_description: String, successful: int, failed: int
) -> String:
	return DebugMenuUtilities.build_run_all_summary(results, scope_description, successful, failed)


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


func clear_output_for_new_action(_action: DebugAction) -> void:
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


func _validate_navigation_state(_context: String) -> bool:
	return true


func _add_category_item_to_list(category_name: String, index: int) -> void:
	var has_ungrouped: bool = DebugRegistry.has_ungrouped_actions(category_name)
	var display_name: String = DebugMenuUtilities.generate_category_display_name(
		category_name, has_ungrouped
	)

	item_list_navigator.add_item(display_name)
	item_list_navigator.set_item_metadata(
		index, MenuListItemData.create_category(category_name, true)
	)


func _start_test_mode_monitoring() -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(_check_test_mode_status)
	timer.autostart = true
	add_child(timer)


func _check_test_mode_status() -> void:
	var current_test_active: bool = DebugAction.is_test_active()

	if current_test_active != _is_test_mode_active:
		_is_test_mode_active = current_test_active

		if _is_test_mode_active:
			_enter_test_mode()
		else:
			_exit_test_mode()


func _enter_test_mode() -> void:
	if not _is_list_hidden:
		_ui_hidden_by_test = true
		_toggle_result_expansion()
		_update_status_label_text("🧪 Test Mode Active - UI Hidden for Clean Output View")


func _exit_test_mode() -> void:
	if _ui_hidden_by_test and _is_list_hidden:
		_ui_hidden_by_test = false
		_toggle_result_expansion()
