# Task-434: Diagnostic test for Firebase RTDB SetValue on Windows
# Tests if SetValue works before attempting GetValue

extends CPPFirebaseDebugAction
class_name CppRtdbSetValueDiagnosticAction

func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var db: Object = get_cpp_firebase_database()
	if not is_instance_valid(db):
		return DebugActionResult.failure("C++ FirebaseDatabase instance not available")

	# Call the diagnostic function
	db.test_set_value_diagnostic()

	return DebugActionResult.success({"message": "SetValue diagnostic test completed"})
