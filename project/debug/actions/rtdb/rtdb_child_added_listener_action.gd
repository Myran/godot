# project/debug/actions/rtdb/rtdb_child_added_listener_action.gd
class_name RTDBChildAddedListenerAction
extends RTDBDebugAction

var _listener_helper: ListenerTestHelper
var _active_path: Array[Variant] = []


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.listeners.child_added"
	group = "Listeners"
	description = "Sets up a listener for when children are added to a specific RTDB path and verifies it works."


# New DebugAction.Result pattern - this is the future
func _execute_action_logic(params: Dictionary = {}) -> DebugAction.Result:
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

	# Setup test path and helper
	_active_path = RTDBTestPaths.to_variant_array(RTDBTestPaths.CHILD_EVENTS)
	_listener_helper = ListenerTestHelper.new()
	_listener_helper.reset()

	_update_status("Setting up child added listener...")

	# Connect to child_added signal using the wrapper's method
	if not db.db.is_signal_connected("child_added", _on_child_added):
		db.db.connect_signal("child_added", _on_child_added)

	# Start listening at path
	db.start_listening(_active_path)
	_update_status("Listener active for path: %s" % str(_active_path))

	# Add test child to trigger listener
	var child_key: String = "test_child_" + str(TimeUtils.now_ms())
	var child_path: Array[Variant] = _active_path + [child_key]
	var child_data: Dictionary = {
		"timestamp": TimeUtils.now_ms(),
		"message": "Test child for add listener",
		"child_id": child_key
	}

	_update_status("Adding test child to trigger listener...")
	var set_success: bool = await execute_simple_operation(
		"set_value_async", child_path, child_data, "Add Child for Listener Test"
	)

	# Wait for callback
	_update_status("Waiting for listener callback...")
	var result: Dictionary = await _listener_helper.wait_for_callback(5.0)

	var total_duration: int = Time.get_ticks_msec() - start_time

	if result.success:
		_update_status("✅ Listener test PASSED")
		return DebugAction.Result.new_listener_result(
			true,
			result,
			5000,
			"child_added_listener_test",
			total_duration,
			{
				"test_type": "rtdb_child_added_listener",
				"path": _active_path,
				"child_key": child_key,
				"child_data": child_data,
				"listener_result": result
			}
		)
	else:
		_update_status("❌ Listener test FAILED: " + str(result.get("error", "unknown error")), true)
		return DebugAction.Result.new_listener_result(
			false,
			result,
			5000,
			"child_added_listener_test",
			total_duration,
			{
				"test_type": "rtdb_child_added_listener",
				"path": _active_path,
				"child_key": child_key,
				"attempted_child_data": child_data,
				"error_details": result.get("error", "unknown error")
			}
		)


# Legacy method for compatibility - delegates to new pattern
func execute_rtdb_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()


func _on_child_added(child_key: String, child_value: Variant) -> void:
	_listener_helper.mark_callback_received(child_key, child_value, {"listened_path": _active_path})
	_update_status("Callback received for key: %s" % child_key)
