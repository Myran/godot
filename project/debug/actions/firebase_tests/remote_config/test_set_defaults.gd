## Test Remote Config set_defaults method
class_name TestSetDefaults extends FirebaseTestActionBase

var _remote_config: RemoteConfigService


func _init() -> void:
	super("test.remote_config.set_defaults", _execute_test)
	set_category("Firebase SDK")
	set_group("Remote Config")
	set_description("Test Remote Config set_defaults: set + verify values readable")
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

	# === STEP 1: Set defaults ===
	var test_defaults: Dictionary = {
		"test_string": "default_value", "test_bool": true, "test_int": 42, "test_float": 3.14
	}
	var result: Variant = await _remote_config.set_defaults_async(test_defaults)

	if not assert_not_null(result, "set_defaults_async result should not be null"):
		return _assertion_result()

	if not assert_true(result is Dictionary, "set_defaults_async result should be a Dictionary"):
		return _assertion_result()

	# === STEP 2: Verify set_defaults completed successfully ===
	if not assert_equals("ok", result.get("status", ""), "set_defaults_async should return status='ok'"):
		return _assertion_result()

	# === STEP 3: Verify all set defaults are readable ===
	var test_string: String = _remote_config.get_string("test_string", "")
	if not assert_equals("default_value", test_string, "get_string should return set default 'default_value'"):
		return _assertion_result()

	var test_bool: bool = _remote_config.get_boolean("test_bool", false)
	if not assert_true(test_bool, "get_boolean should return set default true"):
		return _assertion_result()

	var test_int: int = _remote_config.get_int("test_int", 0)
	if not assert_equals(42, test_int, "get_int should return set default 42"):
		return _assertion_result()

	# Mark test as passed
	_pass()

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(
		action_name,
		"Firebase SDK",
		"Remote Config",
		duration,
		{"defaults_count": test_defaults.size(), "all_verified": true}
	)
	return _assertion_result()
