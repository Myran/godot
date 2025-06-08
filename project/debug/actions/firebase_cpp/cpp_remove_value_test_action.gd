# project/debug/actions/firebase_cpp/cpp_remove_value_test_action.gd
class_name CPPRemoveValueTestAction
extends CPPFirebaseDebugAction

func _init() -> void:
	super._init()
	action_name = "C++ Remove Value Test"

func execute_cpp_action() -> bool:
	_update_status("Executing C++ direct remove value test...")
	
	# First set a value directly via C++
	var test_path = ["cpp_tests", "direct", "remove_value", str(Time.get_ticks_msec())]
	var test_value = "CPP Remove Test Value: " + str(Time.get_ticks_msec())
	
	_update_status("Setting test value via C++...")
	var set_result = await execute_cpp_operation("set_value_async", [test_path, test_value], "C++ Set (for Remove test)")
	
	if not set_result:
		return false
	
	# Now remove the value directly via C++
	_update_status("Removing value via C++...")
	var remove_result = await execute_cpp_operation("remove_value_async", [test_path], "C++ Remove Value")
	
	var success = remove_result != null
	
	if success:
		Log.info("C++ Remove test successful", {"test_path": test_path}, ["debug", "cpp_firebase"])
		_update_status("C++ Remove Value test PASSED")
	else:
		Log.error("C++ Remove test failed", {"test_path": test_path}, ["debug", "cpp_firebase", "error"])
		_update_status("C++ Remove Value test FAILED", true)
	
	return success
