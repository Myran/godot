# project/debug/actions/rtdb/rtdb_delete_value_action.gd
@tool
class_name RTDBDeleteValueAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Delete Value"
	group = "Basic"
	description = "Deletes a value from a predefined test path in RTDB."


func execute() -> Array:
	return await execute_simple_operation(
		"remove_value_async",
		RTDBTestPaths.to_variant_array(RTDBTestPaths.SIMPLE_VALUE),
		null,
		action_name
	)
