# project/debug/debug_output_service.gd
class_name DebugOutputService
extends RefCounted

# Preload the formatter class
const DebugOutputFormatterClass = preload("res://debug/debug_output_formatter.gd")

# Simple static interface
static var _formatter: DebugOutputFormatterClass
static var _initialized: bool = false


static func _ensure_initialized() -> bool:
	if not _initialized:
		_formatter = DebugOutputFormatterClass.new()
		_initialized = true
	return true


static func output_action_status(action: DebugAction, text: String, is_error: bool = false) -> void:
	if not _ensure_initialized():
		return

	# Always log to system first (most reliable)
	_log_to_system(action, text, is_error)

	# Try to send to debug menu UI if available (both manual and startup execution)
	_send_to_debug_menu_if_available(text, is_error)

	# Also output to console if appropriate
	if _should_output_to_console():
		_formatter.format_and_output_status(action, text, is_error)


static func output_action_result(action: DebugAction, success: bool, result: Variant) -> void:
	if not _ensure_initialized():
		return

	var report: String = _formatter.format_completion_report(action, success, result)
	_log_to_system(action, report, not success)

	# Try to send formatted report to debug menu UI if available
	_send_to_debug_menu_if_available(report, not success)

	# Also output to console if appropriate
	if _should_output_to_console():
		_formatter.output_formatted_text(report)


static func output_action_result_structured(action: DebugAction, action_result: DebugActionResult) -> void:
	"""Enhanced output method for DebugActionResult - provides richer information"""
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
