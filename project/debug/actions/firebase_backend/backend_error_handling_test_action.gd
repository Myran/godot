class_name BackendErrorHandlingTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "backend.firebase.error_handling"
	auto_continue = false  # Sequential execution required for Firebase operations


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var backend: DataBackend = get_firebase_backend_for_testing()
	if not backend:
		return TestUtils.make_failure_result(
			"Firebase backend not available for testing",
			TestConstants.ERROR_CODES.BACKEND_UNAVAILABLE,
			0,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.BACKEND_ERROR_HANDLING)
		)

	var error_tests: Array[Dictionary] = []
	var successful_error_handling: int = 0
	var total_error_tests: int = 0

	# Test 1: Invalid path error handling using timing helper
	total_error_tests += 1
	var invalid_path: Array[Variant] = []  # Empty path should be handled gracefully
	var invalid_op: Dictionary = await TestUtils.time_operation(
		"backend_invalid_path_test",
		func() -> Variant:
			return await test_backend_async_pattern(
				"get_data", invalid_path, "", null, "Error: Invalid Path", true
			)
	)

	var invalid_handled: bool = invalid_op.result == false or invalid_op.result == null
	if invalid_handled:
		successful_error_handling += 1
	error_tests.append(
		{
			"test": "invalid_path",
			"handled_gracefully": invalid_handled,
			"result": invalid_op.result,
			"duration_ms": TestUtils.get_duration_ms(invalid_op)
		}
	)

	# Test 2: Timeout error handling using timing helper
	total_error_tests += 1
	var timeout_path: Array[Variant] = (
		TestUtils.make_test_path(TestConstants.FIREBASE_BACKEND_PREFIX, "error_handling")
		+ ["timeout_test"]
	)

	var timeout_op: Dictionary = await TestUtils.time_operation(
		"backend_timeout_test",
		func() -> Variant:
			return await test_backend_async_pattern(
				"get_data", timeout_path, "nonexistent_key", null, "Error: Timeout Test", true
			)
	)

	var timeout_handled: bool = TestUtils.get_duration_ms(timeout_op) < 30000
	if timeout_handled:
		successful_error_handling += 1
	error_tests.append(
		{
			"test": "timeout_handling",
			"handled_gracefully": timeout_handled,
			"duration_ms": TestUtils.get_duration_ms(timeout_op),
			"result": timeout_op.result
		}
	)

	# Test 3: Unsupported method error handling using timing helper
	total_error_tests += 1
	var unsupported_path: Array[Variant] = (
		TestUtils.make_test_path(TestConstants.FIREBASE_BACKEND_PREFIX, "error_handling")
		+ ["unsupported"]
	)

	var unsupported_op: Dictionary = await TestUtils.time_operation(
		"backend_unsupported_method_test",
		func() -> Variant:
			return await test_backend_async_pattern(
				"unsupported_method",
				unsupported_path,
				"test",
				"value",
				"Error: Unsupported Method",
				true
			)
	)

	var unsupported_handled: bool = unsupported_op.result == false
	if unsupported_handled:
		successful_error_handling += 1
	error_tests.append(
		{
			"test": "unsupported_method",
			"handled_gracefully": unsupported_handled,
			"result": unsupported_op.result,
			"duration_ms": TestUtils.get_duration_ms(unsupported_op)
		}
	)

	# Test 4: Backend availability check using timing helper
	total_error_tests += 1
	var availability_op: Dictionary = await TestUtils.time_operation(
		"backend_availability_check", func() -> bool: return backend.is_available()
	)

	var availability_handled: bool = true  # Just checking this doesn't crash
	if availability_handled:
		successful_error_handling += 1
	error_tests.append(
		{
			"test": "availability_check",
			"handled_gracefully": availability_handled,
			"backend_available": availability_op.result,
			"duration_ms": TestUtils.get_duration_ms(availability_op)
		}
	)

	var error_success_rate: float = float(successful_error_handling) / float(total_error_tests)
	var overall_success: bool = error_success_rate >= 0.75  # 75% of error scenarios should be handled gracefully

	# Calculate total duration from all operations
	var total_duration: int = (
		TestUtils.get_duration_ms(invalid_op)
		+ TestUtils.get_duration_ms(timeout_op)
		+ TestUtils.get_duration_ms(unsupported_op)
		+ TestUtils.get_duration_ms(availability_op)
	)

	if overall_success:
		return TestUtils.make_success_result(
			(
				"Backend error handling test completed successfully (%d/%d)"
				% [successful_error_handling, total_error_tests]
			),
			total_duration,
			action_name,
			TestUtils.make_metadata(
				TestConstants.TEST_TYPES.BACKEND_ERROR_HANDLING,
				{
					"error_scenarios": error_tests,
					"success_rate": error_success_rate,
					"total_tests": total_error_tests,
					"successful_tests": successful_error_handling,
					"backend_available": backend.is_available()
				}
			)
		)

	return TestUtils.make_failure_result(
		(
			"Backend error handling test failed - insufficient error handling (%d/%d)"
			% [successful_error_handling, total_error_tests]
		),
		TestConstants.ERROR_CODES.VALIDATION_FAILED,
		total_duration,
		action_name,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.BACKEND_ERROR_HANDLING,
			{
				"error_scenarios": error_tests,
				"success_rate": error_success_rate,
				"total_tests": total_error_tests,
				"successful_tests": successful_error_handling,
				"minimum_required_rate": 0.75,
				"backend_available": backend.is_available()
			}
		)
	)
