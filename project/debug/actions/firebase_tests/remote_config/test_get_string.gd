## Test Remote Config get_string method
class_name TestGetString extends FirebaseTestActionBase

var _remote_config: RemoteConfigService


func _init() -> void:
	super("test.remote_config.get_string", _execute_test)
	set_category("Firebase SDK")
	set_group("Remote Config")
	set_description("Test Remote Config get_string: local defaults + remote fetch")
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
	var local_defaults: Dictionary = {"welcome_message": "LOCAL_DEFAULT", "local_only_key": "local_value"}
	var defaults_result: Variant = await _remote_config.set_defaults_async(local_defaults)

	# Verify set_defaults completed successfully
	if not assert_not_null(defaults_result, "set_defaults_async result should not be null"):
		return _assertion_result()
	if not assert_equals("ok", defaults_result.get("status", ""), "set_defaults_async should return status='ok'"):
		return _assertion_result()

	# === STEP 2: Verify local defaults are readable ===
	var local_value: String = _remote_config.get_string("welcome_message", "")
	if not assert_equals("LOCAL_DEFAULT", local_value, "get_string should return local default 'LOCAL_DEFAULT'"):
		return _assertion_result()

	var local_only: String = _remote_config.get_string("local_only_key", "")
	if not assert_equals("local_value", local_only, "get_string should return local default for local-only key"):
		return _assertion_result()

	# === STEP 3: Fetch remote config values ===
	var fetch_result: Variant = await _remote_config.fetch_and_activate()

	if not assert_not_null(fetch_result, "fetch_and_activate result should not be null"):
		return _assertion_result()
	if not assert_true(fetch_result is Dictionary, "fetch_and_activate result should be a Dictionary"):
		return _assertion_result()

	# === STEP 4: Verify remote values override local defaults ===
	# Remote value is "Hello, World!" - should override local "LOCAL_DEFAULT"
	var welcome: String = _remote_config.get_string("welcome_message", "")
	if not assert_equals("Hello, World!", welcome, "get_string should return remote value 'Hello, World!' overriding local default"):
		return _assertion_result()

	# Another remote value
	var app_name: String = _remote_config.get_string("app_name", "")
	if not assert_equals("GameTwo", app_name, "get_string should return remote value 'GameTwo'"):
		return _assertion_result()

	# === STEP 5: Verify local-only key still works ===
	var still_local: String = _remote_config.get_string("local_only_key", "")
	if not assert_equals("local_value", still_local, "get_string should still return local default for keys not in remote"):
		return _assertion_result()

	# === STEP 6: Test non-existent key returns natural default ===
	var non_existent: String = _remote_config.get_string("truly_non_existent_key", "custom_fallback")
	if not assert_equals("", non_existent, "get_string should return empty string (natural default) for unknown keys"):
		return _assertion_result()

	# Mark test as passed
	_pass()

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(
		action_name, "Firebase SDK", "Remote Config", duration,
		{"welcome_length": welcome.length(), "overridden": true}
	)
	return _assertion_result()
