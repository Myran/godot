class_name RTDBConcurrentOperationsAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.advanced.concurrent_ops"
	group = "Advanced"
	description = "Tests multiple simultaneous RTDB operations to verify concurrent handling."


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	var path_suffix: Array[Variant] = ["concurrent_test"]
	var full_path: Array[Variant] = create_test_path(path_suffix)
	var base_timestamp: int = Time.get_ticks_msec()

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

	for operation: Dictionary in operations:
		var operation_start_time: int = Time.get_ticks_msec()
		var method_str: String = operation["method"]
		var path_array: Array = operation["path"]
		var data_variant: Variant = operation["data"]
		var name_str: String = operation["name"]
		var success: bool = await execute_simple_operation(
			method_str, path_array, data_variant, name_str
		)
		var operation_duration: int = Time.get_ticks_msec() - operation_start_time

		var operation_result: Dictionary = {
			"name": name_str,
			"method": method_str,
			"path": path_array,
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

	var success_rates: Dictionary = {"overall": success_rate, "set_operations": success_rate}

	return DebugActionResult.new_concurrent_result(
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


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
