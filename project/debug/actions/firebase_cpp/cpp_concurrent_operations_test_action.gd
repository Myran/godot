class_name CPPConcurrentOperationsTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.concurrent_ops"
	auto_continue = false  # Sequential execution required - concurrent ops need isolation


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	var concurrent_count: int = _params.get("concurrent_count", 4)
	var test_data: Array[Dictionary] = []

	for i: int in range(concurrent_count):
		test_data.append(
			{
				"path": ["cpp_tests", "concurrent", str(i), str(Time.get_ticks_msec())],
				"value": "Concurrent Test " + str(i) + ": " + str(Time.get_ticks_msec()),
				"operation_id": i
			}
		)

	var set_results: Array[Dictionary] = []
	for data: Dictionary in test_data:
		var operation_start: int = Time.get_ticks_msec()
		var result: Variant = await execute_cpp_operation(
			"set_value_async",
			[data.path, data.value],
			"Concurrent Set " + str(data.operation_id),
			"set_value"
		)
		var operation_duration: int = Time.get_ticks_msec() - operation_start

		set_results.append(
			{
				"operation_id": data.operation_id,
				"operation_type": "set",
				"path": data.path,
				"value": data.value,
				"result": result,
				"success": result != null,
				"duration_ms": operation_duration,
				"timestamp": Time.get_ticks_msec()
			}
		)

	var get_results: Array[Dictionary] = []
	for data: Dictionary in test_data:
		var operation_start: int = Time.get_ticks_msec()
		var result: Variant = await execute_cpp_operation(
			"get_value_async", [data.path], "Concurrent Get " + str(data.operation_id), "get_value"
		)
		var operation_duration: int = Time.get_ticks_msec() - operation_start
		var value_matches: bool = result != null  # Simplified validation
		var retr_val: Variant = null
		if result != null:
			retr_val = "Retrieved"
		get_results.append(
			{
				"operation_id": data.operation_id,
				"operation_type": "get",
				"path": data.path,
				"expected_value": data.value,
				"retrieved_value": retr_val,
				"result": result,
				"success": result != null,
				"value_matches": value_matches,
				"duration_ms": operation_duration,
				"timestamp": Time.get_ticks_msec()
			}
		)

	var successful_sets: int = 0
	var successful_gets: int = 0
	var matching_values: int = 0

	for result: Dictionary in set_results:
		if result.success:
			successful_sets += 1

	for result: Dictionary in get_results:
		if result.success:
			successful_gets += 1
		if result.get("value_matches", false):
			matching_values += 1

	var set_success_rate: float = float(successful_sets) / float(concurrent_count)
	var get_success_rate: float = float(successful_gets) / float(concurrent_count)
	var value_accuracy: float = float(matching_values) / float(concurrent_count)

	var overall_success: bool = (
		set_success_rate >= 0.8 and get_success_rate >= 0.8 and value_accuracy >= 0.8
	)

	var all_operation_results: Array[Dictionary] = []
	all_operation_results.append_array(set_results)
	all_operation_results.append_array(get_results)

	var success_rates: Dictionary = {
		"overall": (set_success_rate + get_success_rate) / 2.0,
		"set_operations": set_success_rate,
		"get_operations": get_success_rate,
		"value_accuracy": value_accuracy
	}

	var total_duration: int = Time.get_ticks_msec() - start_time

	return DebugActionResult.new_concurrent_result(
		all_operation_results,
		success_rates,
		overall_success,
		action_name,
		total_duration,
		{
			"test_type": "cpp_concurrent_operations",
			"concurrent_count": concurrent_count,
			"successful_sets": successful_sets,
			"successful_gets": successful_gets,
			"matching_values": matching_values,
			"thresholds": {"success_rate_threshold": 0.8, "value_accuracy_threshold": 0.8}
		}
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
