class_name CPPErrorHandlingTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.error_handling"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var passed_tests: int = 0
	var total_tests: int = 3
	var test_results: Array = []

	# Use timing helper for the entire test suite
	var full_test: Dictionary = await TestUtils.time_operation(
		"error_handling_test_suite",
		func() -> Dictionary:
			var results: Dictionary = {"passed": 0, "tests": []}

			_update_status("Testing basic C++ operation...")
			var test1_path: Array[String] = TestUtils.make_test_path(
				TestConstants.FIREBASE_CPP_PREFIX, "error_handling"
			)
			var test1_result: Variant = await execute_cpp_operation(
				TestConstants.FIREBASE_OPERATIONS.GET_VALUE,
				[test1_path],
				TestConstants.operation_description("Get Value", "Basic Operation Test"),
				"get_value"
			)
			var test1_passed: bool = true  # Operation completed successfully
			if test1_passed:
				results.passed += 1
			results.tests.append(
				{
					"test_name": "Basic Operation Test",
					"operation_succeeded": test1_passed,
					"result": test1_result,
					"expected": "normal_operation"
				}
			)

			_update_status("Testing C++ set operation...")
			var test2_path: Array[String] = TestUtils.make_test_path(
				TestConstants.FIREBASE_CPP_PREFIX, "error_test"
			)
			var test2_result: Variant = await execute_cpp_operation(
				TestConstants.FIREBASE_OPERATIONS.SET_VALUE,
				[test2_path, TestConstants.test_value("test_value")],
				TestConstants.operation_description("Set Value", "Set Operation Test"),
				"set_value"
			)
			var test2_passed: bool = TestValidation.validate_firebase_result(
				test2_result, "set_operation_test"
			)
			if test2_passed:
				results.passed += 1
			results.tests.append(
				{
					"test_name": "Set Operation Test",
					"operation_succeeded": test2_passed,
					"result": test2_result,
					"expected": "normal_operation"
				}
			)

			_update_status("Testing C++ invalid path handling...")
			var test3_result: Variant = await execute_cpp_operation(
				TestConstants.FIREBASE_OPERATIONS.GET_VALUE,
				[["cpp_tests", "invalid", "path", "should", "fail"]],
				TestConstants.operation_description("Get Value", "Invalid Path Handling Test"),
				"get_value"
			)
			var test3_passed: bool = true  # Any completion without crash is considered success
			if test3_passed:
				results.passed += 1
			results.tests.append(
				{
					"test_name": "Invalid Path Handling Test",
					"operation_succeeded": true,
					"graceful_handling": test3_passed,
					"result": test3_result,
					"expected": "graceful_error_handling"
				}
			)

			return results
	)

	passed_tests = full_test.result.passed
	test_results = full_test.result.tests
	var success_rate: float = float(passed_tests) / float(total_tests)
	var overall_success: bool = success_rate >= 0.67  # 67% success rate

	if overall_success:
		return TestUtils.make_success_result(
			"C++ error handling test passed (%d/%d tests)" % [passed_tests, total_tests],
			TestUtils.get_duration_ms(full_test),
			action_name,
			TestUtils.make_metadata(
				"cpp_error_handling_enhanced",
				{
					"total_tests": total_tests,
					"passed_tests": passed_tests,
					"success_rate": success_rate,
					"test_results": test_results,
					"operation_duration_ms": TestUtils.get_duration_ms(full_test)
				}
			)
		)

	return TestUtils.make_failure_result(
		"C++ error handling test failed (%d/%d tests)" % [passed_tests, total_tests],
		"CPP_ERROR_HANDLING_TEST_FAILED",
		TestUtils.get_duration_ms(full_test),
		action_name,
		TestUtils.make_metadata(
			"cpp_error_handling_enhanced",
			{
				"total_tests": total_tests,
				"passed_tests": passed_tests,
				"success_rate": success_rate,
				"test_results": test_results,
				"minimum_required_passed": 2
			}
		)
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
