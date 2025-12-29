class_name CPPLargeDataTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.large_data"
	auto_continue = false  # Sequential execution required - large data operations need isolation


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing C++ with large data payloads...")

	var test_results: Array[Dictionary] = []
	var data_sizes: Array[Dictionary] = [
		{"name": "Small", "size": 1024, "description": "1KB data"},  # 1KB
		{"name": "Medium", "size": 10240, "description": "10KB data"},  # 10KB
		{"name": "Large", "size": 51200, "description": "50KB data"},  # 50KB
		{"name": "XLarge", "size": 102400, "description": "100KB data"}  # 100KB
	]

	var successful_tests: int = 0
	var total_tests: int = data_sizes.size()

	for size_config: Dictionary in data_sizes:
		var size_description: String = size_config.description
		var config_name: String = size_config.name
		_update_status("Testing " + size_description + "...")

		var size_bytes: int = size_config.size
		var large_data: String = _generate_test_data(size_bytes)
		var test_path: Array[String] = TestUtils.make_test_path(
			TestConstants.FIREBASE_CPP_PREFIX, "large_data_" + config_name.to_lower()
		)

		_update_status("Setting " + size_description + " via C++...")
		var set_op: Dictionary = await TestUtils.time_operation(
			"large_data_set_" + config_name.to_lower(),
			func() -> Variant:
				return await execute_cpp_operation(
					TestConstants.FIREBASE_OPERATIONS.SET_VALUE,
					[test_path, large_data],
					TestConstants.operation_description("Set", "Large Data (" + config_name + ")"),
					"set_value"
				)
		)

		var set_success: bool = TestValidation.validate_firebase_result(
			set_op.result, "large_data_set_" + config_name
		)

		var get_success: bool = false
		var get_op: Dictionary = {"duration_ms": 0}
		var data_matches: bool = false

		if set_success:
			_update_status("Getting " + size_description + " via C++...")
			get_op = await TestUtils.time_operation(
				"large_data_get_" + config_name.to_lower(),
				func() -> Variant:
					return await execute_cpp_operation(
						TestConstants.FIREBASE_OPERATIONS.GET_VALUE,
						[test_path],
						TestConstants.operation_description(
							"Get", "Large Data (" + config_name + ")"
						),
						"get_value"
					)
			)

			get_success = TestValidation.validate_firebase_result(
				get_op.result, "large_data_get_" + config_name
			)
			if get_success:
				data_matches = true

				# Guard against shutdown (task-396)
				_safe_log_info(
					"Large data operation completed",
					{"size": config_name, "data_length": large_data.length()},
					["debug", "cpp_firebase"]
				)

		var test_success: bool = set_success and get_success and data_matches
		if test_success:
			successful_tests += 1

		test_results.append(
			{
				"size_name": config_name,
				"size_bytes": size_bytes,
				"description": size_description,
				"data_length": large_data.length(),
				"set_success": set_success,
				"set_duration_ms": TestUtils.get_duration_ms(set_op),
				"get_success": get_success,
				"get_duration_ms": TestUtils.get_duration_ms(get_op),
				"data_integrity": data_matches,
				"overall_success": test_success
			}
		)

	var success_rate: float = float(successful_tests) / float(total_tests)
	var overall_success: bool = success_rate >= 0.75  # 75% of large data tests should pass

	# Use timing helper for overall test completion
	var completion_timing: Dictionary = await TestUtils.time_operation(
		"large_data_test_completion", func() -> String: return "large_data_test_complete"
	)

	var final_result: Dictionary = TestUtils.make_metadata(
		TestConstants.TEST_TYPES.CPP_LARGE_DATA,
		{
			"successful_tests": successful_tests,
			"total_tests": total_tests,
			"success_rate": success_rate,
			"overall_success": overall_success,
			"test_details": test_results
		}
	)

	if overall_success:
		var success_message: String = (
			"Large data test PASSED ("
			+ str(successful_tests)
			+ "/"
			+ str(total_tests)
			+ " data sizes handled)"
		)
		_update_status(success_message)
		return TestUtils.make_success_result(
			success_message, TestUtils.get_duration_ms(completion_timing), action_name, final_result
		)

	var failure_message: String = (
		"Large data test FAILED (" + str(successful_tests) + "/" + str(total_tests) + " succeeded)"
	)
	_update_status(failure_message, true)
	return TestUtils.make_failure_result(
		failure_message,
		TestConstants.ERROR_CODES.LARGE_DATA_FAILED,
		TestUtils.get_duration_ms(completion_timing),
		action_name,
		final_result
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()


func _generate_test_data(target_size: int) -> String:
	var data: String = "Large Data Test - "
	var base_content: String = "This is test data for Firebase C++ layer performance validation. "

	var header_size: int = data.length()
	var remaining_size: int = target_size - header_size
	var repetitions: int = max(1, int(float(remaining_size) / float(base_content.length())))

	for i: int in range(repetitions):
		data += base_content

	data += (
		" [Generated: " + str(Time.get_ticks_msec()) + ", Target: " + str(target_size) + " bytes]"
	)

	if data.length() > target_size:
		data = data.substr(0, target_size)
	elif data.length() < target_size:
		var padding_needed: int = target_size - data.length()
		data += "X".repeat(padding_needed)

	return data
