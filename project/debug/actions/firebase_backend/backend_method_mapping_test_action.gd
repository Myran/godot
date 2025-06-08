# project/debug/actions/firebase_backend/backend_method_mapping_test_action.gd
class_name BackendMethodMappingTestAction
extends BackendFirebaseDebugAction

func _init() -> void:
	super._init()
	action_name = "Backend Method Mapping Test"

func execute_backend_action() -> bool:
	_update_status("Testing Firebase Backend method mappings...")
	
	var backend = get_firebase_backend_for_testing()
	if not backend:
		return false
	
	var test_base_path = ["backend_tests", "method_mapping"]
	var test_timestamp = str(Time.get_ticks_msec())
	var method_results = {}
	var total_methods = 0
	var successful_methods = 0
	
	# Test 1: set_data method
	_update_status("Testing set_data method mapping...")
	total_methods += 1
	var set_path = test_base_path + ["set_test"]
	var set_key = "set_" + test_timestamp
	var set_value = "Set method test value"
	
	var set_success = await test_backend_async_pattern("set_data", set_path, set_key, set_value, "Method: set_data")
	method_results["set_data"] = {"success": set_success, "tested": true}
	if set_success: successful_methods += 1
	
	# Test 2: get_data method (using the value we just set)
	_update_status("Testing get_data method mapping...")
	total_methods += 1
	var get_success = await test_backend_async_pattern("get_data", set_path, set_key, null, "Method: get_data")
	method_results["get_data"] = {"success": get_success, "tested": true}
	if get_success: successful_methods += 1
	
	# Test 3: push_data method
	_update_status("Testing push_data method mapping...")
	total_methods += 1
	var push_path = test_base_path + ["push_test"]
	var push_value = {"message": "Push method test", "timestamp": test_timestamp}
	
	var push_success = await test_backend_async_pattern("push_data", push_path, "", push_value, "Method: push_data")
	method_results["push_data"] = {"success": push_success, "tested": true}
	if push_success: successful_methods += 1
	
	# Test 4: remove_data method (remove the set value)
	_update_status("Testing remove_data method mapping...")
	total_methods += 1
	var remove_success = await test_backend_async_pattern("remove_data", set_path, set_key, null, "Method: remove_data")
	method_results["remove_data"] = {"success": remove_success, "tested": true}
	if remove_success: successful_methods += 1
	
	# Calculate success rate
	var success_rate = float(successful_methods) / float(total_methods)
	var overall_success = success_rate >= 0.75  # 75% of methods must work
	
	var test_results = {
		"total_methods_tested": total_methods,
		"successful_methods": successful_methods,
		"success_rate": success_rate,
		"method_details": method_results,
		"mapping_validation": overall_success,
		"backend_available": backend.is_available()
	}
	
	if overall_success:
		_update_status("Method Mapping test PASSED (" + str(successful_methods) + "/" + str(total_methods) + ")")
		Log.info("Backend method mapping validation successful", test_results, ["debug", "backend_firebase"])
	else:
		_update_status("Method Mapping test FAILED (" + str(successful_methods) + "/" + str(total_methods) + ")", true)
		Log.error("Backend method mapping validation failed", test_results, ["debug", "backend_firebase", "error"])
	
	return overall_success
