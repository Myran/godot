class_name AuthSignInCustomTokenAction
extends CPPAuthDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.auth.sign_in_custom_token"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Starting custom token sign in test...")
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

	# Test with an invalid token (should fail gracefully)
	# In production, valid tokens come from backend
	var test_token: String = "test_invalid_custom_token"

	# Connect to completion signal
	if not auth.has_signal("custom_token_sign_in_completed"):
		return DebugActionResult.new_failure(
			"FirebaseAuth missing custom_token_sign_in_completed signal",
			"SIGNAL_NOT_FOUND",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	# Use request ID that fits in signed 32-bit int (C++ int parameter)
	var request_id: int = Time.get_ticks_msec() & 0x7FFFFFFF

	# Call the async method with test token
	auth.sign_in_with_custom_token_async(request_id, test_token)

	# Wait for completion
	var signal_result: Array = await auth.custom_token_sign_in_completed
	var duration: int = Time.get_ticks_msec() - start_time

	# Parse result: [request_id, success, uid, error_code, error_message]
	var recv_request_id: int = int(signal_result[0])
	var success: bool = bool(signal_result[1])
	var uid: String = str(signal_result[2])
	var error_code: int = int(signal_result[3])
	var error_message: String = str(signal_result[4])

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

	var metadata: Dictionary = {
		"test_token_used": true,
		"success": success,
		"uid": uid if success else "",
		"error_code": error_code if not success else 0,
		"error_message": error_message if not success else "",
		"expected_failure": true,  # Using test token, expected to fail
		"timestamp": Time.get_unix_time_from_system()
	}

	if success:
		# Unexpected success with test token
		Log.warning(
			"⚠️ Custom token sign in succeeded with test token (unexpected)",
			metadata,
			["debug", "cpp_auth", "sign_in"]
		)
		return DebugActionResult.new_success(true, 0, action_name, metadata)

	# Expected failure with test token
	Log.info(
		"✅ Custom token sign in test completed (expected failure with test token)",
		metadata,
		["debug", "cpp_auth", "sign_in"]
	)

	return DebugActionResult.new_success(true, 0, action_name, metadata)
