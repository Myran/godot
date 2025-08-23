class_name CPPLargeDataTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.large_data"


func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
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
		var test_path: Array[String] = [
			"cpp_tests", "large_data", config_name.to_lower(), str(Time.get_ticks_msec())
		]

		_update_status("Setting " + size_description + " via C++...")
		var set_start_time: int = Time.get_ticks_msec()
		var set_result: Variant = await execute_cpp_operation(
			"set_value_async",
			[test_path, large_data],
			"Large Data Set (" + config_name + ")",
			"set_value"
		)
		var set_duration: int = Time.get_ticks_msec() - set_start_time

		var set_success: bool = set_result != null

		var get_success: bool = false
		var get_duration: int = 0
		var data_matches: bool = false

		if set_success:
			_update_status("Getting " + size_description + " via C++...")
			var get_start_time: int = Time.get_ticks_msec()
			var get_result: Variant = await execute_cpp_operation(
				"get_value_async", [test_path], "Large Data Get (" + config_name + ")", "get_value"
			)
			get_duration = Time.get_ticks_msec() - get_start_time

			get_success = get_result != null
			if get_success:
				data_matches = true

				Log.info(
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
				"set_duration_ms": set_duration,
				"get_success": get_success,
				"get_duration_ms": get_duration,
				"data_integrity": data_matches,
				"overall_success": test_success
			}
		)

	var success_rate: float = float(successful_tests) / float(total_tests)
	var overall_success: bool = success_rate >= 0.75  # 75% of large data tests should pass
	var total_duration: int = Time.get_ticks_msec() - start_time

	var final_result: Dictionary = {
		"successful_tests": successful_tests,
		"total_tests": total_tests,
		"success_rate": success_rate,
		"overall_success": overall_success,
		"test_details": test_results
	}

	if overall_success:
		var success_message: String = (
			"Large data test PASSED ("
			+ str(successful_tests)
			+ "/"
			+ str(total_tests)
			+ " data sizes handled)"
		)
		_update_status(success_message)
		return DebugAction.Result.new_success(
			success_message, total_duration, action_name, final_result
		)

	var failure_message: String = (
		"Large data test FAILED (" + str(successful_tests) + "/" + str(total_tests) + " succeeded)"
	)
	_update_status(failure_message, true)
	return DebugAction.Result.new_failure(
		failure_message,
		"LARGE_DATA_FAILED",
		DebugAction.Result.ErrorCategory.FIREBASE,
		null,
		total_duration,
		action_name,
		final_result
	)


func execute_cpp_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
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
