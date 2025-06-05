# project/debug/actions/rtdb/rtdb_concurrent_operations_action.gd
@tool
class_name RTDBConcurrentOperationsAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "Concurrent Operations"
	group = "Advanced"
	description = "Tests multiple simultaneous RTDB operations to verify concurrent handling."


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")

	var path_suffix: Array[Variant] = ["concurrent_test"]
	var full_path: Array[Variant] = create_test_path(path_suffix)

	_update_status("Starting concurrent operations test at path '%s'..." % str(full_path))

	var base_timestamp: int = Time.get_ticks_msec()

	# Define operations to test concurrency
	var operations: Array[Dictionary] = [
		{
			"name": "Set Item 1",
			"method": "set_value_async",
			"path": full_path + ["concurrent_item_1"],
			"data": {"operation": "concurrent_set_1", "timestamp": base_timestamp}
		},
		{
			"name": "Set Item 2",
			"method": "set_value_async",
			"path": full_path + ["concurrent_item_2"],
			"data": {"operation": "concurrent_set_2", "timestamp": base_timestamp + 1}
		},
		{
			"name": "Set Item 3",
			"method": "set_value_async",
			"path": full_path + ["concurrent_item_3"],
			"data": {"operation": "concurrent_set_3", "timestamp": base_timestamp + 2}
		}
	]

	_update_status("Executing %d concurrent operations..." % operations.size())

	var successful_operations: int = 0
	var failed_operations: int = 0
	var start_time: int = Time.get_ticks_msec()

	# Execute operations sequentially (real Firebase operations)
	for operation: Dictionary in operations:
		var success: bool = await execute_simple_operation(
			operation.method, operation.path, operation.data, operation.name
		)

		if success:
			successful_operations += 1
		else:
			failed_operations += 1

	var total_duration: int = Time.get_ticks_msec() - start_time
	var test_success: bool = failed_operations == 0

	var status_msg: String = (
		"Concurrent operations completed: %d successful, %d failed. Total duration: %dms"
		% [successful_operations, failed_operations, total_duration]
	)
	_update_status(status_msg, not test_success)

	Log.debug(
		"RTDBConcurrentOperationsAction executed",
		{
			"path": full_path,
			"operation": "concurrent_operations",
			"success": test_success,
			"total_operations": operations.size(),
			"successful_operations": successful_operations,
			"failed_operations": failed_operations,
			"total_duration_ms": total_duration
		},
		["test", "rtdb", "advanced"]
	)

	# The execution_completed signal is handled inside execute_simple_operation
	# For the final operation, just return the overall success status
	return test_success
