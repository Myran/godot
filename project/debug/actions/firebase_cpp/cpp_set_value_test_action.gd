# project/debug/actions/firebase_cpp/cpp_set_value_test_action.gd
@tool
class_name CPPSetValueTestAction  
extends CPPFirebaseDebugAction

func _init() -> void:
	super._init()
	action_name = "C++ Set Value Test"

func execute_cpp_action() -> bool:
	_update_status("Executing C++ direct set value test...")
	
	var test_path = ["cpp_tests", "direct", "set_value", str(Time.get_ticks_msec())]
	var test_value = "CPP Direct Value: " + str(Time.get_ticks_msec())
	
	var result = await execute_cpp_operation("set_value_async", [test_path, test_value], "C++ Set Value")
	
	var success = result != null
	execution_completed.emit(success, {"result": result})
	return success
