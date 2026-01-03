## Test Remote Config get_int method
class_name TestGetInt extends FirebaseTestActionBase

var _remote_config: RemoteConfigService


func _init() -> void:
	super("test.remote_config.get_int", _execute_test)
	set_category("Firebase SDK")
	set_group("Remote Config")
	set_description("Test Remote Config get_int: remote values + SDK defaults")
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
	if not assert_equals(
		"ok", fetch_status, "fetch_and_activate should succeed (got: %s)" % fetch_status
	):
		Log.info("fetch_and_activate returned: %s" % str(fetch_result))
		return _assertion_result()

	# Log available keys for debugging
	var all_keys: Array = _remote_config.get_all_keys()
	Log.info("Remote Config available keys: %s" % str(all_keys), {}, [Log.TAG_FIREBASE])

	# === STEP 2: Verify remote int values ===
	var max_players: int = _remote_config.get_int("max_players", 0)
	Log.info(
		"Remote Config get_int('max_players', 0) returned: %d" % max_players, {}, [Log.TAG_FIREBASE]
	)
	if not assert_equals(
		100,
		max_players,
		"get_int should return remote value 100 for max_players (got: %d)" % max_players
	):
		return _assertion_result()

	var retry_count: int = _remote_config.get_int("retry_count", 0)
	if not assert_equals(3, retry_count, "get_int should return remote value 3 for retry_count"):
		return _assertion_result()

	# === STEP 3: Test SDK default values (for keys not in remote) ===
	var non_existent: int = _remote_config.get_int("truly_non_existent_key_xyz", 555)
	if not assert_equals(0, non_existent, "get_int should return 0 (SDK default) for unknown keys"):
		return _assertion_result()

	# Mark test as passed
	_pass()

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(
		action_name, "Firebase SDK", "Remote Config", duration, {"remote_max_players": max_players}
	)
	return _assertion_result()
