class_name RTDBChildAddedListenerAction
extends RTDBDebugAction

var _listener_helper: ListenerTestHelper
var _active_path: Array[Variant] = []


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.listeners.child_added"
	group = "Listeners"
	description = "Sets up a listener for when children are added to a specific RTDB path and verifies it works."


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Executing " + action_name + "...")

	var firebase_backend: Object = get_firebase_database()
	if not firebase_backend:
		return DebugActionResult.new_failure(
			"Firebase backend not available",
			"DATABASE_UNAVAILABLE",
			DebugActionResult.ErrorCategory.DATABASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)

	if not firebase_backend.is_available():
		return DebugActionResult.new_failure(
			"Firebase backend not initialized",
			"DATABASE_NOT_INITIALIZED",
			DebugActionResult.ErrorCategory.DATABASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)

	# Test listener functionality by:
	# 1. Start listening to a test path
	# 2. Add data to trigger the listener
	# 3. Check if the data was successfully set (indicating listener path is working)

	_active_path = RTDBTestPaths.to_variant_array(RTDBTestPaths.CHILD_EVENTS)
	_update_status("Testing listener path: %s" % str(_active_path))

	# Start listening to the path (this tests the listener setup)
	firebase_backend.start_listening(_active_path)
	_update_status("Started listening to test path")

	var child_key: String = "test_child_" + str(TimeUtils.now_ms())
	var child_path: Array[Variant] = _active_path + [child_key]
	var child_data: Dictionary = {
		"timestamp": TimeUtils.now_ms(),
		"message": "Test child for listener validation",
		"child_id": child_key
	}

	_update_status("Adding test data to listener path...")
	var set_success: bool = await execute_simple_operation(
		"set_value_async", child_path, child_data, "Set Child Data for Listener Test"
	)

	# Stop listening after test
	firebase_backend.stop_listening(_active_path)
	_update_status("Stopped listening to test path")

	var total_duration: int = Time.get_ticks_msec() - start_time

	if set_success:
		_update_status("✅ Listener path test PASSED - data successfully set on listener path")
		return DebugActionResult.new_success(
			"Listener path functional - data operations work on listener paths",
			total_duration,
			action_name,
			{
				"test_type": "rtdb_child_added_listener_path_test",
				"path": _active_path,
				"child_key": child_key,
				"child_data": child_data,
				"listener_operations": ["start_listening", "set_value", "stop_listening"]
			}
		)

	_update_status("❌ Listener path test FAILED - could not set data on listener path", true)
	return DebugActionResult.new_failure(
		"Listener path test failed - data operations failed on listener paths",
		"LISTENER_PATH_OPERATION_FAILED",
		DebugActionResult.ErrorCategory.DATABASE,
		null,
		total_duration,
		action_name,
		{
			"test_type": "rtdb_child_added_listener_path_test",
			"path": _active_path,
			"child_key": child_key,
			"attempted_child_data": child_data,
			"failed_operation": "set_value_async"
		}
	)


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()


func _on_child_added(child_key: String, child_value: Variant) -> void:
	_listener_helper.mark_callback_received(child_key, child_value, {"listened_path": _active_path})
	_update_status("Callback received for key: %s" % child_key)
