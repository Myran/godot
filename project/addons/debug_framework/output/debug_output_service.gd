class_name DebugOutputService
extends RefCounted

static var _formatter: DebugOutputFormatter
static var _initialized: bool = false

static var _current_execution_log: Array[Dictionary] = []
static var _current_action: DebugAction = null


static func _ensure_initialized() -> bool:
	if not _initialized:
		_formatter = DebugOutputFormatter.new()
		_initialized = true
	return true


static func start_action_execution(action: DebugAction) -> void:
	"""Start tracking a new action execution"""
	_current_action = action
	_current_execution_log.clear()

	_signal_new_action_started(action)

	_add_execution_log_entry("Starting execution...", false)


static func output_action_status(action: DebugAction, text: String, is_error: bool = false) -> void:
	if not _ensure_initialized():
		return

	_add_execution_log_entry(text, is_error)

	var enhanced_status: String = _formatter.format_enhanced_status(action, text, is_error)

	_log_to_system(action, enhanced_status, is_error)

	_send_to_debug_menu_if_available(enhanced_status, is_error)

	if _should_output_to_console():
		_formatter.output_formatted_text(enhanced_status)


static func output_action_result(action: DebugAction, success: bool, result: Variant) -> void:
	if not _ensure_initialized():
		return

	var result_text: String = "Completed successfully" if success else "Failed with error"
	_add_execution_log_entry(result_text, not success)

	var report: String = _formatter.format_completion_report_with_execution_log(
		action, success, result, _current_execution_log
	)
	_log_to_system(action, report, not success)

	_send_to_debug_menu_if_available(report, not success)

	if _should_output_to_console():
		_formatter.output_formatted_text(report)

	_current_execution_log.clear()
	_current_action = null


static func output_action_result_structured(
	action: DebugAction, action_result: DebugActionResult
) -> void:
	"""Enhanced output method for DebugActionResult - provides richer information"""
	if not _ensure_initialized():
		return

	var report: String = _formatter.format_completion_report_structured(action, action_result)
	_log_to_system(action, report, action_result.is_failure())

	_send_to_debug_menu_if_available(report, action_result.is_failure())

	if _should_output_to_console():
		_formatter.output_formatted_text(report)


static func format_completion_report(action: DebugAction, success: bool, result: Variant) -> String:
	if not _ensure_initialized():
		return "Error: DebugOutputService not initialized"

	return _formatter.format_completion_report(action, success, result)


static func _log_to_system(action: DebugAction, text: String, is_error: bool) -> void:
	# Guard against shutdown - Log may be freed before callback fires (task-396)
	if not is_instance_valid(Log):
		return
	if is_error:
		Log.error(text, {"action": action.action_name}, [Log.TAG_DEBUG, Log.TAG_TEST])
	else:
		Log.info(text, {"action": action.action_name}, [Log.TAG_DEBUG, Log.TAG_TEST])


static func _send_to_debug_menu_if_available(text: String, is_error: bool = false) -> void:
	var debug_menu: Variant = _get_debug_menu_controller()
	if debug_menu and debug_menu.has_method("display_output_from_service"):
		debug_menu.display_output_from_service(text, is_error)


static func _signal_new_action_started(action: DebugAction) -> void:
	"""Signal debug menu that a new action is starting and should clear previous output"""
	var debug_menu: Variant = _get_debug_menu_controller()
	if debug_menu and debug_menu.has_method("clear_output_for_new_action"):
		debug_menu.clear_output_for_new_action(action)


static func _get_debug_menu_controller() -> Variant:
	var tree: SceneTree = _safely_get_scene_tree()
	if not tree:
		return null

	var debug_menu_nodes: Array = tree.get_nodes_in_group("debug_menu")
	if debug_menu_nodes.size() > 0:
		return debug_menu_nodes[0]  # Return the first debug menu controller
	return null


static func _safely_get_scene_tree() -> SceneTree:
	if Engine.is_editor_hint():
		return null

	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null:
		return null

	return main_loop as SceneTree


static func _should_output_to_console() -> bool:
	return DebugAction.is_test_active() or _get_debug_menu_controller() == null


static func _is_manual_context() -> bool:
	return _get_debug_menu_controller() != null


static func _add_execution_log_entry(message: String, is_error: bool) -> void:
	"""Add an entry to the current execution log"""
	var entry: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"message": message,
		"is_error": is_error
	}
	_current_execution_log.append(entry)
