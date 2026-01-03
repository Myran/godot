class_name AuthSignInAnonymousAction
extends CPPAuthDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.auth.sign_in_anonymous"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Starting anonymous sign in test...")
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

	# Check if already signed in
	if auth.is_logged_in():
		Log.info("Already signed in, signing out first", {"uid": auth.uid()}, ["debug", "cpp_auth"])
		auth.sign_out()

	# Connect to completion signal
	if not auth.has_signal("sign_in_completed"):
		return DebugActionResult.new_failure(
			"FirebaseAuth missing sign_in_completed signal",
			"SIGNAL_NOT_FOUND",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	var request_id: int = Time.get_ticks_msec()

	# Call the async method
	auth.sign_in_anonymously_async(request_id)

	# Wait for completion
	var signal_result: Array = await auth.sign_in_completed
	var duration: int = Time.get_ticks_msec() - start_time

	# Parse result: [request_id, success, uid, error_message] (4 params from C++)
	var recv_request_id: int = int(signal_result[0])
	var success: bool = bool(signal_result[1])
	var uid: String = str(signal_result[2])
	var error_message: String = str(signal_result[3])

	if recv_request_id != request_id:
		return DebugActionResult.new_failure(
			"Request ID mismatch: expected " + str(request_id) + " got " + str(recv_request_id),
			"REQUEST_ID_MISMATCH",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			duration,
			action_name,
			{}
		)

	if not success:
		return DebugActionResult.new_failure(
			"Anonymous sign in failed: " + error_message,
			"SIGN_IN_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			duration,
			action_name,
			{}
		)

	var metadata: Dictionary = {
		"uid": uid,
		"is_logged_in": auth.is_logged_in(),
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info("✅ Anonymous sign in completed", metadata, ["debug", "cpp_auth", "sign_in"])

	return DebugActionResult.new_success(true, 0, action_name, metadata)
