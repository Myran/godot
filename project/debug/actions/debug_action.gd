# project/debug/actions/debug_action.gd
class_name DebugAction
extends Resource

# Preload the output service for unified output handling
const DebugOutputServiceClass = preload("res://debug/debug_output_service.gd")

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

		# Determine success based on standardized return patterns
		success = _evaluate_action_result(result)
		if success:
			_update_status("Completed: " + action_name)
		else:
			error_message = _extract_error_message(result)
			_update_status("ERROR: " + action_name + " - " + error_message, true)
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


# Type-safe result evaluation methods
func _evaluate_action_result(result: Variant) -> bool:
	"""Determine if an action result indicates success using standardized patterns"""
	# Handle null/void results as failure
	if result == null:
		return false

	# Handle boolean results
	if result is bool:
		return result

	# Handle array pattern [success: bool, data: Variant]
	if result is Array and result.size() >= 1:
		return result[0] == true

	# Handle dictionary with error key
	if result is Dictionary and result.has("error"):
		return false

	# Handle dictionary with success key
	if result is Dictionary and result.has("success"):
		return result["success"] == true

	# Any other non-null result is considered success
	return true


func _extract_error_message(result: Variant) -> String:
	"""Extract error message from failed action result"""
	if result == null:
		return "Action returned null"

	if result == false:
		return "Action returned false"

	# Handle array pattern [false, error_data]
	if result is Array and result.size() >= 2:
		var error_data = result[1]
		if error_data is String:
			return error_data
		elif error_data is Dictionary and error_data.has("error"):
			return str(error_data["error"])
		else:
			return str(error_data)

	# Handle dictionary with error key
	if result is Dictionary and result.has("error"):
		return str(result["error"])

	# Fallback to string representation
	return str(result)


# Helper to update status via signal instead of direct UI access
func _update_status(text: String, is_error: bool = false) -> void:
	# Unified output for all execution paths using DebugOutputService
	DebugOutputService.output_action_status(self, text, is_error)

	# Emit status update signal
	status_updated.emit(text, is_error)

	# Keep original logging for system logs
	Log.info(
		text,
		{"category": category, "group": group, "action": action_name, "error": is_error},
		["debug", "test"]
	)
