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


# Method to be implemented by specific actions
# Returns an array: [bool_success, Variant_payload_or_error_info]
func execute() -> Array:
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
	var error_info = {"error": error_message}
	error_info.merge(details, true)
	return [false, error_info]
