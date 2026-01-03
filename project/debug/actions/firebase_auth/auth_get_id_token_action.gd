class_name AuthGetIdTokenAction
extends CPPAuthDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.auth.get_id_token"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Starting get ID token test...")
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

	# Need to be signed in to get ID token
	if not auth.is_logged_in():
		# Try anonymous sign in first
		Log.info("Not signed in, attempting anonymous sign in first", {}, ["debug", "cpp_auth"])

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

		var sign_in_request_id: int = Time.get_ticks_msec()
		auth.sign_in_anonymously_async(sign_in_request_id)
		await auth.sign_in_completed

		if not auth.is_logged_in():
			return DebugActionResult.new_failure(
				"Failed to sign in for ID token test",
				"SIGN_IN_REQUIRED",
				DebugActionResult.ErrorCategory.FIREBASE,
				null,
				0,
				action_name,
				{}
			)

	# Connect to completion signal (C++ signal is named "id_token_result")
	if not auth.has_signal("id_token_result"):
		return DebugActionResult.new_failure(
			"FirebaseAuth missing id_token_result signal",
			"SIGNAL_NOT_FOUND",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	var request_id: int = Time.get_ticks_msec()
	var force_refresh: bool = false  # Test without force refresh first

	# Call the async method
	auth.get_id_token_async(request_id, force_refresh)

	# Wait for completion (C++ signal is named "id_token_result")
	var signal_result: Array = await auth.id_token_result
	var duration: int = Time.get_ticks_msec() - start_time

	# Parse result: [request_id, success, token, error_message]
	var recv_request_id: int = int(signal_result[0])
	var success: bool = bool(signal_result[1])
	var token: String = str(signal_result[2])
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
			"Get ID token failed: " + error_message,
			"GET_TOKEN_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			duration,
			action_name,
			{}
		)

	var metadata: Dictionary = {
		"token_length": token.length(),
		"token_prefix": token.left(20) + "..." if token.length() > 20 else token,
		"force_refresh": force_refresh,
		"uid": auth.uid(),
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info("✅ ID token retrieved successfully", metadata, ["debug", "cpp_auth", "id_token"])

	return DebugActionResult.new_success(true, 0, action_name, metadata)
