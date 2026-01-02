class_name RemoteConfigGetKeysAction
extends CPPRemoteConfigDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.remote_config.get_keys"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing Remote Config key enumeration...")

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

	# Get all keys
	var all_keys: Array = rc.get_keys()

	# Get keys by prefix (common use case for feature flags)
	var feature_keys: Array = rc.get_keys_by_prefix("feature_")
	var config_keys: Array = rc.get_keys_by_prefix("config_")

	var metadata: Dictionary = {
		"operation": "get_keys",
		"total_keys": all_keys.size(),
		"all_keys": all_keys,
		"feature_keys_count": feature_keys.size(),
		"feature_keys": feature_keys,
		"config_keys_count": config_keys.size(),
		"config_keys": config_keys,
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info(
		"✅ Remote Config key enumeration completed",
		metadata,
		["debug", "cpp_firebase", "remote_config", "keys"]
	)

	return DebugActionResult.new_success(true, 0, action_name, metadata)
