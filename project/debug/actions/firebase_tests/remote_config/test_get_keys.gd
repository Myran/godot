## Test Remote Config get_keys method (key enumeration)
class_name TestGetKeys extends FirebaseTestActionBase

var _remote_config: RemoteConfigService


func _init() -> void:
	super("test.remote_config.get_keys", _execute_test)
	set_category("Firebase SDK")
	set_group("Remote Config")
	set_description("Test Remote Config get_keys: remote keys enumeration")
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

	# Enable developer mode (bypasses fetch throttling)
	_remote_config.enable_developer_mode()

	# === STEP 1: Fetch remote config values ===
	var fetch_result: Variant = await _remote_config.fetch_and_activate()

	if not assert_not_null(fetch_result, "fetch_and_activate result should not be null"):
		return _assertion_result()
	if not assert_true(
		fetch_result is Dictionary, "fetch_and_activate result should be a Dictionary"
	):
		return _assertion_result()

	# Check if fetch succeeded (not throttled or errored)
	var fetch_status: String = fetch_result.get("status", "unknown")
	if not assert_equals("ok", fetch_status, "fetch_and_activate should succeed (got: %s)" % fetch_status):
		Log.info("fetch_and_activate returned: %s" % str(fetch_result))
		return _assertion_result()

	# === STEP 2: Verify remote keys are available ===
	var all_keys: Array = _remote_config.get_all_keys()
	if not assert_true(all_keys is Array, "get_all_keys should return an Array"):
		return _assertion_result()

	# Remote keys from Firebase template should be present
	if not assert_true("welcome_message" in all_keys, "welcome_message should be in keys"):
		return _assertion_result()

	if not assert_true("max_players" in all_keys, "max_players should be in keys"):
		return _assertion_result()

	if not assert_true("feature_enabled" in all_keys, "feature_enabled should be in keys"):
		return _assertion_result()

	# === STEP 3: Test prefix filtering ===
	var feature_keys: Array = _remote_config.get_keys_with_prefix("feature_")
	if not assert_true(
		feature_keys is Array, "get_keys_with_prefix('feature_') should return an Array"
	):
		return _assertion_result()

	# Mark test as passed
	_pass()

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(
		action_name,
		"Firebase SDK",
		"Remote Config",
		duration,
		{"total_keys": all_keys.size(), "feature_keys": feature_keys.size()}
	)
	return _assertion_result()
