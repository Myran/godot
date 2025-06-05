# project/debug/actions/rtdb/rtdb_get_simple_value_action.gd
@tool
class_name RTDBGetSimpleValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "Get Simple Value"


func execute_rtdb_action():
	_update_status("Executing " + action_name + "...")

	var path: RTDBTestPaths.Path = RTDBTestPaths.create_path(RTDBTestPaths.SIMPLE_VALUE)
	var success: bool = await execute_simple_operation(
		"get_value_async", path.as_variants(), null, action_name
	)

	# Return the result for the base class test tracking
	return success
