class_name BackendAuthSignInAnonymousAction
extends BackendAuthDebugAction

## Tests AuthService.sign_in_anonymously() - the production auth path.
## Validates that the complete flow works: service call → async result.


func _init() -> void:
	super._init()
	action_name = "backend.firebase.auth.sign_in_anonymous"
	auto_continue = false  # Sequential execution required for async operations


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Testing AuthService anonymous sign in...")
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

	Log.info("Calling AuthService.sign_in_anonymously()...", {}, ["debug", "backend_auth"])

	# Call the service method (async - AuthService handles NSRunLoop internally)
	@warning_ignore("redundant_await")
	var result: Variant = await auth.sign_in_anonymously()

	var duration: int = Time.get_ticks_msec() - start_time

	# Validate result
	if result is Dictionary:
		var status: String = result.get("status", "")
		var uid: String = result.get("uid", "")

		if status == "ok":
			var metadata: Dictionary = {"uid": uid, "duration_ms": duration}

			Log.info(
				"AuthService anonymous sign in completed",
				metadata,
				["debug", "backend_auth", "sign_in"]
			)

			return DebugActionResult.new_success(true, duration, action_name, metadata)

		# Error case - status != "ok"
		var error_code: String = result.get("code", "")
		var error_message: String = result.get("message", "Unknown error")

		Log.error(
			"AuthService anonymous sign in failed",
			{"code": error_code, "message": error_message},
			["debug", "backend_auth", "error"]
		)

		return DebugActionResult.new_failure(
			"AuthService anonymous sign in failed: " + error_message,
			error_code,
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			duration,
			action_name,
			{"code": error_code, "message": error_message}
		)

	return DebugActionResult.new_failure(
		"AuthService returned unexpected result type: " + str(typeof(result)),
		"UNEXPECTED_RESULT",
		DebugActionResult.ErrorCategory.FIREBASE,
		null,
		duration,
		action_name,
		{"result_type": typeof(result)}
	)
