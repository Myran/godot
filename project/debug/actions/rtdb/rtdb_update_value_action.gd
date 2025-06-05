# project/debug/actions/rtdb/rtdb_update_value_action.gd
@tool
class_name RTDBUpdateValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "Update Value"


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")

	var path_suffix: Array[Variant] = ["update_test"]
	var test_value: String = "Updated Value: " + str(Time.get_ticks_msec())

	var success: bool = await execute_simple_operation(
		"set_value_async", create_test_path(path_suffix), test_value, action_name
	)

	# The execution_completed signal is handled inside execute_simple_operation
	# Just return the success status for test tracking
	return success
