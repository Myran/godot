class_name AuthStateListenerAction
extends CPPAuthDebugAction

## Tests C++ AuthStateListener for Firebase Auth state changes (Task-420).
## Validates that auth_state_changed signal fires on sign in and sign out.
## Uses NSRunLoop pumping for iOS/macOS callback execution.


# Signal emitter for auth state changes (must be a class to define signal)
class StateChangeEmitter:
	extends Node
	signal state_changed(is_signed_in: bool, uid: String)

	var parent_action: AuthStateListenerAction

	func _init(p_parent: AuthStateListenerAction) -> void:
		parent_action = p_parent

	func handle_auth_state_changed(is_signed_in: bool, uid: String) -> void:
		Log.info(
			"Received auth_state_changed signal",
			{"is_signed_in": is_signed_in, "uid": uid},
			["debug", "cpp_auth", "state_listener"]
		)

		parent_action._state_changes.append(
			{"is_signed_in": is_signed_in, "uid": uid, "timestamp_ms": Time.get_ticks_msec()}
		)

		# Emit from our tree-attached emitter (triggers SignalAwaiter)
		state_changed.emit(is_signed_in, uid)


# State change tracking
var _state_changes: Array[Dictionary] = []


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.auth.state_listener"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Starting AuthStateListener test...")
	var start_time: int = Time.get_ticks_msec()

	# Reset state tracking
	_state_changes = []

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

	# Check if AuthStateListener methods are available
	if not auth.has_method("start_auth_state_listener"):
		return DebugActionResult.new_failure(
			"FirebaseAuth C++ missing start_auth_state_listener method - need updated module",
			"AUTH_METHOD_MISSING",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	# Start NSRunLoop pumping for iOS/macOS
	_start_nsloop_pumping()

	# Create signal emitter node and attach to scene tree
	var signal_emitter: StateChangeEmitter = StateChangeEmitter.new(self)
	var main_loop: MainLoop = Engine.get_main_loop()
	var scene_tree: SceneTree = null
	if main_loop is SceneTree:
		scene_tree = main_loop as SceneTree
		scene_tree.root.add_child(signal_emitter)

	# Sign out first to ensure clean state
	_update_status("Ensuring clean signed-out state...")
	if auth.is_logged_in():
		Log.info(
			"Already signed in, signing out first", {}, ["debug", "cpp_auth", "state_listener"]
		)
		auth.sign_out()
		# Give it a moment to process
		for i in range(10):
			if is_instance_valid(firebase_instance):
				firebase_instance.process_notifications()

	# Connect to auth_state_changed signal
	if not auth.has_signal("auth_state_changed"):
		_cleanup_emitter(signal_emitter, auth)
		return DebugActionResult.new_failure(
			"FirebaseAuth C++ missing auth_state_changed signal - need updated module",
			"AUTH_SIGNAL_MISSING",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	auth.auth_state_changed.connect(signal_emitter.handle_auth_state_changed)

	# Start the AuthStateListener
	_update_status("Starting AuthStateListener...")
	auth.start_auth_state_listener()

	if not auth.is_auth_state_listener_active():
		_cleanup_emitter(signal_emitter, auth)
		return DebugActionResult.new_failure(
			"AuthStateListener failed to start",
			"LISTENER_START_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	Log.info("AuthStateListener started successfully", {}, ["debug", "cpp_auth", "state_listener"])

	# Create NSRunLoop pump timer for iOS/macOS
	var pump_timer: Timer = _create_pump_timer(scene_tree)

	# Initial state change might fire immediately - wait briefly
	await _wait_for_state_change(signal_emitter, 2.0)

	var initial_changes_count: int = _state_changes.size()
	Log.info(
		"Initial state changes received",
		{"count": initial_changes_count},
		["debug", "cpp_auth", "state_listener"]
	)

	# Phase 1: Sign in anonymously and wait for state change
	_update_status("Phase 1: Signing in anonymously...")
	var sign_in_request_id: int = _get_next_request_id()

	if not auth.has_method("sign_in_anonymously_async"):
		_cleanup_all(pump_timer, signal_emitter, auth)
		return DebugActionResult.new_failure(
			"FirebaseAuth C++ missing sign_in_anonymously_async method",
			"AUTH_METHOD_MISSING",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	auth.sign_in_anonymously_async(sign_in_request_id)

	# Wait for auth_state_changed with is_signed_in=true
	var sign_in_state_received: bool = await _wait_for_signed_in_state(signal_emitter, 30.0)

	if not sign_in_state_received:
		var duration: int = Time.get_ticks_msec() - start_time
		_cleanup_all(pump_timer, signal_emitter, auth)
		return DebugActionResult.new_failure(
			"Timeout waiting for auth_state_changed after sign in",
			"STATE_CHANGE_TIMEOUT",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			duration,
			action_name,
			{"phase": "sign_in", "state_changes": _state_changes}
		)

	Log.info(
		"Phase 1 complete: Received signed-in state change",
		{"state_changes": _state_changes.size()},
		["debug", "cpp_auth", "state_listener"]
	)

	# Phase 2: Sign out and wait for state change
	_update_status("Phase 2: Signing out...")
	auth.sign_out()

	# Wait for auth_state_changed with is_signed_in=false
	var sign_out_state_received: bool = await _wait_for_signed_out_state(signal_emitter, 30.0)

	if not sign_out_state_received:
		var duration: int = Time.get_ticks_msec() - start_time
		_cleanup_all(pump_timer, signal_emitter, auth)
		return DebugActionResult.new_failure(
			"Timeout waiting for auth_state_changed after sign out",
			"STATE_CHANGE_TIMEOUT",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			duration,
			action_name,
			{"phase": "sign_out", "state_changes": _state_changes}
		)

	Log.info(
		"Phase 2 complete: Received signed-out state change",
		{"state_changes": _state_changes.size()},
		["debug", "cpp_auth", "state_listener"]
	)

	# Stop the listener
	_update_status("Stopping AuthStateListener...")
	auth.stop_auth_state_listener()

	if auth.is_auth_state_listener_active():
		Log.warning(
			"AuthStateListener still active after stop", {}, ["debug", "cpp_auth", "state_listener"]
		)

	# Cleanup
	_cleanup_all(pump_timer, signal_emitter, auth)

	# Validate results
	var duration: int = Time.get_ticks_msec() - start_time
	var signed_in_changes: Array[Dictionary] = _state_changes.filter(
		func(c: Dictionary) -> bool: return c.get("is_signed_in", false)
	)
	var signed_out_changes: Array[Dictionary] = _state_changes.filter(
		func(c: Dictionary) -> bool: return not c.get("is_signed_in", true)
	)

	var metadata: Dictionary = {
		"total_state_changes": _state_changes.size(),
		"signed_in_changes": signed_in_changes.size(),
		"signed_out_changes": signed_out_changes.size(),
		"duration_ms": duration,
		"state_changes": _state_changes
	}

	# We expect at least 1 signed-in and 1 signed-out state change
	if signed_in_changes.size() < 1:
		return DebugActionResult.new_failure(
			"No signed-in state change received",
			"MISSING_SIGNED_IN_STATE",
			DebugActionResult.ErrorCategory.VALIDATION,
			null,
			duration,
			action_name,
			metadata
		)

	if signed_out_changes.size() < 1:
		return DebugActionResult.new_failure(
			"No signed-out state change received",
			"MISSING_SIGNED_OUT_STATE",
			DebugActionResult.ErrorCategory.VALIDATION,
			null,
			duration,
			action_name,
			metadata
		)

	Log.info(
		"AuthStateListener test passed",
		metadata,
		["debug", "cpp_auth", "state_listener", "success"]
	)

	return DebugActionResult.new_success(true, duration, action_name, metadata)


func _create_pump_timer(scene_tree: SceneTree) -> Timer:
	var pump_timer: Timer = Timer.new()
	pump_timer.wait_time = 0.016  # ~60 FPS
	pump_timer.one_shot = false
	pump_timer.autostart = true
	var pump_callback: Callable = func():
		if (
			is_instance_valid(firebase_instance)
			and firebase_instance.has_method("process_notifications")
		):
			firebase_instance.process_notifications()
	pump_timer.timeout.connect(pump_callback)
	if scene_tree:
		scene_tree.root.add_child(pump_timer)
	return pump_timer


func _wait_for_state_change(emitter: StateChangeEmitter, timeout_seconds: float) -> bool:
	var awaiter: SignalAwaiter.Any = SignalAwaiter.Any.new()
	var timeout_awaiter: SignalAwaiter.Timeout = SignalAwaiter.Timeout.new(timeout_seconds)
	awaiter.add(emitter.state_changed)
	awaiter.add(timeout_awaiter.finished)
	await awaiter.finished
	return _state_changes.size() > 0


func _wait_for_signed_in_state(emitter: StateChangeEmitter, timeout_seconds: float) -> bool:
	var start_time: int = Time.get_ticks_msec()
	var timeout_ms: int = int(timeout_seconds * 1000)

	while Time.get_ticks_msec() - start_time < timeout_ms:
		# Check if we have a signed-in state
		for change: Dictionary in _state_changes:
			if change.get("is_signed_in", false):
				return true

		# Wait for next state change
		var awaiter: SignalAwaiter.Any = SignalAwaiter.Any.new()
		var timeout_awaiter: SignalAwaiter.Timeout = SignalAwaiter.Timeout.new(1.0)
		awaiter.add(emitter.state_changed)
		awaiter.add(timeout_awaiter.finished)
		await awaiter.finished

	return false


func _wait_for_signed_out_state(emitter: StateChangeEmitter, timeout_seconds: float) -> bool:
	var start_time: int = Time.get_ticks_msec()
	var timeout_ms: int = int(timeout_seconds * 1000)

	# Count how many signed-out states we had before
	var initial_signed_out_count: int = 0
	for change: Dictionary in _state_changes:
		if not change.get("is_signed_in", true):
			initial_signed_out_count += 1

	while Time.get_ticks_msec() - start_time < timeout_ms:
		# Check if we have a new signed-out state
		var current_signed_out_count: int = 0
		for change: Dictionary in _state_changes:
			if not change.get("is_signed_in", true):
				current_signed_out_count += 1

		if current_signed_out_count > initial_signed_out_count:
			return true

		# Wait for next state change
		var awaiter: SignalAwaiter.Any = SignalAwaiter.Any.new()
		var timeout_awaiter: SignalAwaiter.Timeout = SignalAwaiter.Timeout.new(1.0)
		awaiter.add(emitter.state_changed)
		awaiter.add(timeout_awaiter.finished)
		await awaiter.finished

	return false


func _cleanup_emitter(emitter: StateChangeEmitter, auth: Object) -> void:
	_stop_nsloop_pumping()
	if is_instance_valid(emitter):
		if auth.auth_state_changed.is_connected(emitter.handle_auth_state_changed):
			auth.auth_state_changed.disconnect(emitter.handle_auth_state_changed)
		emitter.queue_free()
	if is_instance_valid(auth) and auth.is_auth_state_listener_active():
		auth.stop_auth_state_listener()


func _cleanup_all(pump_timer: Timer, emitter: StateChangeEmitter, auth: Object) -> void:
	if is_instance_valid(pump_timer):
		pump_timer.queue_free()
	_cleanup_emitter(emitter, auth)
