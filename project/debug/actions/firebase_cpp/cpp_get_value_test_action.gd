# project/debug/actions/firebase_cpp/cpp_get_value_test_action.gd
@tool
class_name CPPGetValueTestAction
extends CPPFirebaseDebugAction

func _init() -> void:
	super._init()
	action_name = "C++ Get Value Test"

func execute_cpp_action() -> bool:
	_update_status("Executing C++ direct get value test...")
	
	# First set a value directly via C++
	var test_path = ["cpp_tests", "direct", "get_value", str(Time.get_ticks_msec())]
	var test_value = "CPP Get Test Value: " + str(Time.get_ticks_msec())
	
	_update_status("Setting test value via C++...")
	var set_result = await execute_cpp_operation("set_value_async", [test_path, test_value], "C++ Set (for Get test)")
	
	if not set_result:
		execution_completed.emit(false, {"error": "Failed to set test value"})
		return false
	
	# Now get the value directly via C++
	_update_status("Getting value via C++...")
	var get_result = await execute_cpp_operation("get_value_async", [test_path], "C++ Get Value")
	
	var success = get_result != null
	
	if success:
		Log.info("C++ Get test successful", {"test_path": test_path}, ["debug", "cpp_firebase"])
		_update_status("C++ Get Value test PASSED")
	else:
		Log.error("C++ Get test failed", {"test_path": test_path}, ["debug", "cpp_firebase", "error"])
		_update_status("C++ Get Value test FAILED", true)
	
	execution_completed.emit(success, {"result": get_result})
	return success
