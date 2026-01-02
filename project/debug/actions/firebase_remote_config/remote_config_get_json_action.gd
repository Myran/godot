class_name RemoteConfigGetJSONAction
extends CPPRemoteConfigDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.remote_config.get_json"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing Remote Config JSON value retrieval...")

	var rc: Object = get_cpp_remote_config()
	if not is_instance_valid(rc):
		return DebugActionResult.new_failure(
			"FirebaseRemoteConfig C++ instance not available",
			"REMOTE_CONFIG_UNAVAILABLE",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	# Test JSON value retrieval
	# Common use case: complex configuration objects
	var test_keys: Array[String] = [
		"game_config", "feature_toggles", "ab_test_variants", "ui_settings"
	]

	var results: Dictionary = {}

	for key in test_keys:
		var json_result: Dictionary = rc.get_json(key)

		results[key] = {
			"success": json_result.get("success", false),
			"has_data": json_result.has("data"),
			"error": json_result.get("error", ""),
			"data_type": typeof(json_result.get("data", null))
		}

		if json_result.get("success", false):
			Log.debug(
				"Retrieved JSON config",
				{"key": key, "data": json_result.data},
				["debug", "cpp_firebase", "remote_config", "json"]
			)
		else:
			Log.debug(
				"JSON config not found or parse error",
				{"key": key, "error": json_result.get("error", "unknown")},
				["debug", "cpp_firebase", "remote_config", "json"]
			)

	var metadata: Dictionary = {
		"operation": "get_json",
		"test_count": test_keys.size(),
		"results": results,
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info(
		"✅ Remote Config JSON value retrieval test completed",
		metadata,
		["debug", "cpp_firebase", "remote_config", "json"]
	)

	return DebugActionResult.new_success(true, 0, action_name, metadata)
