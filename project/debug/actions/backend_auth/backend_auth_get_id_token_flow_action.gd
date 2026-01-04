class_name BackendAuthGetIdTokenFlowAction
extends BackendAuthDebugAction

## Tests ID token flow: sign_in_anonymously() -> get_id_token() -> validate token.
## Validates backend verification use case through AuthService.


func _init() -> void:
	super._init()
	action_name = "backend.firebase.auth.get_id_token_flow"
	auto_continue = false


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing ID token flow...")
	var start_time: int = Time.get_ticks_msec()

	# Get AuthService
	var auth: AuthService = _get_auth_service()
	if not auth:
		return _fail("AuthService not available", "SERVICE_UNAVAILABLE", start_time)

	# Step 1: Ensure signed in (sign in if needed)
	_update_status("Step 1/3: Ensuring signed in state...")

	var sign_in_error: Dictionary = await _ensure_signed_in(auth, start_time)
	if not sign_in_error.is_empty():
		return DebugActionResult.new_failure(
			sign_in_error.message,
			sign_in_error.code,
			sign_in_error.category,
			null,
			sign_in_error.duration,
			action_name,
			sign_in_error.metadata
		)

	var uid: String = auth.get_uid()
	Log.info("ID token flow: Signed in", {"uid": uid}, ["debug", "backend_auth"])

	# Step 2: Get ID token (no force refresh)
	_update_status("Step 2/3: Getting ID token...")
	Log.info(
		"ID token flow: Requesting ID token", {"force_refresh": false}, ["debug", "backend_auth"]
	)

	@warning_ignore("redundant_await")
	var token_result: Variant = await auth.get_id_token(false)

	var token_error: Dictionary = _validate_token_result(token_result, start_time)
	if not token_error.is_empty():
		return DebugActionResult.new_failure(
			token_error.message,
			token_error.code,
			token_error.category,
			null,
			token_error.duration,
			action_name,
			token_error.metadata
		)

	var token: String = token_result.get("token", "")
	Log.info(
		"ID token flow: Token received", {"token_length": token.length()}, ["debug", "backend_auth"]
	)

	# Step 3: Validate token format (JWT has 3 parts separated by dots)
	_update_status("Step 3/3: Validating token format...")

	var jwt_error: Dictionary = _validate_jwt_format(token, start_time)
	if not jwt_error.is_empty():
		return DebugActionResult.new_failure(
			jwt_error.message,
			jwt_error.code,
			jwt_error.category,
			null,
			jwt_error.duration,
			action_name,
			jwt_error.metadata
		)

	var duration: int = Time.get_ticks_msec() - start_time
	Log.info(
		"ID token flow: Complete flow passed",
		{"duration_ms": duration, "uid": uid, "token_length": token.length()},
		["debug", "backend_auth", "success"]
	)

	return DebugActionResult.new_success(
		true, duration, action_name, {"uid": uid, "token_length": token.length(), "jwt_parts": 3}
	)


func _ensure_signed_in(auth: AuthService, start_time: int) -> Dictionary:
	if not auth.is_signed_in():
		Log.info(
			"ID token flow: Not signed in, signing in anonymously", {}, ["debug", "backend_auth"]
		)

		@warning_ignore("redundant_await")
		var sign_in_result: Variant = await auth.sign_in_anonymously()

		if not _is_success_result(sign_in_result):
			var error_msg: String = _get_error_message(sign_in_result)
			return {
				"message": "Sign in failed: " + error_msg,
				"code": "SIGN_IN_FAILED",
				"category": DebugActionResult.ErrorCategory.FIREBASE,
				"duration": Time.get_ticks_msec() - start_time,
				"metadata": {"step": "sign_in", "error": error_msg}
			}

	return {}


func _validate_token_result(result: Variant, start_time: int) -> Dictionary:
	if not result is Dictionary:
		return {
			"message": "get_id_token() returned invalid type: " + str(typeof(result)),
			"code": "INVALID_RESULT_TYPE",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "get_token", "result_type": typeof(result)}
		}

	var status: String = result.get("status", "")
	if status != "ok":
		var error_code: String = result.get("code", "UNKNOWN")
		var error_msg: String = result.get("message", "Unknown error")
		return {
			"message": "get_id_token() failed: " + error_msg,
			"code": error_code,
			"category": DebugActionResult.ErrorCategory.FIREBASE,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "get_token", "code": error_code, "message": error_msg}
		}

	var token: String = result.get("token", "")
	if token.is_empty():
		return {
			"message": "get_id_token() returned empty token",
			"code": "EMPTY_TOKEN",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "validate_token"}
		}

	return {}


func _validate_jwt_format(token: String, start_time: int) -> Dictionary:
	var token_parts: PackedStringArray = token.split(".")
	if token_parts.size() != 3:
		return {
			"message":
			"Token is not valid JWT format (expected 3 parts, got " + str(token_parts.size()) + ")",
			"code": "INVALID_JWT_FORMAT",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "validate_jwt", "parts": token_parts.size()}
		}

	# Validate each part is non-empty base64
	for i in range(token_parts.size()):
		if token_parts[i].is_empty():
			return {
				"message": "JWT part " + str(i) + " is empty",
				"code": "INVALID_JWT_PART",
				"category": DebugActionResult.ErrorCategory.VALIDATION,
				"duration": Time.get_ticks_msec() - start_time,
				"metadata": {"step": "validate_jwt_parts", "empty_part": i}
			}

	return {}


func _fail(message: String, code: String, start_time: int) -> DebugActionResult:
	return DebugActionResult.new_failure(
		message,
		code,
		DebugActionResult.ErrorCategory.FIREBASE,
		null,
		Time.get_ticks_msec() - start_time,
		action_name,
		{}
	)


func _is_success_result(result: Variant) -> bool:
	if result is Dictionary:
		var status: String = result.get("status", "")
		return status == "ok"
	return false


func _get_error_message(result: Variant) -> String:
	if result is Dictionary:
		return result.get("message", result.get("code", "Unknown error"))
	return "Invalid result type"
