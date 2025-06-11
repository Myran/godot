# project/debug/actions/firebase_cpp/cpp_timeout_behavior_test_action.gd
class_name CPPTimeoutBehaviorTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.timeout_behavior"


func execute_cpp_action() -> bool:
	_update_status("Testing C++ basic operations (timeout method removed)...")

	var operation_tests = []
	var passed_tests = 0
	var total_tests = 0

	# Test 1: Basic set operation
	_update_status("Testing basic set operation...")
	var set_result = await execute_cpp_operation(
		"set_value_async",
		[["cpp_tests", "basic", "set_test", str(Time.get_ticks_msec())], "Basic set test"],
		"Basic Set Test",
		"set_value"
	)

	var set_worked = set_result != null
	operation_tests.append(
		{"test": "Basic Set Operation", "result": set_result, "operation_succeeded": set_worked}
	)
	if set_worked:
		passed_tests += 1
	total_tests += 1

	# Test 2: Basic get operation
	_update_status("Testing basic get operation...")
	var get_result = await execute_cpp_operation(
		"get_value_async",
		[["cpp_tests", "basic", "get_test", str(Time.get_ticks_msec())]],
		"Basic Get Test",
		"get_value"
	)

	var get_worked = get_result != null
	operation_tests.append(
		{"test": "Basic Get Operation", "result": get_result, "operation_succeeded": get_worked}
	)
	if get_worked:
		passed_tests += 1
	total_tests += 1

	# Test 3: Sequential operations
	_update_status("Testing sequential operations...")
	var sequential_success = true
	for i in range(3):
		var seq_result = await execute_cpp_operation(
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

	var success_rate = float(passed_tests) / float(total_tests)
	var overall_success = success_rate >= 0.8  # 80% of operations should work

	var test_result = {
		"passed_tests": passed_tests,
		"total_tests": total_tests,
		"success_rate": success_rate,
		"overall_success": overall_success,
		"operation_test_details": operation_tests
	}

	if overall_success:
		_update_status(
			(
				"Basic operations test PASSED ("
				+ str(passed_tests)
				+ "/"
				+ str(total_tests)
				+ " operations succeeded)"
			)
		)
	else:
		_update_status(
			(
				"Basic operations test FAILED ("
				+ str(passed_tests)
				+ "/"
				+ str(total_tests)
				+ " operations worked)"
			),
			true
		)

	return overall_success

# Removed timeout-related helper methods since timeout functionality was removed
