# project/debug/actions/firebase_backend/backend_request_tracking_test_action.gd
class_name BackendRequestTrackingTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "backend.firebase.request_tracking"


# New DebugAction.Result pattern - this is the future
func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Testing Firebase Backend request tracking...")

	var backend: FirebaseBackend = get_firebase_backend_for_testing()
	if not backend:
		return DebugAction.Result.new_failure(
			"Firebase backend not available for testing",
			"BACKEND_UNAVAILABLE",
			DebugAction.Result.ErrorCategory.DATABASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)

	var tracking_tests: Array[Dictionary] = []
	var successful_tests: int = 0
	var total_tests: int = 0

	# Test 1: Sequential request tracking
	_update_status("Testing sequential request tracking...")
	total_tests += 1
	var sequential_count: int = 3
	var sequential_results: Array[Dictionary] = []
	var sequential_success: int = 0

	for i: int in range(sequential_count):
		var seq_path: Array[String] = ["backend_tests", "request_tracking", "sequential", str(i)]
		var seq_key: String = "req_track_seq_" + str(i) + "_" + str(Time.get_ticks_msec())
		var seq_value: String = "Sequential request " + str(i)

		var seq_start: int = Time.get_ticks_msec()
		var seq_result: bool = await test_backend_async_pattern(
			"set_data", seq_path, seq_key, seq_value, "Tracking: Seq " + str(i)
		)
		var seq_duration: int = Time.get_ticks_msec() - seq_start

		sequential_results.append(
			{
				"request_index": i,
				"success": seq_result,
				"duration_ms": seq_duration,
				"path": seq_path,
				"key": seq_key
			}
		)

		if seq_result:
			sequential_success += 1

	var sequential_test_success: bool = sequential_success == sequential_count
	if sequential_test_success:
		successful_tests += 1

	tracking_tests.append(
		{
			"test": "sequential_request_tracking",
			"success": sequential_test_success,
			"total_requests": sequential_count,
			"successful_requests": sequential_success,
			"request_details": sequential_results
		}
	)

	# Test 2: Concurrent-style request handling (rapid fire)
	_update_status("Testing rapid request handling...")
	total_tests += 1
	var rapid_count: int = 4
	var __rapid_tasks: Array[Variant] = []
	var rapid_results: Array[Dictionary] = []
	var rapid_success: int = 0

	# Execute all requests rapidly one after another
	for i: int in range(rapid_count):
		var rapid_path: Array[String] = ["backend_tests", "request_tracking", "rapid", str(i)]
		var rapid_key: String = "req_track_rapid_" + str(i) + "_" + str(Time.get_ticks_msec())
		var rapid_value: String = "Rapid request " + str(i)

		# Execute request directly for rapid testing
		var rapid_start: int = Time.get_ticks_msec()
		var rapid_result: bool = await test_backend_async_pattern(
			"set_data", rapid_path, rapid_key, rapid_value, "Tracking: Rapid " + str(i)
		)
		var rapid_duration: int = Time.get_ticks_msec() - rapid_start

		rapid_results.append(
			{"request_index": i, "success": rapid_result, "duration_ms": rapid_duration}
		)

		if rapid_result:
			rapid_success += 1

		# Very small delay to simulate rapid firing
		await Engine.get_main_loop().process_frame

	var rapid_test_success: bool = rapid_success >= (rapid_count * 0.75)  # 75% success rate for rapid requests
	if rapid_test_success:
		successful_tests += 1

	tracking_tests.append(
		{
			"test": "rapid_request_handling",
			"success": rapid_test_success,
			"total_requests": rapid_count,
			"successful_requests": rapid_success,
			"success_rate": float(rapid_success) / float(rapid_count),
			"request_details": rapid_results
		}
	)

	# Test 3: RequestSignalHelper pattern validation
	_update_status("Testing RequestSignalHelper pattern...")
	total_tests += 1

	# Test multiple operations of different types to stress RequestSignalHelper
	# Use set-then-get pattern to ensure get_data has valid data to retrieve
	var base_key: String = "pattern_test_" + str(Time.get_ticks_msec())
	var pattern_operations: Array[Dictionary] = [
		{
			"method": "set_data",
			"path": ["backend_tests", "request_tracking", "pattern", "set"],
			"key": base_key + "_set",
			"value": "Pattern set test"
		},
		{
			"method": "set_data",
			"path": ["backend_tests", "request_tracking", "pattern", "get"],
			"key": base_key + "_get",
			"value": "Pattern get test data"
		},
		{
			"method": "get_data",
			"path": ["backend_tests", "request_tracking", "pattern", "get"],
			"key": base_key + "_get",
			"value": null
		},
		{
			"method": "set_data",
			"path": ["backend_tests", "request_tracking", "pattern", "set2"],
			"key": base_key + "_set2",
			"value": "Pattern set2 test"
		}
	]

	var pattern_success: int = 0
	var pattern_results: Array[Dictionary] = []

	for op: Dictionary in pattern_operations:
		var pattern_start: int = Time.get_ticks_msec()
		var method_str: String = op["method"]
		var path_array: Array = op["path"]
		var key_str: String = op["key"]
		var value_variant: Variant = op["value"]
		var pattern_result: bool = await test_backend_async_pattern(
			method_str, path_array, key_str, value_variant, "Pattern: " + method_str
		)
		var pattern_duration: int = Time.get_ticks_msec() - pattern_start

		pattern_results.append(
			{
				"method": method_str,
				"success": pattern_result,
				"duration_ms": pattern_duration,
				"path": path_array,
				"key": key_str
			}
		)

		if pattern_result:
			pattern_success += 1

		# Small delay between pattern operations
		await Engine.get_main_loop().create_timer(0.1).timeout

	var pattern_test_success: bool = pattern_success >= (pattern_operations.size() * 0.75)  # 75% success rate
	if pattern_test_success:
		successful_tests += 1

	tracking_tests.append(
		{
			"test": "request_signal_helper_pattern",
			"success": pattern_test_success,
			"total_operations": pattern_operations.size(),
			"successful_operations": pattern_success,
			"pattern_details": pattern_results
		}
	)

	# Calculate overall success
	var success_rate: float = float(successful_tests) / float(total_tests)
	var overall_success: bool = success_rate >= 0.8  # 80% of tracking tests should pass
	var total_duration: int = Time.get_ticks_msec() - start_time

	var test_results: Dictionary = {
		"total_tests": total_tests,
		"successful_tests": successful_tests,
		"success_rate": success_rate,
		"tracking_tests": tracking_tests,
		"request_tracking_validation": overall_success,
		"backend_available": backend.is_available()
	}

	if overall_success:
		_update_status(
			"Request Tracking test PASSED (" + str(successful_tests) + "/" + str(total_tests) + ")"
		)
		Log.info(
			"Backend request tracking validation successful",
			test_results,
			["debug", "backend_firebase"]
		)

		return DebugAction.Result.new_success(
			"Backend request tracking test completed successfully",
			total_duration,
			action_name,
			{
				"test_type": "backend_request_tracking",
				"tracking_tests": tracking_tests,
				"success_rate": success_rate,
				"total_tests": total_tests,
				"successful_tests": successful_tests,
				"backend_state": {"available": backend.is_available()}
			}
		)
	else:
		_update_status(
			"Request Tracking test FAILED (" + str(successful_tests) + "/" + str(total_tests) + ")",
			true
		)
		Log.error(
			"Backend request tracking validation failed",
			test_results,
			["debug", "backend_firebase", "error"]
		)

		return DebugAction.Result.new_failure(
			"Backend request tracking test failed - insufficient success rate",
			"REQUEST_TRACKING_INSUFFICIENT",
			DebugAction.Result.ErrorCategory.VALIDATION,
			test_results,
			total_duration,
			action_name,
			{
				"test_type": "backend_request_tracking",
				"tracking_tests": tracking_tests,
				"success_rate": success_rate,
				"total_tests": total_tests,
				"successful_tests": successful_tests,
				"minimum_required_rate": 0.8
			}
		)


