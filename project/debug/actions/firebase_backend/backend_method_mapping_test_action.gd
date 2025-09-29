class_name BackendMethodMappingTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "backend.firebase.method_mapping"
	auto_continue = false  # Sequential execution required for Firebase operations


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var timed_op: Dictionary = await TestUtils.time_operation(
		"Backend Method Mapping Test", _perform_method_mapping_tests
	)
	var test_results: Dictionary = timed_op.result
	var duration_ms: int = TestUtils.get_duration_ms(timed_op)

	if not TestUtils.is_valid_result(test_results):
		return TestUtils.make_failure_result(
			"Firebase backend not available for testing",
			TestConstants.ERROR_CODES.BACKEND_UNAVAILABLE,
			duration_ms,
			action_name,
			TestUtils.make_metadata("backend_method_mapping", {"backend_available": false})
		)

	var total_methods: int = test_results.get("total_methods_tested", 0)
	var successful_methods: int = test_results.get("successful_methods", 0)
	var success_rate: float = test_results.get("success_rate", 0.0)
	var method_results: Dictionary = test_results.get("method_details", {})
	var overall_success: bool = success_rate >= 0.75  # 75% of methods must work

	var metadata: Dictionary = TestUtils.make_metadata(
		"backend_method_mapping",
		{
			"methods_tested": ["set_data", "get_data", "push_data", "remove_data"],
			"method_results": method_results,
			"success_rate": success_rate,
			"total_methods": total_methods,
			"successful_methods": successful_methods,
			"minimum_required_rate": 0.75
		}
	)

	if overall_success:
		_update_status("Method Mapping test PASSED (%d/%d)" % [successful_methods, total_methods])
		Log.info(
			"Backend method mapping validation successful",
			test_results,
			["debug", "backend_firebase"]
		)
		return TestUtils.make_success_result(
			"Backend method mapping test completed successfully", duration_ms, action_name, metadata
		)

	_update_status("Method Mapping test FAILED (%d/%d)" % [successful_methods, total_methods], true)
	Log.error(
		"Backend method mapping validation failed",
		test_results,
		["debug", "backend_firebase", "error"]
	)
	return TestUtils.make_failure_result(
		"Backend method mapping test failed - insufficient success rate",
		TestConstants.ERROR_CODES.VALIDATION_FAILED,
		duration_ms,
		action_name,
		metadata
	)


func _perform_method_mapping_tests() -> Dictionary:
	_update_status("Testing Firebase Backend method mappings...")

	var backend: DataBackend = get_firebase_backend_for_testing()
	if not backend:
		return {}

	var test_base_path: Array[Variant] = [TestConstants.FIREBASE_BACKEND_PREFIX, "method_mapping"]
	var test_timestamp: String = str(Time.get_ticks_msec())
	var method_results: Dictionary = {}
	var total_methods: int = 0
	var successful_methods: int = 0

	_update_status("Testing set_data method mapping...")
	total_methods += 1
	var set_test_path: Array[Variant] = []
	set_test_path.assign(test_base_path + ["set_test"])
	var set_key: String = "set_" + test_timestamp
	var set_value: String = TestConstants.test_value("Set method test")

	var set_success: bool = await test_backend_async_pattern(
		"set_data", set_test_path, set_key, set_value, "Method: set_data"
	)
	method_results["set_data"] = {"success": set_success, "tested": true}
	if set_success:
		successful_methods += 1

	_update_status("Testing get_data method mapping...")
	total_methods += 1
	var get_success: bool = await test_backend_async_pattern(
		"get_data", set_test_path, set_key, null, "Method: get_data"
	)
	method_results["get_data"] = {"success": get_success, "tested": true}
	if get_success:
		successful_methods += 1

	_update_status("Testing push_data method mapping...")
	total_methods += 1
	var push_path: Array[Variant] = []
	push_path.assign(test_base_path + ["push_test"])
	var push_value: Dictionary = {"message": "Push method test", "timestamp": test_timestamp}

	var push_success: bool = await test_backend_async_pattern(
		"push_data", push_path, "", push_value, "Method: push_data"
	)
	method_results["push_data"] = {"success": push_success, "tested": true}
	if push_success:
		successful_methods += 1

	_update_status("Testing remove_data method mapping...")
	total_methods += 1
	var remove_success: bool = await test_backend_async_pattern(
		"remove_data", set_test_path, set_key, null, "Method: remove_data"
	)
	method_results["remove_data"] = {"success": remove_success, "tested": true}
	if remove_success:
		successful_methods += 1

	var success_rate: float = float(successful_methods) / float(total_methods)

	return {
		"total_methods_tested": total_methods,
		"successful_methods": successful_methods,
		"success_rate": success_rate,
		"method_details": method_results,
		"mapping_validation": success_rate >= 0.75,
		"backend_available": backend.is_available()
	}
