class_name CPPTimeoutBehaviorTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.timeout_behavior"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Testing C++ basic operations (timeout method removed)...")

	var operation_tests: Array[Dictionary] = []
	var passed_tests: int = 0
	var total_tests: int = 0

	_update_status("Testing basic set operation...")
	var set_result: Variant = await execute_cpp_operation(
		"set_value_async",
		[["cpp_tests", "basic", "set_test", str(Time.get_ticks_msec())], "Basic set test"],
		"Basic Set Test",
		"set_value"
	)

	var set_worked: bool = set_result != null
	operation_tests.append(
		{"test": "Basic Set Operation", "result": set_result, "operation_succeeded": set_worked}
	)
	if set_worked:
		passed_tests += 1
	total_tests += 1

	_update_status("Testing basic get operation...")
	var get_result: Variant = await execute_cpp_operation(
		"get_value_async",
		[["cpp_tests", "basic", "get_test", str(Time.get_ticks_msec())]],
		"Basic Get Test",
		"get_value"
	)

	var get_worked: bool = get_result != null
	operation_tests.append(
		{"test": "Basic Get Operation", "result": get_result, "operation_succeeded": get_worked}
	)
	if get_worked:
		passed_tests += 1
	total_tests += 1

	_update_status("Testing sequential operations...")
	var sequential_success: bool = true
	for i: int in range(3):
		var seq_result: Variant = await execute_cpp_operation(
			"set_value_async",
			[
				["cpp_tests", "basic", "sequential", str(i), str(Time.get_ticks_msec())],
				"Sequential test " + str(i)
			],
			"Sequential Test " + str(i),
			"set_value"
		)
		if seq_result == null:
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
	var total_duration: int = Time.get_ticks_msec() - start_time

	var test_result: Dictionary = {
		"passed_tests": passed_tests,
		"total_tests": total_tests,
		"success_rate": success_rate,
		"overall_success": overall_success,
		"operation_test_details": operation_tests
	}

	if overall_success:
		var success_message: String = (
			"Basic operations test PASSED ("
			+ str(passed_tests)
			+ "/"
			+ str(total_tests)
			+ " operations succeeded)"
		)
		_update_status(success_message)
		return DebugActionResult.new_success(
			success_message, total_duration, action_name, test_result
		)

	var failure_message: String = (
		"Basic operations test FAILED ("
		+ str(passed_tests)
		+ "/"
		+ str(total_tests)
		+ " operations worked)"
	)
	_update_status(failure_message, true)
	return DebugActionResult.new_failure(
		failure_message,
		"TIMEOUT_BEHAVIOR_FAILED",
		DebugActionResult.ErrorCategory.FIREBASE,
		null,
		total_duration,
		action_name,
		test_result
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
