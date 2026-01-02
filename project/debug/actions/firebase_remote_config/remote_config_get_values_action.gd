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

	# Test actual Firebase Remote Config values from template
	# Firebase Remote Config has: test_string, test_number, test_bool
	var test_configs: Array = [
		{"key": "test_string", "type": "string", "expected": "default remote config string"},
		{"key": "test_number", "type": "int", "expected": 420},
		{"key": "test_bool", "type": "boolean", "expected": true}
	]

	var results: Dictionary = {}

	var all_match: bool = true
	var validation_details: Array = []

	for config in test_configs:
		var key: String = config.key
		var value_type: String = config.type
		var expected_value: Variant = config.expected

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

		var matches: bool = value == expected_value
		if not matches:
			all_match = false

		results[key] = {
			"type": value_type, "value": value, "expected": expected_value, "matches": matches
		}

		validation_details.append(
			{"key": key, "value": str(value), "expected": str(expected_value), "matches": matches}
		)

		Log.debug(
			"Retrieved Remote Config value",
			{
				"key": key,
				"type": value_type,
				"value": value,
				"expected": expected_value,
				"matches": matches
			},
			["debug", "cpp_firebase", "remote_config", "values"]
		)

	var metadata: Dictionary = {
		"operation": "get_values",
		"test_count": test_configs.size(),
		"all_match": all_match,
		"results": results,
		"validation_details": validation_details,
		"timestamp": Time.get_unix_time_from_system()
	}

	if all_match:
		Log.info(
			"✅ Remote Config value retrieval test completed - ALL VALUES MATCH",
			metadata,
			["debug", "cpp_firebase", "remote_config", "values"]
		)
	else:
		Log.warn(
			"⚠️ Remote Config value retrieval test completed - SOME VALUES DON'T MATCH",
			metadata,
			["debug", "cpp_firebase", "remote_config", "values"]
		)

	return DebugActionResult.new_success(all_match, 0, action_name, metadata)
