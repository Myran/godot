class_name CPPConcurrentOperationsTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.concurrent_ops"
	auto_continue = false  # Sequential execution required - concurrent ops need isolation


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var concurrent_count: int = _params.get("concurrent_count", 4)
	var test_data: Array[Dictionary] = []

	# Generate test data using utility functions
	for i: int in range(concurrent_count):
		test_data.append(
			{
				"path":
				TestUtils.make_test_path(TestConstants.FIREBASE_CPP_PREFIX, "concurrent_" + str(i)),
				"value": TestConstants.test_value("Concurrent Test " + str(i)),
				"operation_id": i
			}
		)

	var set_results: Array[Dictionary] = []
	for data: Dictionary in test_data:
		# Use timing helper for each set operation
		var set_op: Dictionary = await TestUtils.time_operation(
			"concurrent_set_" + str(data.operation_id),
			func() -> Variant:
				return await execute_cpp_operation(
					TestConstants.FIREBASE_OPERATIONS.SET_VALUE,
					[data.path, data.value],
					TestConstants.operation_description(
						"Set", "Concurrent " + str(data.operation_id)
					),
					"set_value"
				)
		)

		set_results.append(
			{
				"operation_id": data.operation_id,
				"operation_type": "set",
				"path": data.path,
				"value": data.value,
				"result": set_op.result,
				"success": TestValidation.validate_firebase_result(set_op.result, "concurrent_set"),
				"duration_ms": TestUtils.get_duration_ms(set_op),
				"timestamp": set_op.timestamp
			}
		)

	var get_results: Array[Dictionary] = []
	for data: Dictionary in test_data:
		# Use timing helper for each get operation
		var get_op: Dictionary = await TestUtils.time_operation(
			"concurrent_get_" + str(data.operation_id),
			func() -> Variant:
				return await execute_cpp_operation(
					TestConstants.FIREBASE_OPERATIONS.GET_VALUE,
					[data.path],
					TestConstants.operation_description(
						"Get", "Concurrent " + str(data.operation_id)
					),
					"get_value"
				)
		)

		var value_matches: bool = TestValidation.validate_firebase_result(
			get_op.result, "concurrent_get"
		)
		var retr_val: Variant = null
		if get_op.result != null:
			retr_val = "Retrieved"

		get_results.append(
			{
				"operation_id": data.operation_id,
				"operation_type": "get",
				"path": data.path,
				"expected_value": data.value,
				"retrieved_value": retr_val,
				"result": get_op.result,
				"success": TestValidation.validate_firebase_result(get_op.result, "concurrent_get"),
				"value_matches": value_matches,
				"duration_ms": TestUtils.get_duration_ms(get_op),
				"timestamp": get_op.timestamp
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

	# Calculate total duration from all operations
	var total_duration: int = 0
	for result_dict: Dictionary in all_operation_results:
		total_duration += result_dict.get("duration_ms", 0)

	return DebugActionResult.new_concurrent_result(
		all_operation_results,
		success_rates,
		overall_success,
		action_name,
		total_duration,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.CPP_CONCURRENT_OPS,
			{
				"concurrent_count": concurrent_count,
				"successful_sets": successful_sets,
				"successful_gets": successful_gets,
				"matching_values": matching_values,
				"thresholds": {"success_rate_threshold": 0.8, "value_accuracy_threshold": 0.8}
			}
		)
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
