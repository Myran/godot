class_name RemoteConfigAvailabilityAction
extends CPPRemoteConfigDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.remote_config.availability"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var remote_config_available: bool = ClassDB.class_exists("FirebaseRemoteConfig")
	var firebase_app_available: bool = ClassDB.class_exists("FirebaseApp")

	var availability_info: Dictionary = {
		"firebase_remote_config_available": remote_config_available,
		"firebase_app_available": firebase_app_available,
		"platform": OS.get_name(),
		"godot_version": Engine.get_version_info(),
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info(
		"🔍 FIREBASE REMOTE CONFIG AVAILABILITY CHECK",
		availability_info,
		["debug", "cpp_firebase", "remote_config", "availability"]
	)

	var availability_check: Dictionary = await TestUtils.time_operation(
		"remote_config_availability_check",
		func() -> String: return "availability_check_complete"
	)

	return TestUtils.make_success_result(
		"Firebase Remote Config class availability check completed",
		TestUtils.get_duration_ms(availability_check),
		action_name,
		TestUtils.make_metadata("cpp_remote_config_availability", availability_info)
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
