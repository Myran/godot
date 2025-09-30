class_name BackendTimerManagerTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "backend.firebase.timer_manager"
	auto_continue = false  # Sequential execution required for Firebase operations


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing Firebase Backend timer management...")

	var backend: DataBackend = get_firebase_backend_for_testing()
	if not backend:
		return TestUtils.make_failure_result(
			"Firebase backend not available for testing",
			TestConstants.ERROR_CODES.BACKEND_UNAVAILABLE,
			0,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.BACKEND_TIMER_MANAGER)
		)

	_update_status("Testing normal timeout handling...")
	var test_base_path: Array[Variant] = TestUtils.make_test_path(
		TestConstants.FIREBASE_BACKEND_PREFIX, "timer_manager"
	)
	var test_path: Array[Variant] = test_base_path + ["normal"]
	var test_key: String = TestUtils.make_test_key("timer_test")
	var test_value: String = TestUtils.make_test_value("Timer Test")

	var normal_op: Dictionary = await TestUtils.time_operation(
		"timer_normal",
		func() -> Variant:
			return await test_backend_async_pattern(
				"set_data", test_path, test_key, test_value, "Timer Normal"
			)
	)
	var normal_duration: int = TestUtils.get_duration_ms(normal_op)
	var normal_result: bool = normal_op.result

	_update_status("Testing rapid request handling...")
	var rapid_requests: int = 3
	var rapid_success: int = 0
	var total_rapid_duration: int = 0

	for i: int in range(rapid_requests):
		var rapid_path: Array[Variant] = test_base_path + ["rapid", str(i)]
		var rapid_key: String = TestUtils.make_test_key("rapid_" + str(i))
		var rapid_value: String = TestUtils.make_test_value("Rapid Test " + str(i))

		var rapid_op: Dictionary = await TestUtils.time_operation(
			"timer_rapid_" + str(i),
			func() -> Variant:
				return await test_backend_async_pattern(
					"set_data", rapid_path, rapid_key, rapid_value, "Rapid " + str(i)
				)
		)
		var rapid_duration: int = TestUtils.get_duration_ms(rapid_op)
		var rapid_result: bool = rapid_op.result

		if rapid_result:
			rapid_success += 1
		total_rapid_duration += rapid_duration

		# Removed forbidden timing-based wait that caused Firebase C++ SDK race condition
		# The await test_backend_async_pattern already provides proper completion signaling

	var rapid_success_rate: float = float(rapid_success) / float(rapid_requests)
	var avg_rapid_duration: int = int(float(total_rapid_duration) / float(rapid_requests))

	var normal_ok: bool = normal_result and normal_duration < 5000  # Under 5 seconds
	var rapid_ok: bool = rapid_success_rate >= 0.8  # 80% success rate
	var overall_success: bool = normal_ok and rapid_ok

	var test_results: Dictionary = {
		"normal_test":
		{"success": normal_result, "duration_ms": normal_duration, "within_timeout": normal_ok},
		"rapid_test":
		{
			"successful_requests": rapid_success,
			"total_requests": rapid_requests,
			"success_rate": rapid_success_rate,
			"avg_duration_ms": avg_rapid_duration,
			"passed": rapid_ok
		},
		"timer_manager_validation": overall_success
	}

	if overall_success:
		_update_status("Timer Manager test PASSED")
		Log.info(
			"Backend TimerManager validation successful",
			test_results,
			[TestConstants.LOG_TAGS.DEBUG, TestConstants.LOG_TAGS.BACKEND_FIREBASE]
		)

		return TestUtils.make_success_result(
			"Backend timer manager test completed successfully",
			0,
			action_name,
			TestUtils.make_metadata(
				TestConstants.TEST_TYPES.BACKEND_TIMER_MANAGER,
				{
					"normal_test": test_results["normal_test"],
					"rapid_test": test_results["rapid_test"],
					"backend_state": {"available": backend.is_available()}
				}
			)
		)

	_update_status("Timer Manager test FAILED", true)
	Log.error(
		"Backend TimerManager validation failed",
		test_results,
		[
			TestConstants.LOG_TAGS.DEBUG,
			TestConstants.LOG_TAGS.BACKEND_FIREBASE,
			TestConstants.LOG_TAGS.ERROR
		]
	)

	return TestUtils.make_failure_result(
		"Backend timer manager test failed - timeout handling insufficient",
		TestConstants.ERROR_CODES.TIMER_MANAGER_INSUFFICIENT,
		0,
		action_name,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.BACKEND_TIMER_MANAGER,
			{
				"normal_test": test_results["normal_test"],
				"rapid_test": test_results["rapid_test"],
				"normal_ok": normal_ok,
				"rapid_ok": rapid_ok
			}
		)
	)
