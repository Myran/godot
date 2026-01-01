class_name RemoteConfigGetValuesAction
extends CPPRemoteConfigDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.remote_config.get_values"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing Remote Config value retrieval...")

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

	# Test different value types with defaults
	var test_configs: Array = [
		{"key": "feature_enabled", "type": "boolean", "default": false},
		{"key": "welcome_message", "type": "string", "default": "Welcome!"},
		{"key": "max_level", "type": "int", "default": 10},
		{"key": "difficulty_multiplier", "type": "float", "default": 1.0}
	]

	var results: Dictionary = {}

	for config in test_configs:
		var key: String = config.key
		var value_type: String = config.type
		var default_value: Variant = config.default

		var value: Variant = null
		match value_type:
			"boolean":
				value = rc.get_boolean(key)
			"string":
				value = rc.get_string(key)
			"int":
				value = rc.get_int(key)
			"float":
				value = rc.get_double(key)

		# If no value is set, use the default
		if value == null:
			value = default_value

		results[key] = {
			"type": value_type,
			"value": value,
			"default_used": value == default_value
		}

		Log.debug(
			"Retrieved Remote Config value",
			{"key": key, "type": value_type, "value": value},
			["debug", "cpp_firebase", "remote_config", "values"]
		)

	var metadata: Dictionary = {
		"operation": "get_values",
		"test_count": test_configs.size(),
		"results": results,
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info(
		"✅ Remote Config value retrieval test completed",
		metadata,
		["debug", "cpp_firebase", "remote_config", "values"]
	)

	return DebugActionResult.new_success(
		true,
		0,
		action_name,
		metadata
	)
