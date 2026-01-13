class_name CPPGetValueDiagnosticAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.database.get_value_diagnostic"
	description = "Diagnostic test to isolate Windows RTDB GetValue crash (Task-434)"


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	# Get the C++ FirebaseDatabase instance directly
	var db: Object = get_cpp_firebase_database()

	if not is_instance_valid(db):
		return DebugActionResult.failure("C++ FirebaseDatabase instance not available")

	# Call the C++ diagnostic function
	Log.info(
		"[DIAG] Calling C++ diagnostic test...",
		{"test": "get_value_diagnostic"},
		[Log.TAG_FIREBASE, Log.TAG_DEBUG]
	)

	# This will print detailed diagnostic logs showing exactly where the crash occurs
	db.test_get_value_diagnostic()

	return DebugActionResult.success(
		{
			"message": "Diagnostic test completed - check logs for step-by-step results",
			"note": "If app crashes during test, last log line shows crash point"
		}
	)
