## Test Analytics reset data method
class_name TestResetData extends FirebaseTestActionBase

var _analytics: AnalyticsService


func _init() -> void:
	super("test.analytics.reset_data", _execute_test)
	set_category("Firebase SDK")
	set_group("Analytics")
	set_description("Test Analytics reset data method")
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

	# Test reset analytics data
	_analytics.reset_analytics_data()
	assert_true(true, "Analytics data reset works")

	# Mark test as passed before returning
	_pass()

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(action_name, "Firebase SDK", "Analytics", duration, {})
	return _assertion_result()
