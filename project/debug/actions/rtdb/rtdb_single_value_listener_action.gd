# project/debug/actions/rtdb/rtdb_single_value_listener_action.gd
@tool
class_name RTDBSingleValueListenerAction
extends RTDBDebugAction

# Store active listener ID to manage cleanup
var active_listener_id: String = ""
var callback_received: bool = false
var callback_data: Dictionary = {}
var test_start_time: int = 0


func _init() -> void:
	action_name = "Single Value Listener"
	group = "Listeners"
	description = "Sets up a listener for changes on a specific RTDB path using child listeners (C++ module limitation) and verifies it works."


func execute() -> Array:
	var db: Object = get_firebase_database()
	if not db:
		return get_last_error_result()

	var path_suffix: Array[Variant] = ["listener_test"]
	var full_path: Array[Variant] = create_test_path(path_suffix)

	# Reset test state
	callback_received = false
	callback_data = {}
	test_start_time = Time.get_ticks_msec()

	_update_status("Setting up value listener for path '%s'..." % str(full_path))

	# Note: C++ Firebase module only supports child listeners, not single value listeners
	# We'll use child_changed signal to detect value changes
	if not db.child_changed.is_connected(_on_value_changed):
		db.child_changed.connect(_on_value_changed.bind(full_path))

	# Use the only available listener method in C++ module
	db.add_listener_at_path(full_path)
	active_listener_id = str(full_path)  # Use path as ID for tracking

	_update_status("Value listener active for path '%s' (using child listener)" % [str(full_path)])

	# Set up some initial test data to trigger the listener
	var test_child_key: String = "test_value"
	var test_child_path: Array[Variant] = full_path + [test_child_key]
	var initial_value: String = "Listener Test: " + str(Time.get_ticks_msec())

	_update_status("Creating initial test data...")
	db.set_value_async(Time.get_ticks_msec() % 1000000, test_child_path, initial_value)

	# Wait and update to trigger change
	await Engine.get_main_loop().create_timer(0.5).timeout
	_update_status("Modifying data to trigger listener...")
	var updated_value: String = "Updated Listener Test: " + str(Time.get_ticks_msec())
	db.set_value_async((Time.get_ticks_msec() + 1) % 1000000, test_child_path, updated_value)

	# NOW WAIT TO VERIFY THE LISTENER ACTUALLY FIRES
	_update_status("Waiting for listener callback...")
	var timeout_ms: int = 5000  # 5 seconds in milliseconds
	var wait_start: int = Time.get_ticks_msec()

	while not callback_received:
		await Engine.get_main_loop().process_frame
		var elapsed_ms: int = Time.get_ticks_msec() - wait_start

		if elapsed_ms > timeout_ms:
			var error_msg: String = (
				"Listener test FAILED: No callback received after %.1f seconds"
				% (timeout_ms / 1000.0)
			)
			_update_status(error_msg, true)

			Log.error(
				"RTDB Single Value Listener test failed - no callback",
				{"path": full_path, "timeout_ms": timeout_ms, "operation": "listener_test"},
				["test", "rtdb", "listeners", "failure"]
			)

			return _failure(
				error_msg, {"path": full_path, "timeout_ms": timeout_ms, "callback_received": false}
			)

	# SUCCESS - callback was received!
	var success_msg: String = (
		"Listener test PASSED: Callback received with data: %s" % str(callback_data)
	)
	_update_status(success_msg)

	Log.info(
		"RTDB Single Value Listener test PASSED",
		{
			"path": full_path,
			"listener_id": active_listener_id,
			"callback_data": callback_data,
			"test_duration_ms": Time.get_ticks_msec() - test_start_time,
			"operation": "listener_test_success"
		},
		["test", "rtdb", "listeners", "success"]
	)

	return _success(
		{
			"operation": "single_value_listener_test",
			"path": full_path,
			"listener_id": active_listener_id,
			"callback_received": true,
			"callback_data": callback_data,
			"test_result": "PASSED",
			"timestamp": Time.get_ticks_msec(),
			"implementation": "child_listener_based"
		}
	)


## Signal handler for value changes (using child_changed from C++ Firebase module)
## Signature matches the C++ module: child_changed(key: String, value: Variant)
func _on_value_changed(
	child_key: String, child_value: Variant, listened_path: Array[Variant]
) -> void:
	# Mark that we received the callback!
	callback_received = true
	callback_data = {
		"child_key": child_key,
		"child_value": child_value,
		"listened_path": listened_path,
		"received_at_ms": Time.get_ticks_msec()
	}

	var status_msg: String = (
		"✅ LISTENER CALLBACK RECEIVED - Value changed at '%s/%s': %s"
		% [str(listened_path), child_key, str(child_value)]
	)
	_update_status(status_msg)

	Log.info(
		"RTDB Single Value Listener callback triggered",
		{
			"path": listened_path,
			"child_key": child_key,
			"child_value": child_value,
			"listener_type": "single_value_via_child_listener",
			"callback_confirmed": true
		},
		["rtdb", "listeners", "debug", "callback"]
	)
