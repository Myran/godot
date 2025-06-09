# project/debug/actions/rtdb/rtdb_concurrent_operations_action.gd
class_name RTDBConcurrentOperationsAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "Concurrent Operations"
	group = "Advanced"
	description = "Tests multiple simultaneous RTDB operations to verify concurrent handling."


# New DebugAction.Result pattern - this is the future
func _execute_action_logic(params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()

	var path_suffix: Array[Variant] = ["concurrent_test"]
	var full_path: Array[Variant] = create_test_path(path_suffix)
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

	var operation_results: Array[Dictionary] = []
	var successful_operations: int = 0
	var failed_operations: int = 0

	# Execute operations sequentially (real Firebase operations)
	for operation: Dictionary in operations:
		var operation_start_time: int = Time.get_ticks_msec()
		var success: bool = await execute_simple_operation(
			operation.method, operation.path, operation.data, operation.name
		)
		var operation_duration: int = Time.get_ticks_msec() - operation_start_time

		var operation_result: Dictionary = {
			"name": operation.name,
			"method": operation.method,
			"path": operation.path,
			"success": success,
			"duration_ms": operation_duration,
			"timestamp": Time.get_ticks_msec()
		}
		operation_results.append(operation_result)

		if success:
			successful_operations += 1
		else:
			failed_operations += 1

	var total_duration: int = Time.get_ticks_msec() - start_time
	var total_operations: int = operations.size()
	var success_rate: float = (
		float(successful_operations) / float(total_operations) if total_operations > 0 else 0.0
	)
	var overall_success: bool = failed_operations == 0

	# Calculate success rates by operation type
	var success_rates: Dictionary = {"overall": success_rate, "set_operations": success_rate}  # All operations are sets in this test

	# Use the new specialized factory method for concurrent results
	return DebugAction.Result.new_concurrent_result(
		operation_results,
		success_rates,
		overall_success,
		action_name,
		total_duration,
		{
			"test_type": "concurrent_operations",
			"test_path": full_path,
			"base_timestamp": base_timestamp,
			"operations_count": total_operations
		}
	)


# Legacy method for compatibility - delegates to new pattern
func execute_rtdb_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()
