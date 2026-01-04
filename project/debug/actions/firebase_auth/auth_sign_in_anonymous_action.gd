class_name AuthSignInAnonymousAction
extends CPPAuthDebugAction

# Uses C++ FirebaseAuth directly with NSRunLoop pumping (task-414)
# Uses modern sign_in_anonymously_async() with signal-based completion
# This uses MessageQueue for proper thread marshaling on iOS/macOS
# Uses SignalAwaiter for proper timeout handling


# Signal emitter for Firebase completion (must be a class to define signal)
class SignInEmitter:
	extends Node
	signal completed(success: bool, uid: String, error: String)

	var parent_action: AuthSignInAnonymousAction

	func _init(p_parent: AuthSignInAnonymousAction) -> void:
		parent_action = p_parent

	func handle_firebase_callback(
		request_id: int, success: bool, uid: String, error_message: String
	) -> void:
		# Only handle our specific request
		if request_id != parent_action._expected_request_id:
			Log.warning(
				(
					"Received sign_in_completed for different request_id (expected=%d, got=%d)"
					% [parent_action._expected_request_id, request_id]
				),
				{},
				["debug", "cpp_auth"]
			)
			return

		# Set completion state on parent action
		parent_action._sign_in_completed = true
		parent_action._sign_in_success = success
		parent_action._sign_in_uid = uid
		parent_action._sign_in_error = error_message

		Log.info(
			(
				"Received sign_in_completed signal (request_id=%d, success=%s, uid='%s')"
				% [parent_action._expected_request_id, success, uid]
			),
			{},
			["debug", "cpp_auth"]
		)

		# Emit from our tree-attached emitter (triggers SignalAwaiter)
		completed.emit(success, uid, error_message)


