class_name AuthGetIdTokenAction
extends CPPAuthDebugAction

# Uses C++ FirebaseAuth async API with signal-based completion (task-414)
# Requires user to be signed in first
# Uses get_id_token_async(request_id, force_refresh) -> emits id_token_result signal

var _token_result: Dictionary = {}
var _token_received: bool = false


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.auth.get_id_token"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Starting get ID token test...")
	var start_time: int = Time.get_ticks_msec()

	# Get C++ FirebaseAuth instance
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
		auth.sign_in_anonymously()

		# Wait for sign-in completion (max 15 seconds)
		# task-429: FirebaseService._process() now handles CFRunLoop pumping globally
		var max_wait: float = 15.0
		var waited: float = 0.0
		var check_interval: float = 0.1  # Slightly longer check interval

		while waited < max_wait:
			if auth.is_logged_in():
				Log.info(
					"auth_get_id_token: sign-in completed",
					{"waited_seconds": waited},
					["debug", "cpp_auth", "task-429"]
				)
				break
			await Engine.get_main_loop().create_timer(check_interval).timeout
			waited += check_interval

		if not auth.is_logged_in():
			return DebugActionResult.new_failure(
				"Failed to sign in for ID token test (timed out)",
				"SIGN_IN_REQUIRED",
				DebugActionResult.ErrorCategory.FIREBASE,
				null,
				0,
				action_name,
				{"waited_seconds": waited}
			)

	# Check for id_token_result signal
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

	# Connect to signal for result
	_token_received = false
	_token_result = {}
	auth.id_token_result.connect(_on_id_token_result)

	# Request ID token with force refresh
	# Use incremental request ID (sequential, easier to debug)
	var request_id: int = _get_next_request_id()
	Log.info(
		"Requesting ID token",
		{"request_id": request_id, "force_refresh": true},
		["debug", "cpp_auth"]
	)
	auth.get_id_token_async(request_id, true)

	# Wait for signal (max 15 seconds)
	# task-429: FirebaseService._process() now handles CFRunLoop pumping globally
	var max_wait: float = 15.0
	var waited: float = 0.0
	var check_interval: float = 0.1  # Slightly longer check interval

	while waited < max_wait and not _token_received:
		await Engine.get_main_loop().create_timer(check_interval).timeout
		waited += check_interval

	Log.info(
		"auth_get_id_token: token wait loop ended",
		{"token_received": _token_received, "waited_seconds": waited},
		["debug", "cpp_auth", "task-429"]
	)

	# Cleanup
	if auth.id_token_result.is_connected(_on_id_token_result):
		auth.id_token_result.disconnect(_on_id_token_result)

	var duration: int = Time.get_ticks_msec() - start_time

	if _token_received and _token_result.get("success", false):
		var token: String = _token_result.get("token", "")
		var metadata: Dictionary = {
			"token_length": token.length(),
			"token_prefix": token.left(20) + "..." if token.length() > 20 else token,
			"uid": auth.uid() if auth.has_method("uid") else "",
			"waited_seconds": waited,
			"duration_ms": duration,
			"timestamp": Time.get_unix_time_from_system()
		}

		Log.info("✅ ID token retrieved", metadata, ["debug", "cpp_auth", "id_token"])
		return DebugActionResult.new_success(true, 0, action_name, metadata)

	# Failed or timeout
	var error_msg: String = _token_result.get(
		"error_message", "Timeout waiting for id_token_result signal"
	)
	return DebugActionResult.new_failure(
		"Get ID token failed: " + error_msg,
		"GET_TOKEN_FAILED",
		DebugActionResult.ErrorCategory.FIREBASE,
		null,
		duration,
		action_name,
		{"waited_seconds": waited, "received": _token_received, "result": _token_result}
	)


func _on_id_token_result(
	request_id: int, success: bool, token: String, error_message: String
) -> void:
	Log.debug(
		"id_token_result received",
		{
			"request_id": request_id,
			"success": success,
			"token_length": token.length(),
			"error_message": error_message
		},
		["debug", "cpp_auth", "id_token"]
	)

	_token_received = true
	_token_result = {
		"request_id": request_id, "success": success, "token": token, "error_message": error_message
	}
