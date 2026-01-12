## Test Steam to Firebase sign-in flow
class_name TestSteamSignInFlow extends FirebaseTestActionBase

## Preload SteamAuthService script (task-404)
const SteamAuthServiceScript: GDScript = preload("res://firebase/steam_auth_service.gd")


func _init() -> void:
	super("test.steam.sign_in_flow", _execute_test)
	set_category("Firebase SDK")
	set_group("Steam")
	set_description("Test Steam to Firebase sign-in flow (desktop only)")
	set_use_auto_success_logging(false)


func should_run_on_platform() -> bool:
	return _is_desktop()


func _execute_test() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	if not should_run_on_platform():
		return _skip_result("Steam is desktop-only (not available on mobile)")

	# Create SteamAuthService instance
	var steam_service: RefCounted = SteamAuthServiceScript.new()

	if steam_service == null:
		_fail("SteamAuthService should be instantiable")
		return _assertion_result()

	# Initialize service (expected: NO_STEAM_CLIENT = 2)
	var init_result: int = steam_service.initialize("")
	if init_result != 2:
		_fail("Steam init should return NO_STEAM_CLIENT (2), got: %d" % init_result)
		return _assertion_result()

	# Test complete sign-in flow (should fail gracefully at each step)
	var auth_result: Dictionary = steam_service.authenticate_with_steam()

	# Verify failure result
	if auth_result.get("success", true):
		_fail("authenticate_with_steam should fail without GDExtension")
		return _assertion_result()

	var error_msg: String = auth_result.get("error", "")
	if error_msg.is_empty():
		_fail("Result should contain error message")
		return _assertion_result()

	# Verify appropriate error handling
	if not (error_msg.contains("Steam") or error_msg.contains("GDExtension")):
		_fail("Error message should mention Steam or GDExtension, got: %s" % error_msg)
		return _assertion_result()

	# Test sign_in_with_custom_token with empty token (should fail)
	var custom_token_result: Dictionary = steam_service.sign_in_with_custom_token("")

	if custom_token_result.get("success", true):
		_fail("sign_in_with_custom_token should fail with empty token")
		return _assertion_result()

	# All checks passed
	_pass()
	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(
		action_name,
		"Firebase SDK",
		"Steam",
		duration,
		{
			"error_message": error_msg,
			"custom_token_failed": not custom_token_result.get("success", true)
		}
	)
	return _assertion_result()
