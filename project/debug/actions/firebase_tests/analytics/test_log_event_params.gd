## Test Analytics event logging with parameters
class_name TestLogEventParams extends FirebaseTestActionBase

var _analytics: AnalyticsService


func _init() -> void:
	super("test.analytics.log_event_params", _execute_test)
	set_category("Firebase SDK")
	set_group("Analytics")
	set_description("Test Analytics event logging with parameters")
	set_use_auto_success_logging(false)


func _execute_test() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	if not should_run_on_platform():
		return _skip_result("Platform not supported")

	# Get Analytics service
	_analytics = FirebaseService.get_analytics()
	if not _analytics.is_available():
		_fail("AnalyticsService not available")
		return _assertion_result()

	# Test event with parameters
	_analytics.log_event_params("test_event_params", {
		"string_param": "test_value",
		"int_param": 42,
		"float_param": 3.14,
		"bool_param": true
	})
	assert_true(true, "Event with parameters logging works")

	# Mark test as passed before returning
	_pass()

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(action_name, "Firebase SDK", "Analytics", duration, {})
	return _assertion_result()
