class_name BackendLifecycleTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "backend.firebase.lifecycle"
	auto_continue = false  # Sequential execution required for Firebase operations


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Testing Firebase Backend lifecycle...")

	var lifecycle_tests: Array[Dictionary] = []
	var successful_tests: int = 0
	var total_tests: int = 0

	_update_status("Testing backend availability...")
	total_tests += 1
	var backend: DataBackend = get_firebase_backend_for_testing()
	var availability_success: bool = backend != null and is_instance_valid(backend)

	if availability_success:
		successful_tests += 1
	lifecycle_tests.append(
		{
			"test": "backend_availability",
			"success": availability_success,
			"backend_exists": backend != null,
			"backend_valid": is_instance_valid(backend) if backend else false
		}
	)

	if not backend:
		var failure_results: Dictionary = {
			"total_tests": total_tests,
			"successful_tests": successful_tests,
			"lifecycle_tests": lifecycle_tests,
			"lifecycle_validation": false
		}
		return DebugActionResult.new_failure(
			"Backend lifecycle test failed - backend not available",
			"BACKEND_UNAVAILABLE",
			DebugActionResult.ErrorCategory.DATABASE,
			failure_results,
			Time.get_ticks_msec() - start_time,
			action_name,
			{"test_type": "backend_lifecycle", "failed_at": "backend_availability_check"}
		)

	_update_status("Testing backend initialization state...")
	total_tests += 1
	var initialization_success: bool = backend.is_available()

	if initialization_success:
		successful_tests += 1
	lifecycle_tests.append(
		{
			"test": "backend_initialization",
			"success": initialization_success,
			"is_available": backend.is_available()
		}
	)

	_update_status("Testing DataSource integration...")
	total_tests += 1
	var datasource_integration: bool = data_source != null and data_source.is_initialized()

	if datasource_integration:
		successful_tests += 1
	lifecycle_tests.append(
		{
			"test": "datasource_integration",
			"success": datasource_integration,
			"datasource_exists": data_source != null,
			"datasource_initialized": data_source.is_initialized() if data_source else false
		}
	)

	_update_status("Testing backend method accessibility...")
	total_tests += 1
	var methods_accessible: bool = (
		backend.has_method("get_data")
		and backend.has_method("set_data")
		and backend.has_method("remove_data")
		and backend.has_method("push_data")
		and backend.has_method("is_available")
	)

	if methods_accessible:
		successful_tests += 1
	lifecycle_tests.append(
		{
			"test": "method_accessibility",
			"success": methods_accessible,
			"has_get_data": backend.has_method("get_data"),
			"has_set_data": backend.has_method("set_data"),
			"has_remove_data": backend.has_method("remove_data"),
			"has_push_data": backend.has_method("push_data"),
			"has_is_available": backend.has_method("is_available")
		}
	)

	_update_status("Testing basic operation functionality...")
	total_tests += 1
	var test_path: Array[Variant] = ["backend_tests", "lifecycle", "basic_op"]
	var test_key: String = "lifecycle_" + str(Time.get_ticks_msec())
	var test_value: String = "Lifecycle test value"

	var basic_op_success: bool = await test_backend_async_pattern(
		"set_data", test_path, test_key, test_value, "Lifecycle: Basic Op"
	)

	if basic_op_success:
		successful_tests += 1
	lifecycle_tests.append(
		{
			"test": "basic_operation",
			"success": basic_op_success,
			"operation": "set_data",
			"test_path": test_path,
			"test_key": test_key
		}
	)

	_update_status("Testing backend state consistency...")
	total_tests += 1
	var state_consistent: bool = (
		backend.is_available() == initialization_success  # State should be consistent
		and datasource_integration == (data_source != null and data_source.is_initialized())
	)  # Integration should be stable

	if state_consistent:
		successful_tests += 1
	lifecycle_tests.append(
		{
			"test": "state_consistency",
			"success": state_consistent,
			"availability_consistent": backend.is_available() == initialization_success,
			"integration_stable":
			datasource_integration == (data_source != null and data_source.is_initialized())
		}
	)

	var success_rate: float = float(successful_tests) / float(total_tests)
	var overall_success: bool = success_rate >= 0.8  # 80% of lifecycle tests should pass
	var total_duration: int = Time.get_ticks_msec() - start_time

	var test_results: Dictionary = {
		"total_tests": total_tests,
		"successful_tests": successful_tests,
		"success_rate": success_rate,
		"lifecycle_tests": lifecycle_tests,
		"lifecycle_validation": overall_success,
		"backend_final_state":
		{
			"available": backend.is_available() if backend else false,
			"datasource_initialized": data_source.is_initialized() if data_source else false
		}
	}

	if overall_success:
		_update_status(
			"Lifecycle test PASSED (" + str(successful_tests) + "/" + str(total_tests) + ")"
		)
		Log.info(
			"Backend lifecycle validation successful", test_results, ["debug", "backend_firebase"]
		)

		return DebugActionResult.new_success(
			"Backend lifecycle test completed successfully",
			total_duration,
			action_name,
			{
				"test_type": "backend_lifecycle",
				"lifecycle_tests": lifecycle_tests,
				"success_rate": success_rate,
				"total_tests": total_tests,
				"successful_tests": successful_tests,
				"backend_state": test_results["backend_final_state"]
			}
		)

	_update_status(
		"Lifecycle test FAILED (" + str(successful_tests) + "/" + str(total_tests) + ")", true
	)
	Log.error(
		"Backend lifecycle validation failed", test_results, ["debug", "backend_firebase", "error"]
	)

	return DebugActionResult.new_failure(
		"Backend lifecycle test failed - insufficient success rate",
		"LIFECYCLE_INSUFFICIENT",
		DebugActionResult.ErrorCategory.VALIDATION,
		test_results,
		total_duration,
		action_name,
		{
			"test_type": "backend_lifecycle",
			"lifecycle_tests": lifecycle_tests,
			"success_rate": success_rate,
			"total_tests": total_tests,
			"successful_tests": successful_tests,
			"minimum_required_rate": 0.8
		}
	)
