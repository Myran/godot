## Test Remote Config get_boolean method
class_name TestGetBoolean extends FirebaseTestActionBase

var _remote_config: RemoteConfigService


func _init() -> void:
	super("test.remote_config.get_boolean", _execute_test)
	set_category("Firebase SDK")
	set_group("Remote Config")
	set_description("Test Remote Config get_boolean: local defaults + remote fetch")
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

	# Check initial loaded state (may be false before first fetch)
	Log.info(
		"Remote Config initial state: available=%s, loaded=%s" % [
			_remote_config.is_available(),
			_remote_config.is_loaded()
		],
		{},
		[Log.TAG_FIREBASE]
	)

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
		Log.info(
			"fetch_and_activate returned: %s" % str(fetch_result),
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return _assertion_result()

	# === STEP 2: Verify remote boolean values ===
	# These values are set in Firebase Remote Config template
	# feature_enabled: true (remote)
	var feature_enabled: bool = _remote_config.get_boolean("feature_enabled", false)
	if not assert_true(
		feature_enabled, "get_boolean should return remote value true for feature_enabled"
	):
		return _assertion_result()

	# dark_mode: false (remote)
	var dark_mode: bool = _remote_config.get_boolean("dark_mode", true)
	if not assert_false(dark_mode, "get_boolean should return remote value false for dark_mode"):
		return _assertion_result()

	# === STEP 3: Test SDK default values (for keys not in remote) ===
	# Non-existent keys return SDK defaults (false for bool, 0 for int, "" for string)
	var non_existent: bool = _remote_config.get_boolean("truly_non_existent_key_xyz", true)
	if not assert_false(
		non_existent, "get_boolean should return false (SDK default) for unknown keys"
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
		{"feature_enabled": feature_enabled, "overridden": true}
	)
	return _assertion_result()
