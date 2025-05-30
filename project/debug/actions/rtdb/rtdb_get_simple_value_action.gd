# project/debug/actions/rtdb/rtdb_get_simple_value_action.gd
@tool
class_name RTDBGetSimpleValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "Get Simple Value"
	group = "Basic"
	description = "Retrieves a simple value from a predefined test path in RTDB."


func execute() -> void:
	_update_status("Executing " + action_name + "...")

	var path: RTDBTestPaths.Path = RTDBTestPaths.create_path(RTDBTestPaths.SIMPLE_VALUE)
	var result: Array = await execute_simple_operation(
		"get_value_async", path.as_variants(), null, action_name
	)

	# Emit completion signal based on result
	var success: bool = result[0] if result.size() > 0 else false
	var payload: Variant = result[1] if result.size() > 1 else null
	execution_completed.emit(success, payload)
