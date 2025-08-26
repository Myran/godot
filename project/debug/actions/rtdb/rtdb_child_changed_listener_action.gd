class_name RTDBChildChangedListenerAction
extends RTDBDebugAction

var _listener_helper: ListenerTestHelper
var _active_path: Array[Variant] = []


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.listeners.child_changed"
	group = "Listeners"
	description = "Sets up a listener for when children are changed at a specific RTDB path and verifies it works."


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()
	_update_status("Executing " + action_name + "...")

	var db: Object = get_firebase_database()
	if not db:
		return DebugActionResult.new_failure(
			"Firebase database not available",
			"DATABASE_UNAVAILABLE",
			DebugActionResult.ErrorCategory.DATABASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)

	_active_path = RTDBTestPaths.to_variant_array(RTDBTestPaths.CHILD_EVENTS)
	_listener_helper = ListenerTestHelper.new()
	_listener_helper.reset()

	_update_status("Setting up child changed listener...")

	if not db.db.is_signal_connected("child_changed", _on_child_changed):
		db.db.connect_signal("child_changed", _on_child_changed)

	db.start_listening(_active_path)
	_update_status("Listener active for path: %s" % str(_active_path))

	var child_key: String = "test_child_" + str(TimeUtils.now_ms())
	var child_path: Array[Variant] = _active_path + [child_key]

	var initial_data: Dictionary = {
		"timestamp": TimeUtils.now_ms(), "message": "Initial data", "version": 1
	}
	var set_success1: bool = await execute_simple_operation(
		"set_value_async", child_path, initial_data, "Set Initial Data for Change Test"
	)

	await Engine.get_main_loop().create_timer(0.5).timeout

	var updated_data: Dictionary = {
		"timestamp": TimeUtils.now_ms(), "message": "Updated data", "version": 2
	}
	var set_success2: bool = await execute_simple_operation(
		"set_value_async", child_path, updated_data, "Update Data to Trigger Change Listener"
	)

	_update_status("Waiting for listener callback...")
	var result: Dictionary = await _listener_helper.wait_for_callback(5.0)

	var total_duration: int = Time.get_ticks_msec() - start_time

	if result.success:
		_update_status("✅ Listener test PASSED")
		return DebugActionResult.new_listener_result(
			true,
			result,
			5000,
			"child_changed_listener_test",
			total_duration,
			{
				"test_type": "rtdb_child_changed_listener",
				"path": _active_path,
				"child_key": child_key,
				"initial_data": initial_data,
				"updated_data": updated_data,
				"listener_result": result
			}
		)

	_update_status("❌ Listener test FAILED: " + str(result.get("error", "unknown error")), true)
	return DebugActionResult.new_listener_result(
		false,
		result,
		5000,
		"child_changed_listener_test",
		total_duration,
		{
			"test_type": "rtdb_child_changed_listener",
			"path": _active_path,
			"child_key": child_key,
			"attempted_initial_data": initial_data,
			"attempted_updated_data": updated_data,
			"error_details": result.get("error", "unknown error")
		}
	)


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()


func _on_child_changed(child_key: String, child_value: Variant) -> void:
	_listener_helper.mark_callback_received(child_key, child_value, {"listened_path": _active_path})
	_update_status("Callback received for key: %s" % child_key)
