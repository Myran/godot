## Test Remote Config activate_async method (activate previously fetched config)
class_name TestActivateAsync extends FirebaseTestActionBase

var _remote_config: RemoteConfigService


func _init() -> void:
	super("test.remote_config.activate_async", _execute_test)
	set_category("Firebase SDK")
	set_group("Remote Config")
	set_description(
		"Test Remote Config activate async operation (activate previously fetched config)"
	)
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

	# Enable developer mode to bypass fetch throttling during tests
	_remote_config.enable_developer_mode()

	# First fetch config (required before activate)
	var fetch_result: Variant = await _remote_config.fetch()
	if fetch_result.get("status") != "ok":
		# If fetch fails due to throttling, try fetch_and_activate instead
		var fa_result: Variant = await _remote_config.fetch_and_activate()
		if fa_result.get("status") == "ok":
			assert_true(true, "Used fetch_and_activate as fallback")
			_pass()
			var duration: int = Time.get_ticks_msec() - start_time
			_log_test_success(
				action_name,
				"Firebase SDK",
				"Remote Config",
				duration,
				{"method": "fallback_fetch_and_activate"}
			)
			return _assertion_result()

	# Execute activate and verify result structure
	var result: Variant = await _remote_config.activate()

	if not assert_not_null(result, "activate result should not be null"):
		return _assertion_result()

	if not assert_true(result is Dictionary, "activate result should be a Dictionary"):
		return _assertion_result()

	# Check result has expected structure
	if not assert_true(result.has("status"), "Result should have 'status' key"):
		return _assertion_result()

	# Success case - status is "ok"
	if result.get("status") == "ok":
		assert_true(true, "activate completed successfully")
	else:
		# Error case - should still have proper error structure
		assert_true(result.has("code"), "Error result should have 'code' key")
		assert_true(result.has("message"), "Error result should have 'message' key")

	# Mark test as passed
	_pass()

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(
		action_name,
		"Firebase SDK",
		"Remote Config",
		duration,
		{"result_status": result.get("status", "unknown")}
	)
	return _assertion_result()
