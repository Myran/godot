# project/debug/actions/firebase_backend/backend_async_pattern_test_action.gd
class_name BackendAsyncPatternTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "Backend Async Pattern Test"


# New DebugAction.Result pattern - this is the future
func _execute_action_logic(params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Testing Firebase Backend async patterns...")

	var test_path = ["backend_tests", "async_pattern"]
	var test_key = "test_" + str(Time.get_ticks_msec())
	var test_value = "Backend Async Test: " + str(Time.get_ticks_msec())

	# Test set_data pattern
	var set_success = await test_backend_async_pattern(
		"set_data", test_path, test_key, test_value, "Backend Set Data"
	)

	if not set_success:
		return DebugAction.Result.new_failure(
			"Backend async pattern test failed during set operation",
			"SET_OPERATION_FAILED",
			DebugAction.Result.ErrorCategory.DATABASE,
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

	# Test get_data pattern
	var get_success = await test_backend_async_pattern(
		"get_data", test_path, test_key, null, "Backend Get Data"
	)

	var overall_success = set_success and get_success
	var total_duration: int = Time.get_ticks_msec() - start_time

	if overall_success:
		_update_status("Backend async pattern test PASSED")
		return DebugAction.Result.new_success(
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
	else:
		_update_status("Backend async pattern test FAILED", true)
		return DebugAction.Result.new_failure(
			"Backend async pattern test failed during get operation",
			"GET_OPERATION_FAILED",
			DebugAction.Result.ErrorCategory.DATABASE,
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


# Legacy method for compatibility - delegates to new pattern
func execute_backend_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()
