class_name BackendIsolatedGetOnlyTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "backend.firebase.isolated_get_only"
	auto_continue = false


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing ISOLATED Firebase Get operation ONLY...")

	var timed_op: Dictionary = await TestUtils.time_operation(
		"Isolated Firebase Get Test", _perform_isolated_get_test
	)
	var test_results: Dictionary = timed_op.result
	var duration_ms: int = TestUtils.get_duration_ms(timed_op)

	if not test_results.get("success", false):
		return TestUtils.make_failure_result(
			str(test_results.get("error", "Isolated get test failed")),
			TestConstants.ERROR_CODES.BACKEND_UNAVAILABLE,
			duration_ms,
			action_name,
			TestUtils.make_metadata("isolated_get_only", test_results)
		)

	var metadata: Dictionary = TestUtils.make_metadata(
		"isolated_get_only",
		{
			"operation": "get_value_only",
			"test_data": test_results.get("test_data", {}),
			"crash_point": "none - test completed"
		}
	)

	_update_status("✅ ISOLATED GET TEST PASSED - No crash detected")
	Log.info(
		"Isolated Firebase get test completed successfully",
		test_results,
		["debug", "backend_firebase", "isolated_test"]
	)
	return TestUtils.make_success_result(
		"Isolated Firebase get test completed successfully", duration_ms, action_name, metadata
	)


func _perform_isolated_get_test() -> Dictionary:
	var backend: DataBackend = get_firebase_backend_for_testing()
	if not backend:
		return {"success": false, "error": "Firebase backend not available"}

	# Isolated test: ONLY perform Get operation
	# Read from a known safe path that should exist
	var test_path: Array[Variant] = ["isolated_tests", "get_only"]

	_update_status("🔥 EXECUTING ISOLATED GET VALUE OPERATION...")
	var get_result: Variant = await test_backend_async_pattern(
		"get_data", test_path, "", null, "Isolated GetValue operation"
	)

	# Get operation might return null if path doesn't exist - that's OK
	# We're testing for crashes, not data correctness

	_update_status("✅ GET VALUE COMPLETED SUCCESSFULLY - No crash detected")
	return {
		"success": true,
		"test_data": {"path": str(test_path), "result": str(get_result)},
		"path_used": str(test_path),
		"operation": "get_value_only",
		"result_type": typeof(get_result)
	}
