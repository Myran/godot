# project/debug/debug_output_service.gd
class_name DebugOutputService
extends RefCounted

# Use direct class reference since both files are in same directory
# and DebugOutputFormatter is declared as class_name

# Simple static interface
static var _formatter: DebugOutputFormatter
static var _initialized: bool = false

# Execution tracking for complete step-by-step logs
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

	# Signal debug menu to clear previous output for new action
	_signal_new_action_started(action)

	# Add initial execution start log
	_add_execution_log_entry("Starting execution...", false)


static func output_action_status(action: DebugAction, text: String, is_error: bool = false) -> void:
	if not _ensure_initialized():
		return

	# Track this status update in the execution log
	_add_execution_log_entry(text, is_error)

	# Enhanced status output with real-time indicators
	var enhanced_status: String = _formatter.format_enhanced_status(action, text, is_error)

	# Always log to system first (most reliable)
	_log_to_system(action, enhanced_status, is_error)

	# Send progressive status updates to debug menu for real-time monitoring
	_send_to_debug_menu_if_available(enhanced_status, is_error)

	# Also output to console if appropriate
	if _should_output_to_console():
		_formatter.output_formatted_text(enhanced_status)


static func output_action_result(action: DebugAction, success: bool, result: Variant) -> void:
	if not _ensure_initialized():
		return

	# Add final result to execution log
	var result_text: String = "Completed successfully" if success else "Failed with error"
	_add_execution_log_entry(result_text, not success)

	var report: String = _formatter.format_completion_report_with_execution_log(action, success, result, _current_execution_log)
	_log_to_system(action, report, not success)

	# Try to send formatted report to debug menu UI if available
	_send_to_debug_menu_if_available(report, not success)

	# Also output to console if appropriate
	if _should_output_to_console():
		_formatter.output_formatted_text(report)

	# Clear execution log after completion
	_current_execution_log.clear()
	_current_action = null


static func output_action_result_structured(
	action: DebugAction, action_result: DebugAction.Result
) -> void:
	"""Enhanced output method for DebugAction.Result - provides richer information"""
	if not _ensure_initialized():
		return

	var report: String = _formatter.format_completion_report_structured(action, action_result)
	_log_to_system(action, report, action_result.is_failure())

	# Try to send formatted report to debug menu UI if available
	_send_to_debug_menu_if_available(report, action_result.is_failure())

	# Also output to console if appropriate
	if _should_output_to_console():
		_formatter.output_formatted_text(report)


static func format_completion_report(action: DebugAction, success: bool, result: Variant) -> String:
	if not _ensure_initialized():
		return "Error: DebugOutputService not initialized"

	return _formatter.format_completion_report(action, success, result)


static func _log_to_system(action: DebugAction, text: String, is_error: bool) -> void:
	if is_error:
		Log.error(text, {"action": action.action_name}, ["debug", "test"])
	else:
		Log.info(text, {"action": action.action_name}, ["debug", "test"])


static func _send_to_debug_menu_if_available(text: String, is_error: bool = false) -> void:
	# Send output to debug menu UI if it exists (both manual and startup execution)
	var debug_menu: Variant = _get_debug_menu_controller()
	if debug_menu and debug_menu.has_method("display_output_from_service"):
		debug_menu.display_output_from_service(text, is_error)


static func _signal_new_action_started(action: DebugAction) -> void:
	"""Signal debug menu that a new action is starting and should clear previous output"""
	var debug_menu: Variant = _get_debug_menu_controller()
	if debug_menu and debug_menu.has_method("clear_output_for_new_action"):
		debug_menu.clear_output_for_new_action(action)


static func _get_debug_menu_controller() -> Variant:
	# Get the debug menu controller if it exists
	# Use try-catch equivalent to prevent crashes during engine initialization
	var tree: SceneTree = _safely_get_scene_tree()
	if not tree:
		return null

	var debug_menu_nodes: Array = tree.get_nodes_in_group("debug_menu")
	if debug_menu_nodes.size() > 0:
		return debug_menu_nodes[0]  # Return the first debug menu controller
	return null


static func _safely_get_scene_tree() -> SceneTree:
	# Safely get the scene tree without crashing during engine initialization
	# Return null if the engine isn't ready yet
	if Engine.is_editor_hint():
		return null

	# Check if we can safely access the main loop
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null:
		return null

	return main_loop as SceneTree


static func _should_output_to_console() -> bool:
	# Output to console during test context or when no debug menu UI is available
	return DebugAction.is_test_active() or _get_debug_menu_controller() == null


static func _is_manual_context() -> bool:
	# Check if debug menu is available
	return _get_debug_menu_controller() != null


static func _add_execution_log_entry(message: String, is_error: bool) -> void:
	"""Add an entry to the current execution log"""
	var entry: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"message": message,
		"is_error": is_error
	}
	_current_execution_log.append(entry)
