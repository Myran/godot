class_name BackendAuthStateTransitionsAction
extends BackendAuthDebugAction

## Tests auth state transitions: signed out -> signed in -> signed out.
## Validates that is_signed_in() correctly tracks auth state changes.


func _init() -> void:
	super._init()
	action_name = "backend.firebase.auth.state_transitions"
	auto_continue = false


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing auth state transitions...")
	var start_time: int = Time.get_ticks_msec()

	# Get AuthService
	var auth: AuthService = _get_auth_service()
	if not auth:
		return DebugActionResult.new_failure(
			"AuthService not available",
			"SERVICE_UNAVAILABLE",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	var state_transitions: Array[Dictionary] = []

	# Initial state check
	_update_status("Checking initial state...")
	var initial_result: Dictionary = await _check_initial_state(auth, start_time)
	if not initial_result.error.is_empty():
		return DebugActionResult.new_failure(
			initial_result.error.message,
			initial_result.error.code,
			initial_result.error.category,
			null,
			initial_result.error.duration,
			action_name,
			initial_result.error.metadata
		)

	state_transitions.append(initial_result.transition)
	Log.info("State transitions: Clean state confirmed", {}, ["debug", "backend_auth"])

	# Transition 1: signed out -> signed in
	_update_status("Transition 1/2: Signing in...")
	var sign_in_result: Dictionary = await _transition_sign_in(auth, start_time)
	if not sign_in_result.error.is_empty():
		return DebugActionResult.new_failure(
			sign_in_result.error.message,
			sign_in_result.error.code,
			sign_in_result.error.category,
			null,
			sign_in_result.error.duration,
			action_name,
			sign_in_result.error.metadata
		)

	state_transitions.append(sign_in_result.transition)
	var after_sign_in_uid: String = sign_in_result.uid

	Log.info(
		"State transitions: Signed in state confirmed",
		{"uid": after_sign_in_uid},
		["debug", "backend_auth"]
	)

	# Transition 2: signed in -> signed out
	_update_status("Transition 2/2: Signing out...")
	var sign_out_result: Dictionary = await _transition_sign_out(auth, start_time)
	if not sign_out_result.error.is_empty():
		return DebugActionResult.new_failure(
			sign_out_result.error.message,
			sign_out_result.error.code,
			sign_out_result.error.category,
			null,
			sign_out_result.error.duration,
			action_name,
			sign_out_result.error.metadata
		)

	state_transitions.append(sign_out_result.transition)
	Log.info("State transitions: Signed out state confirmed", {}, ["debug", "backend_auth"])

	# Verify all transitions passed
	var all_passed: bool = true
	for transition: Dictionary in state_transitions:
		if not transition.get("passed", false):
			all_passed = false

	var duration: int = Time.get_ticks_msec() - start_time
	var metadata: Dictionary = {
		"transitions": state_transitions.size(),
		"all_passed": all_passed,
		"uid": after_sign_in_uid,
		"duration_ms": duration
	}

	if all_passed:
		Log.info(
			"State transitions: All state transitions passed",
			metadata,
			["debug", "backend_auth", "success"]
		)
		return DebugActionResult.new_success(true, duration, action_name, metadata)

	Log.error(
		"State transitions: Some transitions failed", metadata, ["debug", "backend_auth", "error"]
	)
	return DebugActionResult.new_failure(
		"State transition validation failed",
		"STATE_TRANSITION_FAILED",
		DebugActionResult.ErrorCategory.VALIDATION,
		null,
		duration,
		action_name,
		metadata
	)


func _check_initial_state(auth: AuthService, start_time: int) -> Dictionary:
	var initial_signed_in: bool = auth.is_signed_in()
	var initial_uid: String = auth.get_uid()

	if initial_signed_in:
		# Need to sign out first for clean test
		Log.info("State transitions: Signing out to start clean", {}, ["debug", "backend_auth"])
		@warning_ignore("redundant_await")
		await auth.sign_out()

		initial_signed_in = auth.is_signed_in()
		initial_uid = auth.get_uid()

	var transition: Dictionary = {
		"state": "initial",
		"is_signed_in": initial_signed_in,
		"uid": initial_uid,
		"expected_signed_in": false,
		"passed": not initial_signed_in and initial_uid.is_empty()
	}

	if initial_signed_in or not initial_uid.is_empty():
		return {
			"transition": transition,
			"error":
			{
				"message": "Cannot start with clean signed out state",
				"code": "DIRTY_STATE",
				"category": DebugActionResult.ErrorCategory.VALIDATION,
				"duration": Time.get_ticks_msec() - start_time,
				"metadata": {"initial_signed_in": initial_signed_in, "initial_uid": initial_uid}
			}
		}

	return {"transition": transition, "error": {}}


func _transition_sign_in(auth: AuthService, start_time: int) -> Dictionary:
	@warning_ignore("redundant_await")
	var sign_in_result: Variant = await auth.sign_in_anonymously()

	if not _is_success_result(sign_in_result):
		var error_msg: String = _get_error_message(sign_in_result)
		return {
			"uid": "",
			"transition": {},
			"error":
			{
				"message": "Sign in failed: " + error_msg,
				"code": "SIGN_IN_FAILED",
				"category": DebugActionResult.ErrorCategory.FIREBASE,
				"duration": Time.get_ticks_msec() - start_time,
				"metadata": {"transition": "signed_out_to_signed_in", "error": error_msg}
			}
		}

	var after_sign_in_signed_in: bool = auth.is_signed_in()
	var after_sign_in_uid: String = auth.get_uid()

	var transition: Dictionary = {
		"state": "after_sign_in",
		"is_signed_in": after_sign_in_signed_in,
		"uid": after_sign_in_uid,
		"expected_signed_in": true,
		"passed": after_sign_in_signed_in and not after_sign_in_uid.is_empty()
	}

	if not after_sign_in_signed_in:
		return {
			"uid": after_sign_in_uid,
			"transition": transition,
			"error":
			{
				"message": "is_signed_in() false after successful sign in",
				"code": "STATE_MISMATCH",
				"category": DebugActionResult.ErrorCategory.VALIDATION,
				"duration": Time.get_ticks_msec() - start_time,
				"metadata":
				{"transition": "signed_out_to_signed_in", "expected": true, "actual": false}
			}
		}

	if after_sign_in_uid.is_empty():
		return {
			"uid": after_sign_in_uid,
			"transition": transition,
			"error":
			{
				"message": "UID empty after successful sign in",
				"code": "UID_MISMATCH",
				"category": DebugActionResult.ErrorCategory.VALIDATION,
				"duration": Time.get_ticks_msec() - start_time,
				"metadata": {"transition": "signed_out_to_signed_in", "uid": after_sign_in_uid}
			}
		}

	return {"uid": after_sign_in_uid, "transition": transition, "error": {}}


func _transition_sign_out(auth: AuthService, start_time: int) -> Dictionary:
	@warning_ignore("redundant_await")
	var sign_out_result: Variant = await auth.sign_out()

	if sign_out_result is Dictionary and sign_out_result.get("status", "") != "ok":
		var error_msg: String = sign_out_result.get("message", "Unknown error")
		return {
			"transition": {},
			"error":
			{
				"message": "Sign out failed: " + error_msg,
				"code": "SIGN_OUT_FAILED",
				"category": DebugActionResult.ErrorCategory.FIREBASE,
				"duration": Time.get_ticks_msec() - start_time,
				"metadata": {"transition": "signed_in_to_signed_out", "error": error_msg}
			}
		}

	var after_sign_out_signed_in: bool = auth.is_signed_in()
	var after_sign_out_uid: String = auth.get_uid()

	var transition: Dictionary = {
		"state": "after_sign_out",
		"is_signed_in": after_sign_out_signed_in,
		"uid": after_sign_out_uid,
		"expected_signed_in": false,
		"passed": not after_sign_out_signed_in and after_sign_out_uid.is_empty()
	}

	if after_sign_out_signed_in:
		return {
			"transition": transition,
			"error":
			{
				"message": "is_signed_in() true after sign out",
				"code": "STATE_MISMATCH",
				"category": DebugActionResult.ErrorCategory.VALIDATION,
				"duration": Time.get_ticks_msec() - start_time,
				"metadata":
				{"transition": "signed_in_to_signed_out", "expected": false, "actual": true}
			}
		}

	if not after_sign_out_uid.is_empty():
		return {
			"transition": transition,
			"error":
			{
				"message": "UID not empty after sign out",
				"code": "UID_MISMATCH",
				"category": DebugActionResult.ErrorCategory.VALIDATION,
				"duration": Time.get_ticks_msec() - start_time,
				"metadata": {"transition": "signed_in_to_signed_out", "uid": after_sign_out_uid}
			}
		}

	return {"transition": transition, "error": {}}


func _is_success_result(result: Variant) -> bool:
	if result is Dictionary:
		var status: String = result.get("status", "")
		return status == "ok"
	return false


func _get_error_message(result: Variant) -> String:
	if result is Dictionary:
		return result.get("message", result.get("code", "Unknown error"))
	return "Invalid result type"
