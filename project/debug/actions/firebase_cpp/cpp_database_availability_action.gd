class_name CPPDatabaseAvailabilityAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.database_availability"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	var firebase_db_available: bool = ClassDB.class_exists("FirebaseDatabase")
	var firebase_auth_available: bool = ClassDB.class_exists("FirebaseAuth")

	var availability_info: Dictionary = {
		"firebase_database_available": firebase_db_available,
		"firebase_auth_available": firebase_auth_available,
		"platform": OS.get_name(),
		"godot_version": Engine.get_version_info(),
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info(
		"🔍 FIREBASE CLASS AVAILABILITY CHECK",
		availability_info,
		["debug", "cpp_firebase", "availability"]
	)

	var total_duration: int = Time.get_ticks_msec() - start_time

	return DebugActionResult.new_success(
		"Firebase class availability check completed",
		total_duration,
		action_name,
		availability_info
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = _execute_action_logic({})
	return result.is_success()