# Signal completion tracking
var _sign_in_completed: bool = false
var _sign_in_success: bool = false
var _sign_in_uid: String = ""
var _sign_in_error: String = ""
var _expected_request_id: int = -1


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.auth.sign_in_anonymous"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Starting anonymous sign in test...")
	var start_time: int = Time.get_ticks_msec()

	# Reset completion tracking
	_sign_in_completed = false
	_sign_in_success = false
	_sign_in_uid = ""
	_sign_in_error = ""
	# Use random ID that fits in signed 32-bit int (C++ int parameter)
	# randi() returns 64-bit, but C++ int is 32-bit - mask to positive 31-bit value
	_expected_request_id = randi() & 0x7FFFFFFF

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

	# Check if modern async method is available
	if not auth.has_method("sign_in_anonymously_async"):
		return DebugActionResult.new_failure(
			"FirebaseAuth C++ missing sign_in_anonymously_async method - need updated module",
			"AUTH_METHOD_MISSING",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	# Sign out first to ensure clean state
	if auth.is_logged_in():
		Log.info(
			"Already signed in, signing out first",
			{"uid": auth.uid() if auth.has_method("uid") else ""},
			["debug", "cpp_auth"]
		)
		auth.sign_out()
		# Give it a moment to process
		for i in range(10):
			if is_instance_valid(firebase_instance):
				firebase_instance.process_notifications()

	# Start NSRunLoop pumping for iOS/macOS
	_start_nsloop_pumping()

	# Create signal emitter node and attach to scene tree (critical for iOS/macOS)
	var signal_emitter: SignInEmitter = SignInEmitter.new(self)
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_tree: SceneTree = main_loop as SceneTree
		scene_tree.root.add_child(signal_emitter)

	# Connect to the sign_in_completed signal - use handler method on emitter
	auth.sign_in_completed.connect(signal_emitter.handle_firebase_callback)

	Log.info(
		"Starting C++ anonymous sign in (signal-based, request_id=%d)" % _expected_request_id,
		{},
		["debug", "cpp_auth"]
	)

	# Call C++ sign_in_anonymously_async - this uses MessageQueue for thread marshaling
	auth.sign_in_anonymously_async(_expected_request_id)

	# Create NSRunLoop pump timer - calls process_notifications() repeatedly on iOS/macOS
	var pump_timer: Timer = Timer.new()
	pump_timer.wait_time = 0.016  # ~60 FPS
	pump_timer.one_shot = false  # Repeating
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

	# Use SignalAwaiter for timeout (attached to tree, works on iOS/macOS)
	Log.info("Creating SignalAwaiter...", {}, ["debug", "cpp_auth"])
	var awaiter: SignalAwaiter.Any = SignalAwaiter.Any.new()
	var timeout_awaiter: SignalAwaiter.Timeout = SignalAwaiter.Timeout.new(30.0)
	awaiter.add(signal_emitter.completed)
	awaiter.add(timeout_awaiter.finished)
	Log.info(
		"SignalAwaiter created, connecting completion handler...",
		{"awaiter_valid": is_instance_valid(awaiter)},
		["debug", "cpp_auth"]
	)

	# Completion handler - sets result when Firebase callback fires
	var completion_handler: Callable = func(success: bool, uid: String, error: String) -> void:
		_sign_in_completed = true
		_sign_in_success = success
		_sign_in_uid = uid
		_sign_in_error = error
		Log.info(
			(
				"Received sign_in_completed signal (request_id=%d, success=%s, uid='%s')"
				% [_expected_request_id, success, uid]
			),
			{},
			["debug", "cpp_auth"]
		)

	signal_emitter.completed.connect(completion_handler, CONNECT_ONE_SHOT)

	# Wait for either Firebase completion OR timeout
	# SignalAwaiter attaches to tree and processes properly on iOS/macOS
	# Pump timer runs in background to process Firebase callbacks
	Log.info("About to await SignalAwaiter.finished...", {}, ["debug", "cpp_auth"])
	var await_start: int = Time.get_ticks_msec()
	await awaiter.finished
	var await_duration: int = Time.get_ticks_msec() - await_start
	Log.info(
		"SignalAwaiter.finished returned",
		{"await_duration_ms": await_duration, "sign_in_completed": _sign_in_completed},
		["debug", "cpp_auth"]
	)

	var waited: float = float(Time.get_ticks_msec() - start_time) / 1000.0

	# Cleanup pump timer
	if is_instance_valid(pump_timer):
		pump_timer.queue_free()

	# Cleanup emitter and disconnect signal
	if signal_emitter and is_instance_valid(signal_emitter):
		if auth.sign_in_completed.is_connected(signal_emitter.handle_firebase_callback):
			auth.sign_in_completed.disconnect(signal_emitter.handle_firebase_callback)
		signal_emitter.queue_free()

	# Stop NSRunLoop pumping
	_stop_nsloop_pumping()

	var duration: int = Time.get_ticks_msec() - start_time

	# Check result
	if _sign_in_completed:
		if _sign_in_success:
			var metadata: Dictionary = {
				"uid": _sign_in_uid,
				"is_logged_in": true,
				"waited_seconds": waited,
				"duration_ms": duration,
				"timestamp": Time.get_unix_time_from_system()
			}

			Log.info(
				"✅ Anonymous sign in completed (signal-based)",
				metadata,
				["debug", "cpp_auth", "sign_in"]
			)

			return DebugActionResult.new_success(true, 0, action_name, metadata)

		return DebugActionResult.new_failure(
			"Anonymous sign in failed: " + _sign_in_error,
			"SIGN_IN_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			duration,
			action_name,
			{"waited_seconds": waited, "error": _sign_in_error}
		)

	# Timeout - signal never fired
	var is_logged_in: bool = auth.is_logged_in()
	var uid: String = auth.uid() if auth.has_method("uid") else ""

	return DebugActionResult.new_failure(
		(
			"Anonymous sign in timed out after "
			+ str(30.0)
			+ " seconds without signal (logged_in="
			+ str(is_logged_in)
			+ ", uid='"
			+ uid
			+ "')"
		),
		"SIGN_IN_TIMEOUT",
		DebugActionResult.ErrorCategory.FIREBASE,
		null,
		duration,
		action_name,
		{"waited_seconds": waited, "is_logged_in": is_logged_in, "uid": uid}
	)
