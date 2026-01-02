## Test Remote Config get_int method
class_name TestGetInt extends FirebaseTestActionBase

var _remote_config: RemoteConfigService


func _init() -> void:
	super("test.remote_config.get_int", _execute_test)
	set_category("Firebase SDK")
	set_group("Remote Config")
	set_description("Test Remote Config get_int: local defaults + remote fetch")
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
	var local_defaults: Dictionary = {"local_test_value": 42, "another_local": 99}
	var defaults_result: Variant = await _remote_config.set_defaults_async(local_defaults)

	# Verify set_defaults completed successfully
	if not assert_not_null(defaults_result, "set_defaults_async result should not be null"):
		return _assertion_result()
	if not assert_equals("ok", defaults_result.get("status", ""), "set_defaults_async should return status='ok'"):
		return _assertion_result()

	# === STEP 2: Verify local defaults are readable ===
	var local_value: int = _remote_config.get_int("local_test_value", 0)
	if not assert_equals(42, local_value, "get_int should return local default value 42"):
		return _assertion_result()

	var another_local: int = _remote_config.get_int("another_local", 0)
	if not assert_equals(99, another_local, "get_int should return local default value 99"):
		return _assertion_result()

	# === STEP 3: Fetch remote config values ===
	var fetch_result: Variant = await _remote_config.fetch_and_activate()

	if not assert_not_null(fetch_result, "fetch_and_activate result should not be null"):
		return _assertion_result()
	if not assert_true(fetch_result is Dictionary, "fetch_and_activate result should be a Dictionary"):
		return _assertion_result()

	# === STEP 4: Verify remote values are accessible ===
	# These values were set via Firebase MCP in Remote Config template
	var max_players: int = _remote_config.get_int("max_players", 0)
	if not assert_equals(100, max_players, "get_int should return remote value 100 for max_players"):
		return _assertion_result()

	var retry_count: int = _remote_config.get_int("retry_count", 0)
	if not assert_equals(3, retry_count, "get_int should return remote value 3 for retry_count"):
		return _assertion_result()

	# === STEP 5: Verify local defaults still work for keys not in remote ===
	var still_local: int = _remote_config.get_int("local_test_value", 0)
	if not assert_equals(42, still_local, "get_int should still return local default 42 for keys not in remote"):
		return _assertion_result()

	# === STEP 6: Test non-existent key returns natural default ===
	var non_existent: int = _remote_config.get_int("truly_non_existent_key", 555)
	if not assert_equals(0, non_existent, "get_int should return 0 (natural int default) for unknown keys"):
		return _assertion_result()

	# Mark test as passed
	_pass()

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(
		action_name, "Firebase SDK", "Remote Config", duration,
		{"local_value": local_value, "remote_max_players": max_players}
	)
	return _assertion_result()
