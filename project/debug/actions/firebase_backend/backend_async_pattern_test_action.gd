class_name BackendAsyncPatternTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "backend.firebase.async_pattern"
	auto_continue = false  # Sequential execution required for Firebase operations


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	Log.info(
		"TRACE: _execute_action_logic started",
		{"action": action_name},
		["debug", "backend_firebase", "trace"]
	)

	_update_status("Testing Firebase Backend async patterns...")

	Log.debug(
		"TRACE: About to call test_backend_async_pattern for set_data",
		{"action": action_name},
		["debug", "backend_firebase", "trace"]
	)

	var test_path: Array[Variant] = ["backend_tests", "async_pattern"]
	var test_key: String = TestConstants.test_value("test")
	var test_value: String = TestConstants.test_value("Backend Async Test")

	var async_test: Dictionary = await TestUtils.time_operation(
		"async_pattern_test",
		func() -> Dictionary:
			var set_success: bool = await test_backend_async_pattern(
				"set_data", test_path, test_key, test_value, "Backend Set Data"
			)

			Log.debug(
				"TRACE: test_backend_async_pattern set_data completed",
				{"action": action_name, "set_success": set_success},
				["debug", "backend_firebase", "trace"]
			)

			if not set_success:
				return {
					"success": false,
					"failed_operation": "set_data",
					"test_path": test_path,
					"test_key": test_key,
					"test_value": test_value
				}

			var get_success: bool = await test_backend_async_pattern(
				"get_data", test_path, test_key, null, "Backend Get Data"
			)

			return {
				"success": set_success and get_success,
				"failed_operation": "get_data" if not get_success else "",
				"set_success": set_success,
				"get_success": get_success,
				"test_path": test_path,
				"test_key": test_key,
				"test_value": test_value
			}
	)

	var duration: int = async_test.duration_ms
	var result: Dictionary = async_test.result
	var overall_success: bool = result.success

	# UNIFIED TEST REPORTING: Generate DEBUG_TEST_SUCCESS marker
	var test_metadata: Dictionary = DebugConfigReader.get_test_metadata()
	var config_test_id: String = test_metadata.get("test_id", "")
	if config_test_id != "" and overall_success:
		DebugAction._log_test_success(action_name, category, group, duration, {})

	if overall_success:
		_update_status("Backend async pattern test PASSED")
		return TestUtils.make_success_result(
			"Backend async pattern test completed successfully",
			duration,
			action_name,
			TestUtils.make_metadata(
				"backend_async_pattern",
				{
					"operations_tested": ["set_data", "get_data"],
					"test_path": result.test_path,
					"test_key": result.test_key,
					"test_value": result.test_value,
					"set_success": result.set_success,
					"get_success": result.get_success
				}
			)
		)

	_update_status("Backend async pattern test FAILED", true)
	var failed_op: String = result.failed_operation
	return TestUtils.make_failure_result(
		"Backend async pattern test failed during " + failed_op + " operation",
		TestConstants.ERROR_OPERATION_FAILED,
		duration,
		action_name,
		TestUtils.make_metadata(
			"backend_async_pattern",
			{
				"failed_operation": failed_op,
				"test_path": result.test_path,
				"test_key": result.test_key,
				"set_success": result.get("set_success", false),
				"get_success": result.get("get_success", false)
			}
		)
	)
