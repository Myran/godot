# project/debug/actions/debug_action.gd
@tool
class_name DebugAction
extends Resource

@export var action_name: String = "Unnamed Action"
@export var category: String = "General"  # e.g., "RTDB", "Auth", "Config"
@export var group: String = "Default"  # e.g., "Basic", "Listeners", "Connectivity"
@export_multiline var description: String = "No description."

# Signal for status updates - decouples actions from UI
signal status_updated(text: String, is_error: bool)

# Add support for callable-based actions
var action_callable: Callable


# Add static factory method for creating programmatic actions
static func create_from_callable(
	p_name: String,
	p_callable: Callable,
	p_category: String = "Manual",
	p_group: String = "",
	p_description: String = ""
) -> DebugAction:
	var action: DebugAction = DebugAction.new()
	action.action_name = p_name
	action.category = p_category
	action.group = p_group
	action.description = p_description if p_description else "Execute " + p_name
	action.action_callable = p_callable
	return action


# Method to be implemented by specific actions
# Returns an array: [bool_success, Variant_payload_or_error_info]
func execute() -> Array:
	if action_callable.is_valid():
		# Execute callable and wrap result
		action_callable.call()
		return _success({"executed": true, "type": "callable"})
	else:
		# Subclasses override this for resource-based actions
		push_error("Execute method not implemented for action: ", action_name)
		return [false, {"error": "Not implemented"}]


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
