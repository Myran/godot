# project/debug/actions/debug_action.gd
@tool
class_name DebugAction
extends Resource

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


# Enhanced execute method with proper async support and signals
func execute() -> void:
	if action_callable.is_valid():
		_update_status("Executing " + action_name + "...")
		var result: Variant = await action_callable.call()
		_update_status("Completed: " + action_name)
		execution_completed.emit(true, result)
	else:
		# Subclasses can override this for resource-based actions
		_update_status("ERROR: No execute method defined for " + action_name, true)
		execution_completed.emit(false, "No execute method defined")


# Helper to update status via signal instead of direct UI access
func _update_status(text: String, is_error: bool = false) -> void:
	status_updated.emit(text, is_error)
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
