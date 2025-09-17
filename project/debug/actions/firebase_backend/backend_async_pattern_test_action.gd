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

	var start_time: int = Time.get_ticks_msec()
	_update_status("Testing Firebase Backend async patterns...")

	Log.debug(
		"TRACE: About to call test_backend_async_pattern for set_data",
		{"action": action_name},
		["debug", "backend_firebase", "trace"]
	)

	var test_path: Array[Variant] = ["backend_tests", "async_pattern"]
	var test_key: String = "test_" + str(Time.get_ticks_msec())
	var test_value: String = "Backend Async Test: " + str(Time.get_ticks_msec())

	var set_success: bool = await test_backend_async_pattern(
		"set_data", test_path, test_key, test_value, "Backend Set Data"
	)

	Log.debug(
		"TRACE: test_backend_async_pattern set_data completed",
		{"action": action_name, "set_success": set_success},
		["debug", "backend_firebase", "trace"]
	)

	if not set_success:
		return DebugActionResult.new_failure(
			"Backend async pattern test failed during set operation",
			"SET_OPERATION_FAILED",
			DebugActionResult.ErrorCategory.DATABASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name,
			{
				"test_type": "backend_async_pattern",
				"failed_operation": "set_data",
				"test_path": test_path,
				"test_key": test_key,
				"test_value": test_value
			}
		)

	var get_success: bool = await test_backend_async_pattern(
		"get_data", test_path, test_key, null, "Backend Get Data"
	)

	var overall_success: bool = set_success and get_success
	var total_duration: int = Time.get_ticks_msec() - start_time

	# UNIFIED TEST REPORTING: Generate DEBUG_TEST_SUCCESS marker
	var test_metadata: Dictionary = DebugConfigReader.get_test_metadata()
	var config_test_id: String = test_metadata.get("test_id", "")
	if config_test_id != "" and overall_success:
		DebugAction._log_test_success(action_name, category, group, total_duration, {})

	if overall_success:
		_update_status("Backend async pattern test PASSED")
		return DebugActionResult.new_success(
			"Backend async pattern test completed successfully",
			total_duration,
			action_name,
			{
				"test_type": "backend_async_pattern",
				"operations_tested": ["set_data", "get_data"],
				"test_path": test_path,
				"test_key": test_key,
				"test_value": test_value,
				"set_success": set_success,
				"get_success": get_success
			}
		)

	_update_status("Backend async pattern test FAILED", true)
	return DebugActionResult.new_failure(
		"Backend async pattern test failed during get operation",
		"GET_OPERATION_FAILED",
		DebugActionResult.ErrorCategory.DATABASE,
		null,
		total_duration,
		action_name,
		{
			"test_type": "backend_async_pattern",
			"failed_operation": "get_data",
			"test_path": test_path,
			"test_key": test_key,
			"set_success": set_success,
			"get_success": get_success
		}
	)
