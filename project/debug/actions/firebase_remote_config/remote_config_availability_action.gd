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

	# CRITICAL: Set defaults BEFORE fetch_and_activate (required on Windows)
	# Use async version with signal to ensure defaults are set before proceeding
	var rc: Object = get_cpp_remote_config()
	if is_instance_valid(rc):
		if not rc.has_signal("set_defaults_completed"):
			return DebugActionResult.new_failure(
				"FirebaseRemoteConfig missing set_defaults_completed signal",
				"SIGNAL_NOT_FOUND",
				DebugActionResult.ErrorCategory.FIREBASE,
				null,
				0,
				action_name,
				{}
			)

		var defaults: Dictionary = {
			"test_string": "default remote config string", "test_number": 420, "test_bool": true
		}

		var request_id: int = Time.get_ticks_msec()
		rc.set_defaults_async(request_id, defaults)

		# Wait for completion signal
		var signal_result: Array = await rc.set_defaults_completed
		var recv_request_id: int = int(signal_result[0])
		var success: bool = bool(signal_result[1])
		var error_code: int = int(signal_result[2])
		var error_message: String = str(signal_result[3])

		if not success:
			return DebugActionResult.new_failure(
				"Set defaults failed: " + error_message,
				"SET_DEFAULTS_FAILED",
				DebugActionResult.ErrorCategory.FIREBASE,
				null,
				0,
				action_name,
				{"error_code": error_code, "error_message": error_message}
			)

		Log.info(
			"Set Remote Config defaults successfully",
			{"defaults": defaults.keys()},
			["debug", "cpp_firebase", "remote_config"]
		)

	var availability_check: Dictionary = await TestUtils.time_operation(
		"remote_config_availability_check", func() -> String: return "availability_check_complete"
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
