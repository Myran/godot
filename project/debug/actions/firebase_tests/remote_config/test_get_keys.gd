## Test Remote Config get_keys method (key enumeration)
class_name TestGetKeys extends FirebaseTestActionBase

var _remote_config: RemoteConfigService


func _init() -> void:
	super("test.remote_config.get_keys", _execute_test)
	set_category("Firebase SDK")
	set_group("Remote Config")
	set_description("Test Remote Config get_keys: local defaults + remote fetch")
	set_use_auto_success_logging(false)


func _execute_test() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	if not should_run_on_platform():
		return _skip_result("Platform not supported")

	# Get Remote Config service
	_remote_config = FirebaseService.get_remote_config()
	if not assert_not_null(_remote_config, "RemoteConfigService should not be null"):
		return _assertion_result()

	if not assert_true(_remote_config.is_available(), "RemoteConfigService should be available"):
		return _assertion_result()

	# Enable developer mode
	_remote_config.enable_developer_mode()

	# === STEP 1: Set local defaults ===
	var local_defaults: Dictionary = {
		"local_feature_1": true, "local_feature_2": false, "local_setting": "value1"
	}
	var defaults_result: Variant = await _remote_config.set_defaults_async(local_defaults)

	# Verify set_defaults completed successfully
	if not assert_not_null(defaults_result, "set_defaults_async result should not be null"):
		return _assertion_result()
	if not assert_equals("ok", defaults_result.get("status", ""), "set_defaults_async should return status='ok'"):
		return _assertion_result()

	# === STEP 2: Verify local keys are available ===
	var local_keys: Array = _remote_config.get_all_keys()
	if not assert_true(local_keys is Array, "get_all_keys should return an Array"):
		return _assertion_result()

	if not assert_true(local_keys.size() >= 3, "get_all_keys should return at least 3 local keys"):
		return _assertion_result()

	# Check that our local keys exist
	if not assert_true("local_feature_1" in local_keys, "local_feature_1 should be in keys"):
		return _assertion_result()

	if not assert_true("local_setting" in local_keys, "local_setting should be in keys"):
		return _assertion_result()

	# Test get_keys_with_prefix for local keys
	var local_feature_keys: Array = _remote_config.get_keys_with_prefix("local_")
	if not assert_true(local_feature_keys is Array, "get_keys_with_prefix should return an Array"):
		return _assertion_result()

	if not assert_true(local_feature_keys.size() >= 3, "get_keys_with_prefix('local_') should return at least 3 keys"):
		return _assertion_result()

	# === STEP 3: Fetch remote config values ===
	var fetch_result: Variant = await _remote_config.fetch_and_activate()

	if not assert_not_null(fetch_result, "fetch_and_activate result should not be null"):
		return _assertion_result()
	if not assert_true(fetch_result is Dictionary, "fetch_and_activate result should be a Dictionary"):
		return _assertion_result()

	# === STEP 4: Verify remote keys are available (merged with local) ===
	var all_keys: Array = _remote_config.get_all_keys()
	if not assert_true(all_keys is Array, "get_all_keys should return an Array"):
		return _assertion_result()

	# After fetch, should have more keys (remote + local)
	if not assert_true(all_keys.size() >= 3, "get_all_keys should return keys from both remote and local"):
		return _assertion_result()

	# Remote keys from Firebase MCP should be present
	if not assert_true("welcome_message" in all_keys or "max_players" in all_keys, "Remote keys should be present after fetch"):
		return _assertion_result()

	# Local keys should still be present
	if not assert_true("local_feature_1" in all_keys, "Local keys should still be present after fetch"):
		return _assertion_result()

	# Test prefix filtering with remote keys
	var feature_keys: Array = _remote_config.get_keys_with_prefix("feature_")
	if not assert_true(feature_keys is Array, "get_keys_with_prefix should return an Array"):
		return _assertion_result()

	# Mark test as passed
	_pass()

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(
		action_name,
		"Firebase SDK",
		"Remote Config",
		duration,
		{"total_keys": all_keys.size(), "local_keys": local_keys.size()}
	)
	return _assertion_result()
