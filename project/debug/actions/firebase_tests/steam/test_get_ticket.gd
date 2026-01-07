## Test Steam auth ticket retrieval
class_name TestSteamGetTicket extends FirebaseTestActionBase

## Preload SteamAuthService script (task-404)
const SteamAuthServiceScript: GDScript = preload("res://firebase/steam_auth_service.gd")


func _init() -> void:
	super("test.steam.get_ticket", _execute_test)
	set_category("Firebase SDK")
	set_group("Steam")
	set_description("Test Steam auth ticket retrieval (desktop only)")
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

	# Test get_auth_session_ticket returns empty array when Steam not available
	var ticket: PackedByteArray = steam_service.get_auth_session_ticket()
	if not ticket.is_empty():
		_fail("Auth ticket should be empty without GDExtension")
		return _assertion_result()

	# Test authenticate_with_steam fails gracefully
	var auth_result: Dictionary = steam_service.authenticate_with_steam()

	if auth_result.get("success", true):
		_fail("authenticate_with_steam should fail without GDExtension")
		return _assertion_result()

	var error_msg: String = auth_result.get("error", "")
	if error_msg.is_empty():
		_fail("Auth result should contain error message")
		return _assertion_result()

	# Verify error message mentions Steam or GDExtension
	if not (error_msg.contains("Steam") or error_msg.contains("GDExtension")):
		_fail("Error message should mention Steam or GDExtension, got: %s" % error_msg)
		return _assertion_result()

	# All checks passed
	_pass()
	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(
		action_name,
		"Firebase SDK",
		"Steam",
		duration,
		{"ticket_empty": true, "error_message": error_msg}
	)
	return _assertion_result()
