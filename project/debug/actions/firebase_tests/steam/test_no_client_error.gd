## Test Steam graceful error when client not available
class_name TestSteamNoClientError extends FirebaseTestActionBase

## Preload SteamAuthService script (task-404)
const SteamAuthServiceScript: GDScript = preload("res://firebase/steam_auth_service.gd")


func _init() -> void:
	super("test.steam.no_client_error", _execute_test)
	set_category("Firebase SDK")
	set_group("Steam")
	set_description("Test Steam graceful error when client not available (desktop only)")
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

	# Test all graceful error paths when Steam is not available

	# 1. Test initialization returns appropriate error code (NO_STEAM_CLIENT = 2)
	var init_result: int = steam_service.initialize("")
	if init_result != 2:
		_fail("Initialize should return NO_STEAM_CLIENT (2), got: %d" % init_result)
		return _assertion_result()

	# 2. Test is_available returns false
	if steam_service.is_available():
		_fail("is_available should return false")
		return _assertion_result()

	# 3. Test is_steam_running returns false
	if steam_service.is_steam_running():
		_fail("is_steam_running should return false")
		return _assertion_result()

	# 4. Test get_steam_id returns empty string
	if not steam_service.get_steam_id().is_empty():
		_fail("get_steam_id should return empty string")
		return _assertion_result()

	# 5. Test get_persona_name returns empty string
	if not steam_service.get_persona_name().is_empty():
		_fail("get_persona_name should return empty string")
		return _assertion_result()

	# 6. Test get_auth_session_ticket returns empty array
	var ticket: PackedByteArray = steam_service.get_auth_session_ticket()
	if not ticket.is_empty():
		_fail("get_auth_session_ticket should return empty array")
		return _assertion_result()

	# 7. Test authenticate_with_steam fails gracefully
	var auth_result: Dictionary = steam_service.authenticate_with_steam()

	if auth_result.get("success", true):
		_fail("authenticate_with_steam should fail")
		return _assertion_result()

	var error_msg: String = auth_result.get("error", "")
	if error_msg.is_empty():
		_fail("Should include error message")
		return _assertion_result()

	# 8. Verify error message is descriptive
	if not (
		error_msg.contains("Steam")
		or error_msg.contains("GDExtension")
		or error_msg.contains("available")
	):
		_fail("Error message should be descriptive, got: %s" % error_msg)
		return _assertion_result()

	# 9. Test shutdown doesn't crash (service should handle gracefully)
	steam_service.shutdown()
	if steam_service.is_available():
		_fail("Should still be unavailable after shutdown")
		return _assertion_result()

	# All checks passed
	_pass()
	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(
		action_name,
		"Firebase SDK",
		"Steam",
		duration,
		{"init_result": init_result, "all_methods_graceful": true, "error_message": error_msg}
	)
	return _assertion_result()
