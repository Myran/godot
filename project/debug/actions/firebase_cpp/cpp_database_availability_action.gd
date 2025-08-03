# project/debug/actions/firebase_cpp/cpp_database_availability_action.gd
class_name CPPDatabaseAvailabilityAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.database_availability"


# Modern DebugAction.Result pattern
func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()

	# Check Firebase class availability
	var firebase_db_available: bool = ClassDB.class_exists("FirebaseDatabase")
	var firebase_auth_available: bool = ClassDB.class_exists("FirebaseAuth")

	var availability_info: Dictionary = {
		"firebase_database_available": firebase_db_available,
		"firebase_auth_available": firebase_auth_available,
		"platform": OS.get_name(),
		"godot_version": Engine.get_version_info(),
		"timestamp": Time.get_unix_time_from_system()
	}

	# Log availability information prominently
	Log.info(
		"🔍 FIREBASE CLASS AVAILABILITY CHECK",
		availability_info,
		["debug", "cpp_firebase", "availability"]
	)

	var total_duration: int = Time.get_ticks_msec() - start_time

	# Action succeeds regardless of availability - we just want the information
	return DebugAction.Result.new_success(
		"Firebase class availability check completed",
		total_duration,
		action_name,
		availability_info
	)


# Legacy method for compatibility
func execute_cpp_action() -> bool:
	var result: DebugAction.Result = _execute_action_logic({})
	return result.is_success()
