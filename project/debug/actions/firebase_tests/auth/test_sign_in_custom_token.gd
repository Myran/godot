## Test Auth sign-in with custom token (required for Steam)
class_name TestSignInCustomToken extends FirebaseTestActionBase

func _init() -> void:
	super("test.auth.sign_in_custom_token", _execute_test)
	set_category("Firebase SDK")
	set_group("Auth")
	set_description("Test Auth sign-in with custom token (required for Steam)")
	set_use_auto_success_logging(false)


func _execute_test() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	if not should_run_on_platform():
		return _skip_result("Platform not supported")

	# TDD Red Phase: This test will fail until implementation is complete
	assert_true(false, "FirebaseAuth.sign_in_with_custom_token not yet implemented - see task-399")

	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(action_name, "Firebase SDK", "Auth", duration, {})
	return _assertion_result()
