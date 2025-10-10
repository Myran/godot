class_name BackendIsolatedPushOnlyTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "backend.firebase.isolated_push_only"
	auto_continue = false


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing ISOLATED Firebase PushChild operation ONLY...")

	var timed_op: Dictionary = await TestUtils.time_operation(
		"Isolated Firebase PushChild Test", _perform_isolated_push_test
	)
	var test_results: Dictionary = timed_op.result
	var duration_ms: int = TestUtils.get_duration_ms(timed_op)

	if not test_results.get("success", false):
		return TestUtils.make_failure_result(
			test_results.get("error", "Isolated push test failed"),
			TestConstants.ERROR_CODES.BACKEND_UNAVAILABLE,
			duration_ms,
			action_name,
			TestUtils.make_metadata("isolated_push_only", test_results)
		)

	var metadata: Dictionary = TestUtils.make_metadata(
		"isolated_push_only",
		{
			"operation": "push_child_only",
			"test_data": test_results.get("test_data", {}),
			"crash_point": "none - test completed"
		}
	)

	_update_status("✅ ISOLATED PUSH TEST PASSED - No crash detected")
	Log.info(
		"Isolated Firebase push test completed successfully",
		test_results,
		["debug", "backend_firebase", "isolated_test"]
	)
	return TestUtils.make_success_result(
		"Isolated Firebase push test completed successfully", duration_ms, action_name, metadata
	)


func _perform_isolated_push_test() -> Dictionary:
	var backend: DataBackend = get_firebase_backend_for_testing()
	if not backend:
		return {"success": false, "error": "Firebase backend not available"}

	# Create minimal test data - small and simple to isolate the crash
	var test_data: Dictionary = {
		"test_type": "isolated_push_only",
		"timestamp": str(Time.get_ticks_msec()),
		"simple_value": "test_value"
	}

	# Isolated test: ONLY perform PushChild operation
	# No other Firebase operations before or after
	var test_path: Array[Variant] = ["isolated_tests", "push_only", str(Time.get_ticks_msec())]

	_update_status("🔥 EXECUTING ISOLATED PUSH CHILD OPERATION...")
	var push_success: bool = await test_backend_async_pattern(
		"push_data", test_path, "", test_data, "Isolated PushChild operation"
	)

	if not push_success:
		return {"success": false, "error": "PushChild operation failed", "test_data": test_data}

	_update_status("✅ PUSH CHILD COMPLETED SUCCESSFULLY - No crash detected")
	return {
		"success": true,
		"test_data": test_data,
		"path_used": str(test_path),
		"operation": "push_child_only"
	}
