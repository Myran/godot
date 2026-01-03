class_name AuthSignOutAction
extends CPPAuthDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.auth.sign_out"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Starting sign out test...")
	var start_time: int = Time.get_ticks_msec()

	var auth: Object = get_cpp_firebase_auth()
	if not is_instance_valid(auth):
		return DebugActionResult.new_failure(
			"FirebaseAuth C++ instance not available",
			"AUTH_UNAVAILABLE",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	var was_logged_in: bool = auth.is_logged_in()
	var previous_uid: String = auth.uid() if auth.has_method("uid") else ""

	# Sign out (synchronous operation)
	auth.sign_out()

	var duration: int = Time.get_ticks_msec() - start_time
	var is_logged_out: bool = not auth.is_logged_in()

	var metadata: Dictionary = {
		"was_logged_in": was_logged_in,
		"previous_uid": previous_uid,
		"is_logged_out": is_logged_out,
		"timestamp": Time.get_unix_time_from_system()
	}

	if is_logged_out:
		Log.info("✅ Sign out completed", metadata, ["debug", "cpp_auth", "sign_out"])
		return DebugActionResult.new_success(true, 0, action_name, metadata)

	return DebugActionResult.new_failure(
		"Sign out failed - still logged in",
		"SIGN_OUT_FAILED",
		DebugActionResult.ErrorCategory.FIREBASE,
		null,
		duration,
		action_name,
		metadata
	)
