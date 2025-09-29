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
	var firebase_backend: Object = get_firebase_database()
	if not TestValidation.validate_backend_available(firebase_backend, "Firebase RTDB"):
		return TestUtils.make_failure_result(
			"Firebase backend not available or not initialized",
			TestConstants.ERROR_CODES.BACKEND_NOT_INITIALIZED,
			0,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.RTDB_SINGLE_LISTENER)
		)

	var full_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.SINGLE_VALUE)
	var test_child_key: String = "test_value"
	var test_child_path: Array[Variant] = full_path + [test_child_key]
	var initial_value: String = TestUtils.make_test_value("RTDB Listener Test")
	var updated_value: String = TestUtils.make_test_value("Updated Listener Test")

	# Step 1: Start listener using timing helper
	var listener_op: Dictionary = await TestUtils.time_operation(
		"rtdb_start_listener",
		func() -> bool:
			firebase_backend.start_listening(full_path)
			return true
	)

	# Step 2: Add initial test data using timing helper
	var initial_set_op: Dictionary = await TestUtils.time_operation(
		"rtdb_initial_set",
		func() -> bool:
			return await execute_simple_operation(
				"set_value_async", test_child_path, initial_value, "Create Initial Test Data"
			)
	)

	if not initial_set_op.result:
		firebase_backend.stop_listening(full_path)
		return TestUtils.make_failure_result(
			"Failed to add initial data on single value listener path",
			TestConstants.ERROR_CODES.SET_FAILED,
			TestUtils.get_duration_ms(listener_op) + TestUtils.get_duration_ms(initial_set_op),
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.RTDB_SINGLE_LISTENER)
		)

	# Step 3: Update test data using timing helper
	var update_set_op: Dictionary = await TestUtils.time_operation(
		"rtdb_update_set",
		func() -> bool:
			return await execute_simple_operation(
				"set_value_async", test_child_path, updated_value, "Update Data on Listener Path"
			)
	)

	# Step 4: Stop listener using timing helper
	var stop_listener_op: Dictionary = await TestUtils.time_operation(
		"rtdb_stop_listener",
		func() -> bool:
			firebase_backend.stop_listening(full_path)
			return true
	)

	var total_duration: int = (
		TestUtils.get_duration_ms(listener_op)
		+ TestUtils.get_duration_ms(initial_set_op)
		+ TestUtils.get_duration_ms(update_set_op)
		+ TestUtils.get_duration_ms(stop_listener_op)
	)

	if update_set_op.result:
		return TestUtils.make_success_result(
			"Single value listener path functional - data operations work correctly",
			total_duration,
			action_name,
			TestUtils.make_metadata(
				TestConstants.TEST_TYPES.RTDB_SINGLE_LISTENER,
				{
					"path": full_path,
					"test_child_key": test_child_key,
					"initial_value": initial_value,
					"updated_value": updated_value,
					"listener_duration_ms": TestUtils.get_duration_ms(listener_op),
					"initial_set_duration_ms": TestUtils.get_duration_ms(initial_set_op),
					"update_set_duration_ms": TestUtils.get_duration_ms(update_set_op),
					"stop_listener_duration_ms": TestUtils.get_duration_ms(stop_listener_op),
					"listener_operations":
					["start_listening", "set_value", "update_value", "stop_listening"]
				}
			)
		)

	return TestUtils.make_failure_result(
		"Single value listener path test failed - data update operations failed",
		TestConstants.ERROR_CODES.LISTENER_FAILED,
		total_duration,
		action_name,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.RTDB_SINGLE_LISTENER,
			{
				"path": full_path,
				"test_child_key": test_child_key,
				"initial_value": initial_value,
				"attempted_updated_value": updated_value,
				"failed_operation": "set_value_async (update)",
				"listener_duration_ms": TestUtils.get_duration_ms(listener_op),
				"initial_set_duration_ms": TestUtils.get_duration_ms(initial_set_op),
				"update_set_duration_ms": TestUtils.get_duration_ms(update_set_op)
			}
		)
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
