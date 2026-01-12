## Test Steam initialization
class_name TestSteamInit extends FirebaseTestActionBase

## Preload SteamAuthService script (task-404) - instantiate via preload since class_name not available at runtime
const SteamAuthServiceScript: GDScript = preload("res://firebase/steam_auth_service.gd")


func _init() -> void:
	super("test.steam.init", _execute_test)
	set_category("Firebase SDK")
	set_group("Steam")
	set_description("Test Steam initialization (desktop only)")
	set_use_auto_success_logging(false)


func should_run_on_platform() -> bool:
	return _is_desktop()


func _execute_test() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	if not should_run_on_platform():
		return _skip_result("Steam is desktop-only (not available on mobile)")

	# Create SteamAuthService instance
	var steam_service: RefCounted = SteamAuthServiceScript.new()

	# Basic instantiation check
	if steam_service == null:
		_fail("SteamAuthService should be instantiable")
		return _assertion_result()

	# Test initialization without backend URL (returns NO_STEAM_CLIENT = 2 since GDExtension not available)
	var init_result: int = steam_service.initialize("")
	if init_result != 2:
		_fail(
			(
				"Steam init should return NO_STEAM_CLIENT (2) when GDExtension not available, got: %d"
				% init_result
			)
		)
		return _assertion_result()

	# Test that is_available returns false
	var is_available: bool = steam_service.is_available()
	if is_available:
		_fail("Steam should not be available without GDExtension")
		return _assertion_result()

	# Test that is_steam_running returns false
	var is_running: bool = steam_service.is_steam_running()
	if is_running:
		_fail("Steam should report not running without GDExtension")
		return _assertion_result()

	# Test that get_steam_id returns empty string
	var steam_id: String = steam_service.get_steam_id()
	if not steam_id.is_empty():
		_fail("Steam ID should be empty without GDExtension")
		return _assertion_result()

	# Test that get_persona_name returns empty string
	var persona_name: String = steam_service.get_persona_name()
	if not persona_name.is_empty():
		_fail("Persona name should be empty without GDExtension")
		return _assertion_result()

	# All checks passed
	_pass()
	var duration: int = Time.get_ticks_msec() - start_time
	_log_test_success(
		action_name,
		"Firebase SDK",
		"Steam",
		duration,
		{"init_result": init_result, "steam_available": is_available, "steam_running": is_running}
	)
	return _assertion_result()
