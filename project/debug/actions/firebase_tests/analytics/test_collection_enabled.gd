## Test Analytics collection toggle (enable/disable)
class_name TestCollectionEnabled extends FirebaseTestActionBase

func _init() -> void:
	super("test.analytics.collection_enabled", _execute_test)
	set_category("Firebase SDK")
	set_group("Analytics")
	set_description("Test Analytics collection toggle (enable/disable)")
	set_use_auto_success_logging(false)


func _execute_test() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	if not should_run_on_platform():
		return _skip_result("Platform not supported")

	# TDD Red Phase: This test will fail until implementation is complete
	assert_true(false, "FirebaseAnalytics.set_analytics_collection_enabled not yet implemented - see task-402")

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(action_name, "Firebase SDK", "Analytics", duration, {})
	return _assertion_result()
