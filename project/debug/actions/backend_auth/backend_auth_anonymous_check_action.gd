class_name BackendAuthAnonymousCheckAction
extends BackendAuthDebugAction

## Tests anonymous user detection: sign_in_anonymously() -> verify is_anonymous().
## Validates that anonymous users are correctly identified through AuthService.


func _init() -> void:
	super._init()
	action_name = "backend.firebase.auth.anonymous_check"
	auto_continue = false


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing anonymous user detection...")
	var start_time: int = Time.get_ticks_msec()

	# Get AuthService
	var auth: AuthService = _get_auth_service()
	if not auth:
		return _fail("AuthService not available", "SERVICE_UNAVAILABLE", start_time)

	# Step 1: Ensure we start in a clean state (sign out if needed)
	_update_status("Step 1/3: Ensuring clean signed out state...")

	var clean_error: Dictionary = await _ensure_clean_state(auth, start_time)
	if not clean_error.is_empty():
		return DebugActionResult.new_failure(
			clean_error.message,
			clean_error.code,
			clean_error.category,
			null,
			clean_error.duration,
			action_name,
			clean_error.metadata
		)

	Log.info("Anonymous check: Clean state verified", {}, ["debug", "backend_auth"])

	# Step 2: Sign in anonymously
	_update_status("Step 2/3: Signing in anonymously...")
	Log.info("Anonymous check: Starting anonymous sign in", {}, ["debug", "backend_auth"])

	@warning_ignore("redundant_await")
	var sign_in_result: Variant = await auth.sign_in_anonymously()

	var sign_in_error: Dictionary = _validate_sign_in_result(sign_in_result, start_time)
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

	var uid: String = sign_in_result.get("uid", "")
	Log.info("Anonymous check: Sign in completed", {"uid": uid}, ["debug", "backend_auth"])

	# Step 3: Verify anonymous state
	_update_status("Step 3/3: Verifying anonymous user state...")

	var verify_error: Dictionary = await _verify_anonymous_state(auth, start_time)
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

	var providers: Array = auth.get_providers()
	var duration: int = Time.get_ticks_msec() - start_time
	Log.info(
		"Anonymous check: Anonymous user correctly identified",
		{
			"duration_ms": duration,
			"uid": uid,
			"is_anonymous": true,
			"providers_count": providers.size()
		},
		["debug", "backend_auth", "success"]
	)

	return DebugActionResult.new_success(
		true,
		duration,
		action_name,
		{"uid": uid, "is_anonymous": true, "providers_count": providers.size()}
	)


func _ensure_clean_state(auth: AuthService, start_time: int) -> Dictionary:
	if auth.is_signed_in():
		Log.info(
			"Anonymous check: Already signed in, signing out first", {}, ["debug", "backend_auth"]
		)
		@warning_ignore("redundant_await")
		await auth.sign_out()

	if auth.is_signed_in():
		return {
			"message": "Cannot start clean - user still signed in after sign_out",
			"code": "DIRTY_STATE",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "clean_state", "is_signed_in": true}
		}

	if not auth.get_uid().is_empty():
		return {
			"message": "Cannot start clean - UID not empty after sign_out",
			"code": "DIRTY_STATE",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "clean_state", "uid": auth.get_uid()}
		}

	return {}


func _validate_sign_in_result(result: Variant, start_time: int) -> Dictionary:
	if not _is_success_result(result):
		var error_msg: String = _get_error_message(result)
		return {
			"message": "Anonymous sign in failed: " + error_msg,
			"code": "SIGN_IN_FAILED",
			"category": DebugActionResult.ErrorCategory.FIREBASE,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "sign_in", "error": error_msg}
		}
	return {}


func _verify_anonymous_state(auth: AuthService, start_time: int) -> Dictionary:
	if not auth.is_signed_in():
		return {
			"message": "is_signed_in() returned false after successful anonymous sign in",
			"code": "NOT_SIGNED_IN",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "verify_signed_in", "expected": true, "actual": false}
		}

	if not auth.is_anonymous():
		var providers: Array = auth.get_providers()
		return {
			"message": "is_anonymous() returned false for anonymous sign in",
			"code": "NOT_ANONYMOUS",
			"category": DebugActionResult.ErrorCategory.VALIDATION,
			"duration": Time.get_ticks_msec() - start_time,
			"metadata": {"step": "verify_anonymous", "providers": providers}
		}

	# Verify providers array is empty or has empty provider name for anonymous users
	var providers: Array = auth.get_providers()
	if providers.size() > 0:
		var first_provider: Variant = providers[0]
		if first_provider is Dictionary:
			var provider_name: String = first_provider.get("name", "")
			if not provider_name.is_empty():
				return {
					"message": "Anonymous user has non-empty provider name",
					"code": "PROVIDER_MISMATCH",
					"category": DebugActionResult.ErrorCategory.VALIDATION,
					"duration": Time.get_ticks_msec() - start_time,
					"metadata": {"step": "verify_providers", "providers": providers}
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
