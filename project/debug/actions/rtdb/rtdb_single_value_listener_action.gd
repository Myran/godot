class_name RTDBSingleValueListenerAction
extends RTDBDebugAction

var active_listener_id: String = ""
var callback_received: bool = false
var callback_data: Dictionary = {}
var test_start_time: int = 0


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.listeners.single_value"
	group = "Listeners"
	description = "Sets up a listener for changes on a specific RTDB path using child listeners " + \
		"(C++ module limitation) and verifies it works."


func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Executing " + action_name + "...")

	var db: Object = get_firebase_database()
	if not db:
		return DebugAction.Result.new_failure(
			"Firebase database not available",
			"DATABASE_UNAVAILABLE",
			DebugAction.Result.ErrorCategory.DATABASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)

	var full_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.SINGLE_VALUE)

	callback_received = false
	callback_data = {}
	test_start_time = Time.get_ticks_msec()

	_update_status("Setting up value listener for path '%s'..." % str(full_path))

	if not db.db.is_signal_connected("child_changed", _on_value_changed):
		db.db.connect_signal("child_changed", _on_value_changed)

	db.start_listening(full_path)
	active_listener_id = str(full_path)  # Use path as ID for tracking

	_update_status("Value listener active for path '%s' (using child listener)" % [str(full_path)])

	var test_child_key: String = "test_value"
	var test_child_path: Array[Variant] = full_path + [test_child_key]
	var initial_value: String = "Listener Test: " + str(Time.get_ticks_msec())

	_update_status("Creating initial test data...")
	var set_success1: bool = await execute_simple_operation(
		"set_value_async", test_child_path, initial_value, "Create Initial Test Data"
	)

	await Engine.get_main_loop().create_timer(0.5).timeout
	_update_status("Modifying data to trigger listener...")
	var updated_value: String = "Updated Listener Test: " + str(Time.get_ticks_msec())
	var set_success2: bool = await execute_simple_operation(
		"set_value_async", test_child_path, updated_value, "Update Data to Trigger Listener"
	)

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

			return DebugAction.Result.new_listener_result(
				false,
				{},
				timeout_ms,
				"single_value_listener_test",
				Time.get_ticks_msec() - start_time,
				{
					"test_type": "rtdb_single_value_listener",
					"path": full_path,
					"listener_id": active_listener_id,
					"timeout_reason": "no_callback_received"
				}
			)

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

	return DebugAction.Result.new_listener_result(
		true,
		callback_data,
		timeout_ms,
		"single_value_listener_test",
		Time.get_ticks_msec() - start_time,
		{
			"test_type": "rtdb_single_value_listener",
			"path": full_path,
			"listener_id": active_listener_id,
			"total_duration_ms": Time.get_ticks_msec() - test_start_time,
			"callback_timing": callback_data.get("received_at_ms", 0) - test_start_time
		}
	)


func execute_rtdb_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()


func _on_value_changed(child_key: String, child_value: Variant) -> void:
	callback_received = true
	callback_data = {
		"child_key": child_key,
		"child_value": child_value,
		"listener_path": RTDBTestPaths.to_variant_array(RTDBTestPaths.SINGLE_VALUE),
		"received_at_ms": Time.get_ticks_msec()
	}

	var status_msg: String = (
		"✅ LISTENER CALLBACK RECEIVED - Value changed at '%s/%s': %s"
		% [str(RTDBTestPaths.SINGLE_VALUE), child_key, str(child_value)]
	)
	_update_status(status_msg)

	Log.info(
		"RTDB Single Value Listener callback triggered",
		{
			"path": RTDBTestPaths.SINGLE_VALUE,
			"child_key": child_key,
			"child_value": child_value,
			"listener_type": "single_value_via_child_listener",
			"callback_confirmed": true
		},
		["rtdb", "listeners", "debug", "callback"]
	)
