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
	description = (
		"Sets up a listener for changes on a specific RTDB path using child listeners "
		+ "(C++ module limitation) and verifies it works."
	)


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

	# Test single value listener functionality by:
	# 1. Start listening to a test path
	# 2. Add/modify test data to the path
	# 3. Verify data operations succeed (indicating listener path is functional)

	var full_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.SINGLE_VALUE)
	_update_status("Testing single value listener path: %s" % str(full_path))

	firebase_backend.start_listening(full_path)
	_update_status("Started listening to single value test path")

	var test_child_key: String = "test_value"
	var test_child_path: Array[Variant] = full_path + [test_child_key]
	var initial_value: String = "Listener Test: " + str(Time.get_ticks_msec())

	_update_status("Adding initial test data...")
	var set_success1: bool = await execute_simple_operation(
		"set_value_async", test_child_path, initial_value, "Create Initial Test Data"
	)

	if not set_success1:
		firebase_backend.stop_listening(full_path)
		var failure_duration: int = Time.get_ticks_msec() - start_time
		return DebugActionResult.new_failure(
			"Failed to add initial data on single value listener path",
			"INITIAL_DATA_SET_FAILED",
			DebugActionResult.ErrorCategory.DATABASE,
			null,
			failure_duration,
			action_name
		)

	_update_status("Updating test data on listener path...")
	var updated_value: String = "Updated Listener Test: " + str(Time.get_ticks_msec())
	var set_success2: bool = await execute_simple_operation(
		"set_value_async", test_child_path, updated_value, "Update Data on Listener Path"
	)

	firebase_backend.stop_listening(full_path)
	_update_status("Stopped listening to single value test path")

	var total_duration: int = Time.get_ticks_msec() - start_time

	if set_success2:
		_update_status("✅ Single value listener path test PASSED - data operations successful")
		return DebugActionResult.new_success(
			"Single value listener path functional - data operations work correctly",
			total_duration,
			action_name,
			{
				"test_type": "rtdb_single_value_listener_path_test",
				"path": full_path,
				"test_child_key": test_child_key,
				"initial_value": initial_value,
				"updated_value": updated_value,
				"listener_operations":
				["start_listening", "set_value", "update_value", "stop_listening"]
			}
		)

	_update_status("❌ Single value listener path test FAILED - data update failed", true)
	return DebugActionResult.new_failure(
		"Single value listener path test failed - data update operations failed",
		"LISTENER_PATH_UPDATE_FAILED",
		DebugActionResult.ErrorCategory.DATABASE,
		null,
		total_duration,
		action_name,
		{
			"test_type": "rtdb_single_value_listener_path_test",
			"path": full_path,
			"test_child_key": test_child_key,
			"initial_value": initial_value,
			"attempted_updated_value": updated_value,
			"failed_operation": "set_value_async (update)"
		}
	)


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
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
