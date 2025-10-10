class_name BackendIsolatedSetValueTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "backend.firebase.isolated_set_value"
	auto_continue = false


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing ISOLATED Firebase SetValue operation ONLY...")

	var timed_op: Dictionary = await TestUtils.time_operation(
		"Isolated Firebase SetValue Test", _perform_isolated_set_value_test
	)
	var test_results: Dictionary = timed_op.result
	var duration_ms: int = TestUtils.get_duration_ms(timed_op)

	if not test_results.get("success", false):
		return TestUtils.make_failure_result(
			str(test_results.get("error", "Isolated set value test failed")),
			TestConstants.ERROR_CODES.BACKEND_UNAVAILABLE,
			duration_ms,
			action_name,
			TestUtils.make_metadata("isolated_set_value", test_results)
		)

	var metadata: Dictionary = TestUtils.make_metadata(
		"isolated_set_value",
		{
			"operation": "set_value_only",
			"test_data": test_results.get("test_data", {}),
			"crash_point": "none - test completed"
		}
	)

	_update_status("✅ ISOLATED SET VALUE TEST PASSED - No crash detected")
	Log.info(
		"Isolated Firebase set value test completed successfully",
		test_results,
		["debug", "backend_firebase", "isolated_test"]
	)
	return TestUtils.make_success_result(
		"Isolated Firebase set value test completed successfully",
		duration_ms,
		action_name,
		metadata
	)


func _perform_isolated_set_value_test() -> Dictionary:
	var backend: DataBackend = get_firebase_backend_for_testing()
	if not backend:
		return {"success": false, "error": "Firebase backend not available"}

	# Create minimal test data
	var test_data: Dictionary = {
		"test_type": "isolated_set_value_only",
		"timestamp": str(Time.get_ticks_msec()),
		"simple_value": "test_set_value"
	}

	# Isolated test: ONLY perform SetValue operation (not PushChild)
	var test_path: Array[Variant] = ["isolated_tests", "set_value", "test_node"]

	_update_status("🔥 EXECUTING ISOLATED SET VALUE OPERATION...")
	var set_success: bool = await test_backend_async_pattern(
		"set_data", test_path, "", test_data, "Isolated SetValue operation"
	)

	if not set_success:
		return {"success": false, "error": "SetValue operation failed", "test_data": test_data}

	_update_status("✅ SET VALUE COMPLETED SUCCESSFULLY - No crash detected")
	return {
		"success": true,
		"test_data": test_data,
		"path_used": str(test_path),
		"operation": "set_value_only"
	}
