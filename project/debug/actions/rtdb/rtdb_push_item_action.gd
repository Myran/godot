# project/debug/actions/rtdb/rtdb_push_item_action.gd
@tool
class_name RTDBPushItemAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "Push Item"


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")

	# Use proper test paths with timestamp for uniqueness
	var base_path: Array[String] = ["debug_tests", "rtdb", "push_test"]
	var test_path: Array[Variant] = RTDBTestPaths.to_variant_array(base_path)

	# Create test data with timestamp for uniqueness
	var push_data: Dictionary = {
		"message": "Push Test Item",
		"timestamp": Time.get_unix_time_from_system(),
		"test_id": str(Time.get_ticks_msec())
	}

	var success: bool = await execute_simple_operation(
		"push_value_async", test_path, push_data, action_name
	)

	# The execution_completed signal is handled inside execute_simple_operation
	# Just return the success status for test tracking
	return success
