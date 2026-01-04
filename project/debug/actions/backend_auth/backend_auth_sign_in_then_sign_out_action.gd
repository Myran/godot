class_name BackendAuthSignInThenSignOutAction
extends BackendAuthDebugAction

## Tests full auth cycle: sign_in -> verify -> sign_out -> verify.
## Validates complete auth lifecycle through AuthService.


func _init() -> void:
	super._init()
	action_name = "backend.firebase.auth.sign_in_then_sign_out"
	auto_continue = false


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing full auth cycle...")
	var start_time: int = Time.get_ticks_msec()

	# Get AuthService
	var auth: AuthService = _get_auth_service()
	if not auth:
		return _fail("AuthService not available", "SERVICE_UNAVAILABLE", start_time, {})

	# Step 1: Sign in anonymously
	_update_status("Step 1/4: Signing in anonymously...")
	Log.info("Auth cycle: Starting anonymous sign in", {}, ["debug", "backend_auth"])

	@warning_ignore("redundant_await")
	var sign_in_result: Variant = await auth.sign_in_anonymously()

	var error: Dictionary = _validate_sign_in_result(sign_in_result, auth, start_time)
	if not error.is_empty():
		return DebugActionResult.new_failure(
			error.message,
			error.code,
			error.category,
			null,
			error.duration,
			action_name,
			error.metadata
		)

	var uid: String = sign_in_result.get("uid", "")
	Log.info("Auth cycle: Sign in completed", {"uid": uid}, ["debug", "backend_auth"])

	# Step 2: Verify signed in state
	_update_status("Step 2/4: Verifying signed in state...")
	var verify_error: Dictionary = _verify_signed_in_state(
		auth, uid, start_time, "verify_signed_in"
	)
	if not verify_error.is_empty():
		return DebugActionResult.new_failure(
			verify_error.message,
			verify_error.code,
			verify_error.category,
			null,
			verify_error.duration,
			action_name,
			verify_error.metadata
		)

	Log.info("Auth cycle: Signed in state verified", {"uid": uid}, ["debug", "backend_auth"])

	# Step 3: Sign out
	_update_status("Step 3/4: Signing out...")
	Log.info("Auth cycle: Starting sign out", {}, ["debug", "backend_auth"])

	@warning_ignore("redundant_await")
	var sign_out_result: Variant = await auth.sign_out()

	var sign_out_error: Dictionary = _validate_sign_out_result(sign_out_result, start_time)
	if not sign_out_error.is_empty():
		return DebugActionResult.new_failure(
			sign_out_error.message,
			sign_out_error.code,
			sign_out_error.category,
			null,
			sign_out_error.duration,
			action_name,
			sign_out_error.metadata
		)

	Log.info("Auth cycle: Sign out completed", {}, ["debug", "backend_auth"])

	# Step 4: Verify signed out state
	_update_status("Step 4/4: Verifying signed out state...")
	var final_error: Dictionary = _verify_signed_out_state(auth, start_time)
	if not final_error.is_empty():
		return DebugActionResult.new_failure(
			final_error.message,
			final_error.code,
			final_error.category,
			null,
			final_error.duration,
			action_name,
			final_error.metadata
		)

	var duration: int = Time.get_ticks_msec() - start_time
	Log.info(
		"Auth cycle: Complete auth cycle passed",
		{"duration_ms": duration, "uid": uid},
		["debug", "backend_auth", "success"]
	)

	return DebugActionResult.new_success(
		true,
		duration,
		action_name,
		{"uid": uid, "cycle": "sign_in -> verify -> sign_out -> verify"}
	)


func _validate_sign_in_result(result: Variant, auth: AuthService, start_time: int) -> Dictionary:
	if not _is_success_result(result):
		var error_msg: String = _get_error_message(result)
		return {
			"message": "Sign in failed: " + error_msg,
			"code": "SIGN_IN_FAILED",
			"category": DebugActionResult.ErrorCategory.FIREBASE,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "sign_in", "error": error_msg}
		}

	# Verify signed in state
	if not auth.is_signed_in():
		return {
			"message": "is_signed_in() returned false after successful sign in",
			"code": "STATE_MISMATCH",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "verify_signed_in", "expected": true, "actual": false}
		}

	var uid: String = result.get("uid", "")
	var stored_uid: String = auth.get_uid()
	if stored_uid != uid:
		return {
			"message": "UID mismatch after sign in",
			"code": "UID_MISMATCH",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "verify_uid", "expected": uid, "actual": stored_uid}
		}

	return {}


func _verify_signed_in_state(
	auth: AuthService, uid: String, start_time: int, step: String
) -> Dictionary:
	if not auth.is_signed_in():
		return {
			"message": "is_signed_in() returned false",
			"code": "STATE_MISMATCH",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": step}
		}

	if auth.get_uid() != uid:
		return {
			"message": "UID mismatch in verify step",
			"code": "UID_MISMATCH",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": step}
		}

	return {}


func _validate_sign_out_result(result: Variant, start_time: int) -> Dictionary:
	if result is Dictionary:
		var status: String = result.get("status", "")
		if status == "ok":
			return {}

		var error_msg: String = result.get("message", "Unknown error")
		return {
			"message": "Sign out failed: " + error_msg,
			"code": "SIGN_OUT_FAILED",
			"category": DebugActionResult.ErrorCategory.FIREBASE,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "sign_out", "error": error_msg}
		}

	return {
		"message": "Sign out returned invalid type",
		"code": "INVALID_RESULT",
		"category": DebugActionResult.ErrorCategory.VALIDATION,
		"duration": Time.get_ticks_msec() - start_time,
		"metadata": {"step": "sign_out"}
	}


func _verify_signed_out_state(auth: AuthService, start_time: int) -> Dictionary:
	if auth.is_signed_in():
		return {
			"message": "is_signed_in() true after sign out",
			"code": "STATE_MISMATCH",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "verify_signed_out", "expected": false, "actual": true}
		}

	var uid: String = auth.get_uid()
	if not uid.is_empty():
		return {
			"message": "UID not cleared after sign out",
			"code": "UID_NOT_CLEARED",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "verify_uid_cleared", "uid": uid}
		}

	return {}


func _fail(
	message: String, code: String, start_time: int, metadata: Dictionary
) -> DebugActionResult:
	return DebugActionResult.new_failure(
		message,
		code,
		DebugActionResult.ErrorCategory.FIREBASE,
		null,
		Time.get_ticks_msec() - start_time,
		action_name,
		metadata
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
