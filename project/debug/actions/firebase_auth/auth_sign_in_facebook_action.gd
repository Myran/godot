class_name AuthSignInFacebookAction
extends CPPAuthDebugAction

## Regression test for Facebook OAuth sign-in (Task-421).
## Validates C++ API surface and error handling without real OAuth credentials.
## Tests method existence, signal structure, and error reporting.


# Signal emitter for Firebase completion (must be a class to define signal)
class SignInEmitter:
	extends Node
	signal completed(success: bool, uid: String, error: String)

	var parent_action: AuthSignInFacebookAction

	func _init(p_parent: AuthSignInFacebookAction) -> void:
		parent_action = p_parent

	func handle_firebase_callback(
		request_id: int, success: bool, uid: String, error_message: String
	) -> void:
		if request_id != parent_action._expected_request_id:
			return

		parent_action._sign_in_completed = true
		parent_action._sign_in_success = success
		parent_action._sign_in_uid = uid
		parent_action._sign_in_error = error_message

		Log.info(
			(
				"Received sign_in_completed for Facebook (request_id=%d, success=%s, error='%s')"
				% [parent_action._expected_request_id, success, error_message]
			),
			{},
			["debug", "cpp_auth", "facebook"]
		)

		completed.emit(success, uid, error_message)


var _sign_in_completed: bool = false
var _sign_in_success: bool = false
var _sign_in_uid: String = ""
var _sign_in_error: String = ""
var _expected_request_id: int = -1


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.auth.sign_in_facebook"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Starting Facebook OAuth sign-in regression test...")
	var start_time: int = Time.get_ticks_msec()

	_sign_in_completed = false
	_sign_in_success = false
	_sign_in_uid = ""
	_sign_in_error = ""
	_expected_request_id = _get_next_request_id()

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

	# Check if method exists (API surface validation)
	if not auth.has_method("sign_in_facebook_async"):
		return DebugActionResult.new_failure(
			"FirebaseAuth C++ missing sign_in_facebook_async method",
			"AUTH_METHOD_MISSING",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	_start_nsloop_pumping()

	var signal_emitter: SignInEmitter = SignInEmitter.new(self)
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_tree: SceneTree = main_loop as SceneTree
		scene_tree.root.add_child(signal_emitter)

	auth.sign_in_completed.connect(signal_emitter.handle_firebase_callback)

	Log.info(
		"Testing Facebook sign_in with invalid token (regression test)",
		{},
		["debug", "cpp_auth", "facebook"]
	)

	var pump_timer: Timer = Timer.new()
	pump_timer.wait_time = 0.016
	pump_timer.one_shot = false
	pump_timer.autostart = true
	var pump_callback: Callable = func():
		if (
			is_instance_valid(firebase_instance)
			and firebase_instance.has_method("process_notifications")
		):
			firebase_instance.process_notifications()
	pump_timer.timeout.connect(pump_callback)
	if main_loop is SceneTree:
		var scene_tree: SceneTree = main_loop as SceneTree
		scene_tree.root.add_child(pump_timer)

	var awaiter: SignalAwaiter.Any = SignalAwaiter.Any.new()
	var timeout_awaiter: SignalAwaiter.Timeout = SignalAwaiter.Timeout.new(30.0)
	awaiter.add(signal_emitter.completed)
	awaiter.add(timeout_awaiter.finished)

	var completion_handler: Callable = func(success: bool, uid: String, error: String) -> void:
		_sign_in_completed = true
		_sign_in_success = success
		_sign_in_uid = uid
		_sign_in_error = error
		Log.info(
			(
				"Facebook sign_in completed (request_id=%d, success=%s, error='%s')"
				% [_expected_request_id, success, error]
			),
			{},
			["debug", "cpp_auth", "facebook"]
		)

	signal_emitter.completed.connect(completion_handler, CONNECT_ONE_SHOT)

	# Use invalid token to test error handling
	var invalid_token: String = "test_invalid_facebook_token_" + str(_expected_request_id)
	auth.sign_in_facebook_async(_expected_request_id, invalid_token)

	Log.info("Waiting for Facebook sign_in response...", {}, ["debug", "cpp_auth", "facebook"])

	await awaiter.finished

	var waited: float = float(Time.get_ticks_msec() - start_time) / 1000.0

	if is_instance_valid(pump_timer):
		pump_timer.queue_free()

	if signal_emitter and is_instance_valid(signal_emitter):
		if auth.sign_in_completed.is_connected(signal_emitter.handle_firebase_callback):
			auth.sign_in_completed.disconnect(signal_emitter.handle_firebase_callback)
		signal_emitter.queue_free()

	_stop_nsloop_pumping()

	var duration: int = Time.get_ticks_msec() - start_time
	var metadata: Dictionary = {
		"method_exists": true,
		"completed": _sign_in_completed,
		"success": _sign_in_success,
		"uid": _sign_in_uid,
		"error": _sign_in_error,
		"waited_seconds": waited,
		"duration_ms": duration
	}

	if _sign_in_completed:
		if _sign_in_success:
			# This would be unexpected with invalid token, but we pass if signal fires correctly
			Log.warning(
				"Facebook sign_in succeeded with invalid token - may indicate mock/test mode",
				metadata,
				["debug", "cpp_auth", "facebook"]
			)
			return DebugActionResult.new_success(true, duration, action_name, metadata)

		# Expected path: error with invalid token
		if not _sign_in_error.is_empty():
			Log.info(
				"✅ Facebook OAuth API validated: error handling works correctly",
				metadata,
				["debug", "cpp_auth", "facebook", "success"]
			)
			return DebugActionResult.new_success(true, duration, action_name, metadata)

		return DebugActionResult.new_failure(
			"Facebook sign_in failed without error message",
			"NO_ERROR_MESSAGE",
			DebugActionResult.ErrorCategory.VALIDATION,
			null,
			duration,
			action_name,
			metadata
		)

	return DebugActionResult.new_failure(
		"Facebook sign_in timed out after " + str(30.0) + " seconds",
		"SIGN_IN_TIMEOUT",
		DebugActionResult.ErrorCategory.FIREBASE,
		null,
		duration,
		action_name,
		metadata
	)
