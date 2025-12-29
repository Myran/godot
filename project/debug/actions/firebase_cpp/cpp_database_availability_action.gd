class_name CPPDatabaseAvailabilityAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.database_availability"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	# Create availability info directly to avoid unsafe cast
	var firebase_db_available: bool = ClassDB.class_exists("FirebaseDatabase")
	var firebase_auth_available: bool = ClassDB.class_exists("FirebaseAuth")

	var availability_info: Dictionary = {
		"firebase_database_available": firebase_db_available,
		"firebase_auth_available": firebase_auth_available,
		"platform": OS.get_name(),
		"godot_version": Engine.get_version_info(),
		"timestamp": Time.get_unix_time_from_system()
	}

	# Guard against shutdown (task-396)
	_safe_log_info(
		"🔍 FIREBASE CLASS AVAILABILITY CHECK",
		availability_info,
		["debug", "cpp_firebase", "availability"]
	)

	# Use simple timing helper for the overall duration
	var availability_check: Dictionary = await TestUtils.time_operation(
		"availability_check", func() -> String: return "availability_check_complete"
	)
	return TestUtils.make_success_result(
		"Firebase class availability check completed",
		TestUtils.get_duration_ms(availability_check),
		action_name,
		TestUtils.make_metadata("cpp_database_availability", availability_info)
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
