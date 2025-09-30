class_name BackendRequestTrackingTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "backend.firebase.request_tracking"
	auto_continue = false  # Sequential execution required for Firebase operations


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing Firebase Backend request tracking...")

	var backend: DataBackend = get_firebase_backend_for_testing()
	if not backend:
		return TestUtils.make_failure_result(
			"Firebase backend not available for testing",
			TestConstants.ERROR_CODES.BACKEND_UNAVAILABLE,
			0,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.BACKEND_REQUEST_TRACKING)
		)

	var tracking_tests: Array[Dictionary] = []
	var successful_tests: int = 0
	var total_tests: int = 0

	_update_status("Testing sequential request tracking...")
	total_tests += 1
	var sequential_count: int = 3
	var sequential_results: Array[Dictionary] = []
	var sequential_success: int = 0
	var test_base_path: Array[Variant] = TestUtils.make_test_path(
		TestConstants.FIREBASE_BACKEND_PREFIX, "request_tracking"
	)

	for i: int in range(sequential_count):
		var seq_path: Array[Variant] = test_base_path + ["sequential", str(i)]
		var seq_key: String = TestUtils.make_test_key("req_track_seq_" + str(i))
		var seq_value: String = TestUtils.make_test_value("Sequential request " + str(i))

		var seq_op: Dictionary = await TestUtils.time_operation(
			"sequential_" + str(i),
			func() -> Variant:
				return await test_backend_async_pattern(
					"set_data", seq_path, seq_key, seq_value, "Tracking: Seq " + str(i)
				)
		)
		var seq_duration: int = TestUtils.get_duration_ms(seq_op)
		var seq_result: bool = seq_op.result

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

	_update_status("Testing rapid request handling...")
	total_tests += 1
	var rapid_count: int = 4
	var rapid_tasks: Array[Variant] = []
	var rapid_results: Array[Dictionary] = []
	var rapid_success: int = 0

	for i: int in range(rapid_count):
		var rapid_path: Array[Variant] = test_base_path + ["rapid", str(i)]
		var rapid_key: String = TestUtils.make_test_key("req_track_rapid_" + str(i))
		var rapid_value: String = TestUtils.make_test_value("Rapid request " + str(i))

		var rapid_op: Dictionary = await TestUtils.time_operation(
			"rapid_" + str(i),
			func() -> Variant:
				return await test_backend_async_pattern(
					"set_data", rapid_path, rapid_key, rapid_value, "Tracking: Rapid " + str(i)
				)
		)
		var rapid_duration: int = TestUtils.get_duration_ms(rapid_op)
		var rapid_result: bool = rapid_op.result

		rapid_results.append(
			{"request_index": i, "success": rapid_result, "duration_ms": rapid_duration}
		)

		if rapid_result:
			rapid_success += 1

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

	_update_status("Testing RequestSignalHelper pattern...")
	total_tests += 1

	var base_key: String = TestUtils.make_test_key("pattern_test")
	var pattern_base_path: Array[Variant] = test_base_path + ["pattern"]
	var pattern_operations: Array[Dictionary] = [
		{
			"method": "set_data",
			"path": pattern_base_path + ["set"],
			"key": base_key + "_set",
			"value": TestUtils.make_test_value("Pattern set test")
		},
		{
			"method": "set_data",
			"path": pattern_base_path + ["get"],
			"key": base_key + "_get",
			"value": TestUtils.make_test_value("Pattern get test data")
		},
		{
			"method": "get_data",
			"path": pattern_base_path + ["get"],
			"key": base_key + "_get",
			"value": null
		},
		{
			"method": "set_data",
			"path": pattern_base_path + ["set2"],
			"key": base_key + "_set2",
			"value": TestUtils.make_test_value("Pattern set2 test")
		}
	]

	var pattern_success: int = 0
	var pattern_results: Array[Dictionary] = []

	for op: Dictionary in pattern_operations:
		var method_str: String = op["method"]
		var path_array: Array[Variant] = op["path"]
		var key_str: String = op["key"]
		var value_variant: Variant = op["value"]

		var pattern_op: Dictionary = await TestUtils.time_operation(
			"pattern_" + method_str,
			func() -> Variant:
				return await test_backend_async_pattern(
					method_str, path_array, key_str, value_variant, "Pattern: " + method_str
				)
		)
		var pattern_duration: int = TestUtils.get_duration_ms(pattern_op)
		var pattern_result: bool = pattern_op.result

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

	var success_rate: float = float(successful_tests) / float(total_tests)
	var overall_success: bool = success_rate >= 0.8  # 80% of tracking tests should pass

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
			[TestConstants.LOG_TAGS.DEBUG, TestConstants.LOG_TAGS.BACKEND_FIREBASE]
		)

		return TestUtils.make_success_result(
			"Backend request tracking test completed successfully",
			0,
			action_name,
			TestUtils.make_metadata(
				TestConstants.TEST_TYPES.BACKEND_REQUEST_TRACKING,
				{
					"tracking_tests": tracking_tests,
					"success_rate": success_rate,
					"total_tests": total_tests,
					"successful_tests": successful_tests,
					"backend_state": {"available": backend.is_available()}
				}
			)
		)

	_update_status(
		"Request Tracking test FAILED (" + str(successful_tests) + "/" + str(total_tests) + ")",
		true
	)
	Log.error(
		"Backend request tracking validation failed",
		test_results,
		[
			TestConstants.LOG_TAGS.DEBUG,
			TestConstants.LOG_TAGS.BACKEND_FIREBASE,
			TestConstants.LOG_TAGS.ERROR
		]
	)

	return TestUtils.make_failure_result(
		"Backend request tracking test failed - insufficient success rate",
		TestConstants.ERROR_CODES.REQUEST_TRACKING_INSUFFICIENT,
		0,
		action_name,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.BACKEND_REQUEST_TRACKING,
			{
				"tracking_tests": tracking_tests,
				"success_rate": success_rate,
				"total_tests": total_tests,
				"successful_tests": successful_tests,
				"minimum_required_rate": 0.8
			}
		)
	)
