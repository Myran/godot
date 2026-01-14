class_name CPPRTDBBlockingGetValueAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.database.get_value_blocking"
	description = "Test GetValue using blocking wait pattern (Firebase example pattern) - Task-434"


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	# Get the C++ FirebaseDatabase instance directly
	var db: Object = get_cpp_firebase_database()

	if not is_instance_valid(db):
		return DebugActionResult.failure("C++ FirebaseDatabase instance not available")

	Log.info(
		"[BLOCK] Testing GetValue with BLOCKING wait (Firebase example pattern)...",
		{"test": "get_value_blocking"},
		[Log.TAG_FIREBASE, Log.TAG_DEBUG]
	)

	# Call the C++ blocking test function (uses WaitForCompletion pattern)
	db.test_get_value_blocking()

	return DebugActionResult.success(
		{
			"message": "Blocking GetValue test completed - check logs for results",
			"pattern": "Uses while(future.status() == pending) Sleep(100) pattern",
			"note": "This mimics Firebase example's WaitForCompletion approach"
		}
	)
