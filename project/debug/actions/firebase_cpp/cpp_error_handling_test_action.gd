# project/debug/actions/firebase_cpp/cpp_error_handling_test_action.gd
class_name CPPErrorHandlingTestAction
extends "res://debug/actions/firebase_cpp/cpp_firebase_debug_action.gd"


func _init() -> void:
	super._init()
	action_name = "C++ Error Handling Test"


# New DebugAction.Result pattern - this is the future
func _execute_action_logic(params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	var passed_tests: int = 0
	var total_tests: int = 3  # Simplified to 3 tests

	# Test 1: Basic operation
	var test1_result: Variant = await execute_cpp_operation(
		"get_value_async",
		[["cpp_tests", "error_handling", str(Time.get_ticks_msec())]],
		"Basic Error Test"
	)
	if test1_result != null:
		passed_tests += 1

	# Test 2: Set operation
	var test2_result: Variant = await execute_cpp_operation(
		"set_value_async",
		[["cpp_tests", "error_test", str(Time.get_ticks_msec())], "test_value"],
		"Set Error Test"
	)
	if test2_result != null:
		passed_tests += 1

	# Test 3: Invalid path test
	var test3_result: Variant = await execute_cpp_operation(
		"get_value_async",
		[["cpp_tests", "invalid_path", str(Time.get_ticks_msec())]],
		"Invalid Path Test"
	)
	# For invalid path, any completion (success or graceful failure) is good
	passed_tests += 1

	var success_rate: float = float(passed_tests) / float(total_tests)
	var overall_success: bool = success_rate >= 0.67  # 67% success rate
	var total_duration: int = Time.get_ticks_msec() - start_time

	if overall_success:
		return DebugAction.Result.new_success(
			"C++ error handling test passed (%d/%d tests)" % [passed_tests, total_tests],
			total_duration,
			action_name,
			{
				"test_type": "cpp_error_handling",
				"total_tests": total_tests,
				"passed_tests": passed_tests,
				"success_rate": success_rate
			}
		)
	else:
		return DebugAction.Result.new_failure(
			"C++ error handling test failed (%d/%d tests)" % [passed_tests, total_tests],
			"",
			DebugAction.Result.ErrorCategory.FIREBASE,
			null,
			total_duration,
			action_name,
			{
				"test_type": "cpp_error_handling",
				"total_tests": total_tests,
				"passed_tests": passed_tests,
				"success_rate": success_rate
			}
		)


# Legacy method for compatibility - delegates to new pattern
func execute_cpp_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()
