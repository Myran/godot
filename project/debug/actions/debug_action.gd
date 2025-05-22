# project/debug/actions/debug_action.gd
@tool
class_name DebugAction
extends Resource

@export var action_name: String = "Unnamed Action"
@export var category: String = "General"  # e.g., "RTDB", "Auth", "Config"
@export var group: String = "Default"  # e.g., "Basic", "Listeners", "Connectivity"
@export_multiline var description: String = "No description."


# Method to be implemented by specific actions
# target_node can be used to emit signals or update UI elements (like a status label)
# Returns an array: [bool_success, Variant_payload_or_error_info]
func execute(target_node: Node = null) -> Array:
	push_error("Execute method not implemented for action: ", action_name)
	return [false, {"error": "Not implemented"}]


# Helper to update status on the target node's status label
func _update_status(target_node: Node, text: String, is_error: bool = false) -> void:
	# Use % to access nodes by unique name regardless of hierarchy
	var label = target_node.get_node_or_null("%DebugRichTextLabel")

	if label:
		if label is RichTextLabel:
			var color_tag = "[color=green]" if not is_error else "[color=red]"
			label.text = color_tag + text + "[/color]"
			Log.info(
				text,
				{"category": category, "group": group, "action": action_name, "error": is_error},
				["debug", "test"]
			)
		elif label is Label:  # Fallback for simple Label
			label.text = text
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
