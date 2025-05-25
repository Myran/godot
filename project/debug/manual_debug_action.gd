@tool
class_name ManualDebugAction
extends Resource
## Resource for defining manual debug actions that appear in the debug menu.
## These are different from DebugAction as they're simpler, immediate actions.

@export var action_name: String = "Unnamed Manual Action"
@export var button_name: String = ""  # Internal identifier
@export var category: String = "Manual"
@export var group: String = ""  # Optional - empty means no group
@export_multiline var description: String = "No description."
@export var show_in_menu: bool = true
@export var requires_confirmation: bool = false
@export_multiline var confirmation_message: String = "Are you sure?"

## The actual action to execute. Override this in subclasses or use callable
var action_callable: Callable


func execute() -> void:
	if action_callable.is_valid():
		action_callable.call()
	else:
		push_error("ManualDebugAction: No action defined for " + action_name)


func _init(p_name: String = "", p_callable: Callable = Callable()) -> void:
	if p_name != "":
		action_name = p_name
		button_name = p_name.to_snake_case()
	action_callable = p_callable
