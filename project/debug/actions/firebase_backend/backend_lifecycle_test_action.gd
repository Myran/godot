# project/debug/actions/firebase_backend/backend_lifecycle_test_action.gd
@tool
class_name BackendLifecycleTestAction
extends BackendFirebaseDebugAction

func _init() -> void:
	super._init()
	action_name = "Backend Lifecycle Test"

func execute_backend_action() -> bool:
	_update_status("Testing Firebase Backend lifecycle...")
	
	var lifecycle_tests = []
	var successful_tests = 0
	var total_tests = 0
	
	# Test 1: Backend availability check
	_update_status("Testing backend availability...")
	total_tests += 1
	var backend = get_firebase_backend_for_testing()
	var availability_success = backend != null and is_instance_valid(backend)
	
	if availability_success: successful_tests += 1
	lifecycle_tests.append({
		"test": "backend_availability",
		"success": availability_success,
		"backend_exists": backend != null,
		"backend_valid": is_instance_valid(backend) if backend else false
	})
	
	if not backend:
		var test_results = {
			"total_tests": total_tests,
			"successful_tests": successful_tests,
			"lifecycle_tests": lifecycle_tests,
			"lifecycle_validation": false
		}
		execution_completed.emit(false, test_results)
		return false
	
	# Test 2: Backend initialization state
	_update_status("Testing backend initialization state...")
	total_tests += 1
	var initialization_success = backend.is_available()
	
	if initialization_success: successful_tests += 1
	lifecycle_tests.append({
		"test": "backend_initialization",
		"success": initialization_success,
		"is_available": backend.is_available()
	})
	
	# Test 3: DataSource integration
	_update_status("Testing DataSource integration...")
	total_tests += 1
	var datasource_integration = data_source != null and data_source.is_initialized()
	
	if datasource_integration: successful_tests += 1
	lifecycle_tests.append({
		"test": "datasource_integration",
		"success": datasource_integration,
		"datasource_exists": data_source != null,
		"datasource_initialized": data_source.is_initialized() if data_source else false
	})
	
	# Test 4: Backend method accessibility
	_update_status("Testing backend method accessibility...")
	total_tests += 1
	var methods_accessible = (
		backend.has_method("get_data") and 
		backend.has_method("set_data") and 
		backend.has_method("remove_data") and 
		backend.has_method("push_data") and
		backend.has_method("is_available")
	)
	
	if methods_accessible: successful_tests += 1
	lifecycle_tests.append({
		"test": "method_accessibility",
		"success": methods_accessible,
		"has_get_data": backend.has_method("get_data"),
		"has_set_data": backend.has_method("set_data"),
		"has_remove_data": backend.has_method("remove_data"),
		"has_push_data": backend.has_method("push_data"),
		"has_is_available": backend.has_method("is_available")
	})
	
	# Test 5: Basic operation functionality (lightweight test)
	_update_status("Testing basic operation functionality...")
	total_tests += 1
	var test_path = ["backend_tests", "lifecycle", "basic_op"]
	var test_key = "lifecycle_" + str(Time.get_ticks_msec())
	var test_value = "Lifecycle test value"
	
	var basic_op_success = await test_backend_async_pattern("set_data", test_path, test_key, test_value, "Lifecycle: Basic Op")
	
	if basic_op_success: successful_tests += 1
	lifecycle_tests.append({
		"test": "basic_operation",
		"success": basic_op_success,
		"operation": "set_data",
		"test_path": test_path,
		"test_key": test_key
	})
	
	# Test 6: Backend state consistency
	_update_status("Testing backend state consistency...")
	total_tests += 1
	var state_consistent = (
		backend.is_available() == initialization_success and  # State should be consistent
		datasource_integration == (data_source != null and data_source.is_initialized())  # Integration should be stable
	)
	
	if state_consistent: successful_tests += 1
	lifecycle_tests.append({
		"test": "state_consistency",
		"success": state_consistent,
		"availability_consistent": backend.is_available() == initialization_success,
		"integration_stable": datasource_integration == (data_source != null and data_source.is_initialized())
	})
	
	# Calculate success rate
	var success_rate = float(successful_tests) / float(total_tests)
	var overall_success = success_rate >= 0.8  # 80% of lifecycle tests should pass
	
	var test_results = {
		"total_tests": total_tests,
		"successful_tests": successful_tests,
		"success_rate": success_rate,
		"lifecycle_tests": lifecycle_tests,
		"lifecycle_validation": overall_success,
		"backend_final_state": {
			"available": backend.is_available() if backend else false,
			"datasource_initialized": data_source.is_initialized() if data_source else false
		}
	}
	
	if overall_success:
		_update_status("Lifecycle test PASSED (" + str(successful_tests) + "/" + str(total_tests) + ")")
		Log.info("Backend lifecycle validation successful", test_results, ["debug", "backend_firebase"])
	else:
		_update_status("Lifecycle test FAILED (" + str(successful_tests) + "/" + str(total_tests) + ")", true)
		Log.error("Backend lifecycle validation failed", test_results, ["debug", "backend_firebase", "error"])
	
	execution_completed.emit(overall_success, test_results)
	return overall_success
