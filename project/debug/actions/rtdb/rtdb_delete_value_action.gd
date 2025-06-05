# project/debug/actions/rtdb/rtdb_delete_value_action.gd
@tool
class_name RTDBDeleteValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "Delete Value"


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")
	var success: bool = await execute_simple_operation(
		"remove_value_async",
		RTDBTestPaths.to_variant_array(RTDBTestPaths.SIMPLE_VALUE),
		null,
		action_name
	)

	# The execution_completed signal is handled inside execute_simple_operation
	# Just return the success status for test tracking
	return success
