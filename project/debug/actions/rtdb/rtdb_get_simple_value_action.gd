# project/debug/actions/rtdb/rtdb_get_simple_value_action.gd
@tool
class_name RTDBGetSimpleValueAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Get Simple Value"
	group = "Basic"
	description = "Retrieves a simple value from a predefined test path in RTDB."


func execute() -> Array:
	var path: RTDBTestPaths.Path = RTDBTestPaths.create_path(RTDBTestPaths.SIMPLE_VALUE)
	return await execute_simple_operation("get_value_async", path.as_variants(), null, action_name)
