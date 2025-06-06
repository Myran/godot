# project/debug/actions/firebase_cpp/cpp_error_handling_test_action.gd
@tool
class_name CPPErrorHandlingTestAction
extends "res://debug/actions/firebase_cpp/cpp_firebase_debug_action.gd"

func _init() -> void:
	super._init()
	action_name = "C++ Error Handling Test"

func execute_cpp_action() -> bool:
	_update_status("Testing C++ error handling scenarios...")
	
	var error_tests = []
	var passed_tests = 0
	var total_tests = 0
	
	# Test 1: Invalid path characters
	_update_status("Testing invalid path characters...")
	var invalid_path_result = await execute_cpp_operation_with_timeout(
		"get_value_async",
		[["cpp_tests", "invalid.path.test", "with$pecial@characters"]],
		3.0,
		"Invalid Path Test"
	)
	
	var invalid_path_handled = _is_error_properly_handled(invalid_path_result, "Invalid path characters")
	error_tests.append({
		"test": "Invalid Path Characters",
		"result": invalid_path_result,
		"handled_correctly": invalid_path_handled
	})
	if invalid_path_handled: passed_tests += 1
	total_tests += 1
	
	# Test 2: Very long path
	_update_status("Testing extremely long path...")
	var long_segment = "very_long_segment_" + "x".repeat(500)  # Create very long path segment
	var long_path_result = await execute_cpp_operation_with_timeout(
		"get_value_async",
		[["cpp_tests", "long_path", long_segment]],
		3.0,
		"Long Path Test"
	)
	
	var long_path_handled = _is_error_properly_handled(long_path_result, "Very long path")
	error_tests.append({
		"test": "Very Long Path",
		"result": long_path_result,
		"handled_correctly": long_path_handled
	})
	if long_path_handled: passed_tests += 1
	total_tests += 1
	
	# Test 3: Null path
	_update_status("Testing null/empty path...")
	var empty_path_result = await execute_cpp_operation_with_timeout(
		"get_value_async",
		[[]],  # Empty path array
		3.0,
		"Empty Path Test"
	)
	
	var empty_path_handled = _is_error_properly_handled(empty_path_result, "Empty path")
	error_tests.append({
		"test": "Empty Path",
		"result": empty_path_result,
		"handled_correctly": empty_path_handled
	})
	if empty_path_handled: passed_tests += 1
	total_tests += 1
	
	# Test 4: Timeout scenario (very short timeout)
	_update_status("Testing timeout handling...")
	var timeout_result = await execute_cpp_operation_with_timeout(
		"set_value_async",
		[["cpp_tests", "timeout_test", str(Time.get_ticks_msec())], "Timeout test value"],
		0.1,  # Very short timeout to force timeout
		"Timeout Test"
	)
	
	var timeout_handled = timeout_result.get("code") == "TIMEOUT"
	error_tests.append({
		"test": "Timeout Handling",
		"result": timeout_result,
		"handled_correctly": timeout_handled
	})
	if timeout_handled: passed_tests += 1
	total_tests += 1
	
	var success_rate = float(passed_tests) / float(total_tests)
	var overall_success = success_rate >= 0.75  # 75% of error scenarios should be handled correctly
	
	var test_result = {
		"passed_tests": passed_tests,
		"total_tests": total_tests,
		"success_rate": success_rate,
		"overall_success": overall_success,
		"error_test_details": error_tests
	}
	
	if overall_success:
		_update_status("Error handling test PASSED (" + str(passed_tests) + "/" + str(total_tests) + " scenarios handled correctly)")
	else:
		_update_status("Error handling test FAILED (" + str(passed_tests) + "/" + str(total_tests) + " scenarios handled)", true)
	
	execution_completed.emit(overall_success, test_result)
	return overall_success

# Helper function to determine if an error was properly handled
func _is_error_properly_handled(result: Dictionary, test_name: String) -> bool:
	var status = result.get("status", "")
	var code = result.get("code", "")
	
	# Check if it's a proper error response (not success and has error code)
	var is_error = status == "error" and not code.is_empty()
	
	# Also accept timeout as proper error handling
	var is_timeout = code == "TIMEOUT"
	
	# Check if C++ properly returned error data
	var has_error_data = result.has("result") and result.get("result") is Dictionary and result.get("result").has("error_code")
	
	var properly_handled = is_error or is_timeout or has_error_data
	
	Log.debug("Error handling evaluation", {
		"test": test_name,
		"status": status,
		"code": code,
		"properly_handled": properly_handled,
		"result": result
	}, ["debug", "cpp_firebase"])
	
	return properly_handled
