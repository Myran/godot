class_name BackendErrorHandlingTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "backend.firebase.error_handling"
	auto_continue = false  # Sequential execution required for Firebase operations


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Testing Firebase Backend error handling...")

	var backend: DataBackend = get_firebase_backend_for_testing()
	if not backend:
		return DebugActionResult.new_failure(
			"Firebase backend not available for testing",
			"BACKEND_UNAVAILABLE",
			DebugActionResult.ErrorCategory.DATABASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)

	var error_tests: Array[Dictionary] = []
	var successful_error_handling: int = 0
	var total_error_tests: int = 0

	_update_status("Testing invalid path error handling...")
	total_error_tests += 1
	var invalid_path: Array[Variant] = []  # Empty path should be handled gracefully
	var invalid_result: Variant
	invalid_result = await test_backend_async_pattern(
		"get_data", invalid_path, "", null, "Error: Invalid Path"
	)

	var invalid_handled: bool = invalid_result == false or invalid_result == null
	if invalid_handled:
		successful_error_handling += 1
	error_tests.append(
		{"test": "invalid_path", "handled_gracefully": invalid_handled, "result": invalid_result}
	)

	_update_status("Testing timeout error handling...")
	total_error_tests += 1
	var timeout_path: Array[Variant] = [
		"backend_tests", "error_handling", "timeout_test", str(Time.get_ticks_msec())
	]

	var timeout_start_time: int = Time.get_ticks_msec()
	var timeout_result: Variant
	timeout_result = await test_backend_async_pattern(
		"get_data", timeout_path, "nonexistent_key", null, "Error: Timeout Test"
	)
	var timeout_duration: int = Time.get_ticks_msec() - timeout_start_time

	var timeout_handled: bool = timeout_duration < 30000  # Should not hang for more than 30 seconds
	if timeout_handled:
		successful_error_handling += 1
	error_tests.append(
		{
			"test": "timeout_handling",
			"handled_gracefully": timeout_handled,
			"duration_ms": timeout_duration,
			"result": timeout_result
		}
	)

	_update_status("Testing unsupported method error handling...")
	total_error_tests += 1
	var unsupported_path: Array[Variant] = ["backend_tests", "error_handling", "unsupported"]

	var unsupported_result: Variant
	unsupported_result = await test_backend_async_pattern(
		"unsupported_method", unsupported_path, "test", "value", "Error: Unsupported Method"
	)

	var unsupported_handled: bool = unsupported_result == false
	if unsupported_handled:
		successful_error_handling += 1
	error_tests.append(
		{
			"test": "unsupported_method",
			"handled_gracefully": unsupported_handled,
			"result": unsupported_result
		}
	)

	_update_status("Testing backend availability error handling...")
	total_error_tests += 1
	var availability_check: bool = backend.is_available()
	var availability_handled: bool = true  # Just checking this doesn't crash
	if availability_handled:
		successful_error_handling += 1
	error_tests.append(
		{
			"test": "availability_check",
			"handled_gracefully": availability_handled,
			"backend_available": availability_check
		}
	)

	var error_success_rate: float = float(successful_error_handling) / float(total_error_tests)
	var overall_success: bool = error_success_rate >= 0.75  # 75% of error scenarios should be handled gracefully
	var total_duration: int = Time.get_ticks_msec() - start_time

	var test_results: Dictionary = {
		"total_error_tests": total_error_tests,
		"successful_error_handling": successful_error_handling,
		"error_success_rate": error_success_rate,
		"error_test_details": error_tests,
		"error_handling_validation": overall_success,
		"backend_available": backend.is_available()
	}

	if overall_success:
		_update_status(
			(
				"Error Handling test PASSED ("
				+ str(successful_error_handling)
				+ "/"
				+ str(total_error_tests)
				+ ")"
			)
		)
		Log.info(
			"Backend error handling validation successful",
			test_results,
			["debug", "backend_firebase"]
		)

		return DebugActionResult.new_success(
			"Backend error handling test completed successfully",
			total_duration,
			action_name,
			{
				"test_type": "backend_error_handling",
				"error_scenarios": error_tests,
				"success_rate": error_success_rate,
				"total_tests": total_error_tests,
				"successful_tests": successful_error_handling
			}
		)

	_update_status(
		(
			"Error Handling test FAILED ("
			+ str(successful_error_handling)
			+ "/"
			+ str(total_error_tests)
			+ ")"
		),
		true
	)
	Log.error(
		"Backend error handling validation failed",
		test_results,
		["debug", "backend_firebase", "error"]
	)

	return DebugActionResult.new_failure(
		"Backend error handling test failed - insufficient error handling",
		"ERROR_HANDLING_INSUFFICIENT",
		DebugActionResult.ErrorCategory.VALIDATION,
		test_results,
		total_duration,
		action_name,
		{
			"test_type": "backend_error_handling",
			"error_scenarios": error_tests,
			"success_rate": error_success_rate,
			"total_tests": total_error_tests,
			"successful_tests": successful_error_handling,
			"minimum_required_rate": 0.75
		}
	)
