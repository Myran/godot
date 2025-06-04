# project/debug/actions/debug_action.gd
@tool
class_name DebugAction
extends Resource

# Preload the output service for unified output handling
const DebugOutputService = preload("res://debug/debug_output_service.gd")

@export var action_name: String = "Unnamed Action"
@export var category: String = "General"  # e.g., "RTDB", "Auth", "Config"
@export var group: String = ""  # e.g., "Basic", "Listeners", "Connectivity"
@export_multiline var description: String = "No description."
@export var requires_confirmation: bool = false
@export var keyboard_shortcut: String = ""

# Signal for status updates - decouples actions from UI
signal status_updated(text: String, is_error: bool)
signal execution_completed(success: bool, result: Variant)

# Add support for callable-based actions
var action_callable: Callable

# Static test tracking variables for smart test system
static var current_test_id: String = ""
static var test_action_count: int = 0
static var test_success_count: int = 0
static var test_failure_count: int = 0


func _init(p_name: String = "", p_callable: Callable = Callable()) -> void:
	action_name = p_name
	action_callable = p_callable


# Builder pattern methods for fluent configuration
func set_category(p_category: String) -> DebugAction:
	category = p_category
	return self


func set_group(p_group: String) -> DebugAction:
	group = p_group
	return self


func set_description(p_description: String) -> DebugAction:
	description = p_description
	return self


func set_requires_confirmation(p_requires_confirmation: bool) -> DebugAction:
	requires_confirmation = p_requires_confirmation
	return self


func set_keyboard_shortcut(p_shortcut: String) -> DebugAction:
	keyboard_shortcut = p_shortcut
	return self


# Static test context management for smart testing
static func set_test_context(test_id: String) -> void:
	"""Set the current test ID for all debug actions"""
	current_test_id = test_id
	test_action_count = 0
	test_success_count = 0
	test_failure_count = 0
	Log.info("DEBUG_TEST_START", {"test_id": test_id}, ["debug", "test", "start"])


static func clear_test_context() -> void:
	"""Clear test context and emit completion signal"""
	if current_test_id != "":
		Log.info(
			"DEBUG_TEST_COMPLETE",
			{
				"test_id": current_test_id,
				"total_actions": test_action_count,
				"successful_actions": test_success_count,
				"failed_actions": test_failure_count
			},
			["debug", "test", "complete"]
		)
		current_test_id = ""


static func get_current_test_id() -> String:
	"""Get the current test ID (useful for debugging)"""
	return current_test_id


static func is_test_active() -> bool:
	"""Check if we're currently in a test context"""
	return current_test_id != ""


# Static factory method for creating programmatic actions
static func create(p_name: String, p_callable: Callable) -> DebugAction:
	var action: DebugAction = DebugAction.new(p_name, p_callable)
	return action


# Legacy factory method for compatibility
static func create_from_callable(
	p_name: String,
	p_callable: Callable,
	p_category: String = "Manual",
	p_group: String = "",
	p_description: String = ""
) -> DebugAction:
	var action: DebugAction = DebugAction.new(p_name, p_callable)
	action.category = p_category
	action.group = p_group
	action.description = p_description if p_description else "Execute " + p_name
	return action


# Enhanced execute method with smart test tracking
func execute() -> void:
	# Track test execution if we're in test context
	if current_test_id != "":
		test_action_count += 1

	var start_time: int = Time.get_ticks_msec()
	var success: bool = false
	var error_message: String = ""
	var result: Variant = null

	_update_status("Executing " + action_name + "...")

	if action_callable.is_valid():
		# Execute the action - GDScript doesn't have try/except
		result = await action_callable.call()

		# Check if execution was successful (improved error detection)
		if result == false or (result is Dictionary and result.has("error")) or (result is Array and result.size() > 0 and result[0] == false):
			success = false
			error_message = str(result) if result != false else "Action returned false"
			_update_status("ERROR: " + action_name + " failed", true)
		elif result != null:
			success = true
			_update_status("Completed: " + action_name)
		else:
			success = false
			error_message = "Action returned null"
			_update_status("ERROR: " + action_name + " returned null", true)
	else:
		# No callable defined
		success = false
		error_message = "No execute method defined for " + action_name
		_update_status("ERROR: No execute method defined for " + action_name, true)

	var duration_ms: int = Time.get_ticks_msec() - start_time

	# Emit test tracking signals if in test context
	if current_test_id != "":
		if success:
			test_success_count += 1
			Log.info(
				"DEBUG_TEST_SUCCESS",
				{
					"test_id": current_test_id,
					"action": action_name,
					"category": category,
					"group": group,
					"duration_ms": duration_ms
				},
				["debug", "test", "success"]
			)
		else:
			test_failure_count += 1
			Log.error(
				"DEBUG_TEST_FAILURE",
				{
					"test_id": current_test_id,
					"action": action_name,
					"category": category,
					"group": group,
					"error": error_message,
					"duration_ms": duration_ms
				},
				["debug", "test", "failure"]
			)

	# NEW: Unified output for completion using DebugOutputService
	DebugOutputService.output_action_result(self, success, result if success else error_message)

	# EXISTING: Keep signal for backward compatibility
	execution_completed.emit(success, result if success else error_message)


# Helper to update status via signal instead of direct UI access
func _update_status(text: String, is_error: bool = false) -> void:
	# NEW: Unified output for all execution paths using DebugOutputService
	DebugOutputService.output_action_status(self, text, is_error)

	# EXISTING: Keep signal for backward compatibility
	status_updated.emit(text, is_error)

	# Keep original logging for system logs
	Log.info(
		text,
		{"category": category, "group": group, "action": action_name, "error": is_error},
		["debug", "test"]
	)


# Helper to simplify returning success
func _success(payload: Variant = null) -> Array:
	return [true, payload]


# Helper to simplify returning failure
func _failure(error_message: String, details: Dictionary = {}) -> Array:
	var error_info: Dictionary = {"error": error_message}
	error_info.merge(details, true)
	return [false, error_info]
