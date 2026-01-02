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

	# Enable developer mode
	_remote_config.enable_developer_mode()

	# === STEP 1: Set local defaults (different from remote values) ===
	var local_defaults: Dictionary = {"feature_enabled": false, "dark_mode": true, "local_only_key": true}
	var defaults_result: Variant = await _remote_config.set_defaults_async(local_defaults)

	# Verify set_defaults completed successfully
	if not assert_not_null(defaults_result, "set_defaults_async result should not be null"):
		return _assertion_result()
	if not assert_equals("ok", defaults_result.get("status", ""), "set_defaults_async should return status='ok'"):
		return _assertion_result()

	# === STEP 2: Verify local defaults are readable ===
	var local_feature: bool = _remote_config.get_boolean("feature_enabled", false)
	if not assert_false(local_feature, "get_boolean should return local default false"):
		return _assertion_result()

	var local_dark_mode: bool = _remote_config.get_boolean("dark_mode", false)
	if not assert_true(local_dark_mode, "get_boolean should return local default true for dark_mode"):
		return _assertion_result()

	# === STEP 3: Fetch remote config values ===
	var fetch_result: Variant = await _remote_config.fetch_and_activate()

	if not assert_not_null(fetch_result, "fetch_and_activate result should not be null"):
		return _assertion_result()
	if not assert_true(fetch_result is Dictionary, "fetch_and_activate result should be a Dictionary"):
		return _assertion_result()

	# === STEP 4: Verify remote values override local defaults ===
	# Remote value for feature_enabled is true - should override local false
	var feature_enabled: bool = _remote_config.get_boolean("feature_enabled", false)
	if not assert_true(feature_enabled, "get_boolean should return remote value true overriding local default false"):
		return _assertion_result()

	# Remote value for dark_mode is false - should override local true
	var dark_mode: bool = _remote_config.get_boolean("dark_mode", true)
	if not assert_false(dark_mode, "get_boolean should return remote value false overriding local default true"):
		return _assertion_result()

	# === STEP 5: Verify local-only key still works ===
	var still_local: bool = _remote_config.get_boolean("local_only_key", false)
	if not assert_true(still_local, "get_boolean should still return local default for keys not in remote"):
		return _assertion_result()

	# === STEP 6: Test non-existent key returns natural default ===
	var non_existent: bool = _remote_config.get_boolean("truly_non_existent_key", true)
	if not assert_false(non_existent, "get_boolean should return false (natural default) for unknown keys"):
		return _assertion_result()

	# Mark test as passed
	_pass()

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(
		action_name, "Firebase SDK", "Remote Config", duration,
		{"feature_enabled": feature_enabled, "overridden": true}
	)
	return _assertion_result()
