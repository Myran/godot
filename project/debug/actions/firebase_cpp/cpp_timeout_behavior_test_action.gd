# project/debug/actions/firebase_cpp/cpp_timeout_behavior_test_action.gd
@tool
class_name CPPTimeoutBehaviorTestAction
extends "res://debug/actions/firebase_cpp/cpp_firebase_debug_action.gd"

func _init() -> void:
	super._init()
	action_name = "C++ Timeout Behavior Test"

func execute_cpp_action() -> bool:
	_update_status("Testing C++ timeout behavior scenarios...")
	
	var timeout_tests = []
	var passed_tests = 0
	var total_tests = 0
	
	# Test 1: Very short timeout (should trigger timeout)
	_update_status("Testing very short timeout...")
	var short_timeout_result = await execute_cpp_operation_with_timeout(
		"set_value_async",
		[["cpp_tests", "timeout", "very_short", str(Time.get_ticks_msec())], "Short timeout test"],
		0.05,  # 50ms - very short timeout
		"Very Short Timeout Test"
	)
	
	var short_timeout_worked = short_timeout_result.get("code") == "TIMEOUT"
	timeout_tests.append({
		"test": "Very Short Timeout (50ms)",
		"result": short_timeout_result,
		"timeout_triggered": short_timeout_worked,
		"expected_timeout": true
	})
	if short_timeout_worked: passed_tests += 1
	total_tests += 1
	
	# Test 2: Reasonable timeout (should succeed)
	_update_status("Testing reasonable timeout...")
	var normal_timeout_result = await execute_cpp_operation_with_timeout(
		"set_value_async",
		[["cpp_tests", "timeout", "normal", str(Time.get_ticks_msec())], "Normal timeout test"],
		5.0,  # 5 seconds - reasonable timeout
		"Normal Timeout Test"
	)
	
	var normal_timeout_worked = normal_timeout_result.get("status") == "success"
	timeout_tests.append({
		"test": "Normal Timeout (5s)",
		"result": normal_timeout_result,
		"operation_succeeded": normal_timeout_worked,
		"expected_timeout": false
	})
	if normal_timeout_worked: passed_tests += 1
	total_tests += 1
	
	# Test 3: Long timeout (should succeed but test patience)
	_update_status("Testing long timeout...")
	var long_timeout_result = await execute_cpp_operation_with_timeout(
		"set_value_async",
		[["cpp_tests", "timeout", "long", str(Time.get_ticks_msec())], "Long timeout test"],
		10.0,  # 10 seconds - long timeout
		"Long Timeout Test"
	)
	
	var long_timeout_worked = long_timeout_result.get("status") == "success"
	timeout_tests.append({
		"test": "Long Timeout (10s)",
		"result": long_timeout_result,
		"operation_succeeded": long_timeout_worked,
		"expected_timeout": false
	})
	if long_timeout_worked: passed_tests += 1
	total_tests += 1
	
	# Test 4: Multiple operations with different timeouts
	_update_status("Testing mixed timeout scenarios...")
	var mixed_results = await _test_mixed_timeouts()
	
	var mixed_timeout_worked = mixed_results.get("success", false)
	timeout_tests.append({
		"test": "Mixed Timeout Scenarios",
		"result": mixed_results,
		"scenario_handled": mixed_timeout_worked,
		"expected_timeout": "mixed"
	})
	if mixed_timeout_worked: passed_tests += 1
	total_tests += 1
	
	# Test 5: Timeout cleanup (ensure no memory leaks)
	_update_status("Testing timeout cleanup...")
	var cleanup_result = await _test_timeout_cleanup()
	
	var cleanup_worked = cleanup_result.get("cleanup_successful", false)
	timeout_tests.append({
		"test": "Timeout Cleanup",
		"result": cleanup_result,
		"cleanup_successful": cleanup_worked,
		"expected_timeout": "cleanup"
	})
	if cleanup_worked: passed_tests += 1
	total_tests += 1
	
	var success_rate = float(passed_tests) / float(total_tests)
	var overall_success = success_rate >= 0.8  # 80% of timeout scenarios should work correctly
	
	var test_result = {
		"passed_tests": passed_tests,
		"total_tests": total_tests,
		"success_rate": success_rate,
		"overall_success": overall_success,
		"timeout_test_details": timeout_tests
	}
	
	if overall_success:
		_update_status("Timeout behavior test PASSED (" + str(passed_tests) + "/" + str(total_tests) + " scenarios handled correctly)")
	else:
		_update_status("Timeout behavior test FAILED (" + str(passed_tests) + "/" + str(total_tests) + " scenarios worked)", true)
	
	execution_completed.emit(overall_success, test_result)
	return overall_success

# Test multiple operations with different timeout configurations
func _test_mixed_timeouts() -> Dictionary:
	var operations = [
		{"timeout": 0.1, "should_timeout": true},
		{"timeout": 3.0, "should_timeout": false},
		{"timeout": 0.05, "should_timeout": true},
		{"timeout": 5.0, "should_timeout": false}
	]
	
	var correct_behaviors = 0
	var operation_results = []
	
	for i in range(operations.size()):
		var op = operations[i]
		var result = await execute_cpp_operation_with_timeout(
			"set_value_async",
			[["cpp_tests", "timeout", "mixed", str(i), str(Time.get_ticks_msec())], "Mixed test " + str(i)],
			op.timeout,
			"Mixed Timeout " + str(i)
		)
		
		var timed_out = result.get("code") == "TIMEOUT"
		var behavior_correct = (op.should_timeout and timed_out) or (not op.should_timeout and not timed_out)
		
		if behavior_correct:
			correct_behaviors += 1
		
		operation_results.append({
			"operation": i,
			"timeout": op.timeout,
			"should_timeout": op.should_timeout,
			"actual_timeout": timed_out,
			"behavior_correct": behavior_correct,
			"result": result
		})
	
	return {
		"success": correct_behaviors == operations.size(),
		"correct_behaviors": correct_behaviors,
		"total_operations": operations.size(),
		"operation_details": operation_results
	}

# Test that timeout cleanup works properly (no resource leaks)
func _test_timeout_cleanup() -> Dictionary:
	var initial_request_count = _cpp_pending_requests.size()
	
	# Create several operations that will timeout
	var timeout_operations = []
	for i in range(3):
		var task = execute_cpp_operation_with_timeout(
			"set_value_async",
			[["cpp_tests", "timeout", "cleanup", str(i), str(Time.get_ticks_msec())], "Cleanup test " + str(i)],
			0.1,  # Very short timeout
			"Cleanup Test " + str(i)
		)
		timeout_operations.append(task)
	
	# Wait for all to timeout
	var timeout_results = []
	for task in timeout_operations:
		var result = await task
		timeout_results.append(result)
	
	# Check that pending requests were cleaned up
	await get_tree().create_timer(0.5).timeout  # Give cleanup time to complete
	var final_request_count = _cpp_pending_requests.size()
	
	var cleanup_successful = final_request_count <= initial_request_count
	var all_timed_out = true
	
	for result in timeout_results:
		if result.get("code") != "TIMEOUT":
			all_timed_out = false
			break
	
	return {
		"cleanup_successful": cleanup_successful,
		"all_operations_timed_out": all_timed_out,
		"initial_request_count": initial_request_count,
		"final_request_count": final_request_count,
		"timeout_results": timeout_results
	}
