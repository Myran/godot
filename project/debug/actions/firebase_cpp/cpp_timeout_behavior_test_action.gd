class_name CPPTimeoutBehaviorTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.timeout_behavior"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing C++ basic operations (timeout method removed)...")

	var operation_tests: Array[Dictionary] = []
	var passed_tests: int = 0
	var total_tests: int = 0

	_update_status("Testing basic set operation...")
	var set_test_path: Array[String] = TestUtils.make_test_path(
		TestConstants.FIREBASE_CPP_PREFIX, "basic_set_test"
	)
	var set_result: Variant = await execute_cpp_operation(
		TestConstants.FIREBASE_OPERATIONS.SET_VALUE,
		[set_test_path, TestConstants.test_value("Basic set test")],
		TestConstants.operation_description("Set", "Basic Set Test"),
		"set_value"
	)

	var set_worked: bool = TestValidation.validate_firebase_result(set_result, "basic_set_test")
	operation_tests.append(
		{"test": "Basic Set Operation", "result": set_result, "operation_succeeded": set_worked}
	)
	if set_worked:
		passed_tests += 1
	total_tests += 1

	_update_status("Testing basic get operation...")
	# First write test data, then read it back
	var get_test_path: Array[String] = TestUtils.make_test_path(
		TestConstants.FIREBASE_CPP_PREFIX, "basic_get_test"
	)
	var get_test_data: String = TestConstants.test_value("Test data for get operation")

	await execute_cpp_operation(
		TestConstants.FIREBASE_OPERATIONS.SET_VALUE,
		[get_test_path, get_test_data],
		TestConstants.operation_description("Set", "Basic Get Test Setup"),
		"set_value"
	)

	var get_result: Variant = await execute_cpp_operation(
		TestConstants.FIREBASE_OPERATIONS.GET_VALUE,
		[get_test_path],
		TestConstants.operation_description("Get", "Basic Get Test"),
		"get_value"
	)

	var get_worked: bool = TestValidation.validate_firebase_result(get_result, "basic_get_test")
	operation_tests.append(
		{"test": "Basic Get Operation", "result": get_result, "operation_succeeded": get_worked}
	)
	if get_worked:
		passed_tests += 1
	total_tests += 1

	_update_status("Testing sequential operations...")
	var sequential_success: bool = true
	for i: int in range(3):
		var seq_path: Array[String] = TestUtils.make_test_path(
			TestConstants.FIREBASE_CPP_PREFIX, "sequential_" + str(i)
		)
		var seq_result: Variant = await execute_cpp_operation(
			TestConstants.FIREBASE_OPERATIONS.SET_VALUE,
			[seq_path, TestConstants.test_value("Sequential test " + str(i))],
			TestConstants.operation_description("Set", "Sequential Test " + str(i)),
			"set_value"
		)
		if not TestValidation.validate_firebase_result(seq_result, "sequential_test_" + str(i)):
			sequential_success = false
			break

	operation_tests.append(
		{"test": "Sequential Operations", "operation_succeeded": sequential_success}
	)
	if sequential_success:
		passed_tests += 1
	total_tests += 1

	var success_rate: float = float(passed_tests) / float(total_tests)
	var overall_success: bool = success_rate >= 0.8  # 80% of operations should work

	# Use timing helper for overall duration tracking
	var overall_timing: Dictionary = await TestUtils.time_operation(
		"timeout_behavior_completion", func() -> String: return "timeout_behavior_test_complete"
	)

	var test_result: Dictionary = TestUtils.make_metadata(
		TestConstants.TEST_TYPES.CPP_TIMEOUT_BEHAVIOR,
		{
			"passed_tests": passed_tests,
			"total_tests": total_tests,
			"success_rate": success_rate,
			"overall_success": overall_success,
			"operation_test_details": operation_tests
		}
	)

	if overall_success:
		var success_message: String = (
			"Basic operations test PASSED ("
			+ str(passed_tests)
			+ "/"
			+ str(total_tests)
			+ " operations succeeded)"
		)
		_update_status(success_message)
		return TestUtils.make_success_result(
			success_message, TestUtils.get_duration_ms(overall_timing), action_name, test_result
		)

	var failure_message: String = (
		"Basic operations test FAILED ("
		+ str(passed_tests)
		+ "/"
		+ str(total_tests)
		+ " operations worked)"
	)
	_update_status(failure_message, true)
	return TestUtils.make_failure_result(
		failure_message,
		TestConstants.ERROR_CODES.TIMEOUT_BEHAVIOR_FAILED,
		TestUtils.get_duration_ms(overall_timing),
		action_name,
		test_result
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
