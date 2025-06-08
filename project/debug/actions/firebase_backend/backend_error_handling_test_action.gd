# project/debug/actions/firebase_backend/backend_error_handling_test_action.gd
class_name BackendErrorHandlingTestAction
extends BackendFirebaseDebugAction

func _init() -> void:
	super._init()
	action_name = "Backend Error Handling Test"

func execute_backend_action() -> bool:
	_update_status("Testing Firebase Backend error handling...")
	
	var backend = get_firebase_backend_for_testing()
	if not backend:
		return false
	
	var error_tests = []
	var successful_error_handling = 0
	var total_error_tests = 0
	
	# Test 1: Invalid path handling
	_update_status("Testing invalid path error handling...")
	total_error_tests += 1
	var invalid_path = []  # Empty path should be handled gracefully
	var invalid_result = await test_backend_async_pattern("get_data", invalid_path, "", null, "Error: Invalid Path")
	
	# For error handling, we expect the operation to fail gracefully (return false/null, not crash)
	var invalid_handled = (invalid_result == false or invalid_result == null)
	if invalid_handled: successful_error_handling += 1
	error_tests.append({
		"test": "invalid_path",
		"handled_gracefully": invalid_handled,
		"result": invalid_result
	})
	
	# Test 2: Network timeout simulation (using very long path)
	_update_status("Testing timeout error handling...")
	total_error_tests += 1
	var timeout_path = ["backend_tests", "error_handling", "timeout_test", str(Time.get_ticks_msec())]
	
	var start_time = Time.get_ticks_msec()
	var timeout_result = await test_backend_async_pattern("get_data", timeout_path, "nonexistent_key", null, "Error: Timeout Test")
	var timeout_duration = Time.get_ticks_msec() - start_time
	
	# Backend should handle timeouts gracefully and return within reasonable time
	var timeout_handled = (timeout_duration < 30000)  # Should not hang for more than 30 seconds
	if timeout_handled: successful_error_handling += 1
	error_tests.append({
		"test": "timeout_handling", 
		"handled_gracefully": timeout_handled,
		"duration_ms": timeout_duration,
		"result": timeout_result
	})
	
	# Test 3: Unsupported method handling
	_update_status("Testing unsupported method error handling...")
	total_error_tests += 1
	var unsupported_path = ["backend_tests", "error_handling", "unsupported"]
	
	# Call test_backend_async_pattern with an unsupported method
	var unsupported_result = await test_backend_async_pattern("unsupported_method", unsupported_path, "test", "value", "Error: Unsupported Method")
	
	# Should return false and not crash
	var unsupported_handled = (unsupported_result == false)
	if unsupported_handled: successful_error_handling += 1
	error_tests.append({
		"test": "unsupported_method",
		"handled_gracefully": unsupported_handled,
		"result": unsupported_result
	})
	
	# Test 4: Backend availability check
	_update_status("Testing backend availability error handling...")
	total_error_tests += 1
	var availability_check = backend.is_available()
	var availability_handled = true  # Just checking this doesn't crash
	if availability_handled: successful_error_handling += 1
	error_tests.append({
		"test": "availability_check",
		"handled_gracefully": availability_handled,
		"backend_available": availability_check
	})
	
	# Calculate success rate
	var error_success_rate = float(successful_error_handling) / float(total_error_tests)
	var overall_success = error_success_rate >= 0.75  # 75% of error scenarios should be handled gracefully
	
	var test_results = {
		"total_error_tests": total_error_tests,
		"successful_error_handling": successful_error_handling,
		"error_success_rate": error_success_rate,
		"error_test_details": error_tests,
		"error_handling_validation": overall_success,
		"backend_available": backend.is_available()
	}
	
	if overall_success:
		_update_status("Error Handling test PASSED (" + str(successful_error_handling) + "/" + str(total_error_tests) + ")")
		Log.info("Backend error handling validation successful", test_results, ["debug", "backend_firebase"])
	else:
		_update_status("Error Handling test FAILED (" + str(successful_error_handling) + "/" + str(total_error_tests) + ")", true)
		Log.error("Backend error handling validation failed", test_results, ["debug", "backend_firebase", "error"])
	
	return overall_success
