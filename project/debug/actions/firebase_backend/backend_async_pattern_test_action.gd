# project/debug/actions/firebase_backend/backend_async_pattern_test_action.gd
@tool
class_name BackendAsyncPatternTestAction
extends BackendFirebaseDebugAction

func _init() -> void:
	super._init()
	action_name = "Backend Async Pattern Test"

func execute_backend_action() -> bool:
	_update_status("Testing Firebase Backend async patterns...")
	
	var test_path = ["backend_tests", "async_pattern"]
	var test_key = "test_" + str(Time.get_ticks_msec())
	var test_value = "Backend Async Test: " + str(Time.get_ticks_msec())
	
	# Test set_data pattern
	var set_success = await test_backend_async_pattern("set_data", test_path, test_key, test_value, "Backend Set Data")
	
	if not set_success:
		execution_completed.emit(false, {"error": "Set operation failed"})
		return false
	
	# Test get_data pattern  
	var get_success = await test_backend_async_pattern("get_data", test_path, test_key, null, "Backend Get Data")
	
	var overall_success = set_success and get_success
	
	if overall_success:
		_update_status("Backend async pattern test PASSED")
	else:
		_update_status("Backend async pattern test FAILED", true)
	
	execution_completed.emit(overall_success, {"set_success": set_success, "get_success": get_success})
	return overall_success
