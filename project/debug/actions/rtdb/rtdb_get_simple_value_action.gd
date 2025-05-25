# project/debug/actions/rtdb/rtdb_get_simple_value_action.gd
@tool
class_name RTDBGetSimpleValueAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Get Simple Value"
	group = "Basic"
	description = "Retrieves a simple value from a predefined test path in RTDB."


func execute() -> Array:
	return await execute_simple_operation(
		"get_value_async",
		RTDBTestPaths.to_variant_array(RTDBTestPaths.SIMPLE_VALUE),
		null,
		action_name
	)
