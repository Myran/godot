# project/debug/actions/rtdb/rtdb_child_removed_listener_action.gd
@tool
class_name RTDBChildRemovedListenerAction
extends RTDBDebugAction

var _listener_helper: ListenerTestHelper
var _active_path: Array[Variant] = []


func _init() -> void:
	action_name = "Child Removed Listener"
	group = "Listeners"
	description = "Sets up a listener for when children are removed from a specific RTDB path and verifies it works."


func execute() -> Array:
	var db: Object = get_firebase_database()
	if not db:
		return get_last_error_result()

	# Setup test path and helper
	_active_path = RTDBTestPaths.to_variant_array(RTDBTestPaths.CHILD_EVENTS)
	_listener_helper = ListenerTestHelper.new()
	_listener_helper.reset()

	_update_status("Setting up child removed listener...")

	# Connect to child_removed signal
	if not db.child_removed.is_connected(_on_child_removed):
		db.child_removed.connect(_on_child_removed.bind())

	# Add listener at path
	db.add_listener_at_path(_active_path)
	_update_status("Listener active for path: %s" % str(_active_path))

	# Create test child then remove it
	var child_key: String = "temp_child_" + str(TimeUtils.now_ms())
	var child_path: Array[Variant] = _active_path + [child_key]
	var child_data: Dictionary = {
		"timestamp": TimeUtils.now_ms(),
		"message": "Temporary child for removal test",
		"child_id": child_key
	}

	# Set child data first
	_update_status("Creating test child...")
	db.set_value_async(RTDBDebugAction.generate_request_id(), child_path, child_data)

	# Wait briefly then remove to trigger listener
	await Engine.get_main_loop().create_timer(0.5).timeout

	_update_status("Removing child to trigger listener...")
	db.remove_value_async(RTDBDebugAction.generate_request_id(), child_path)

	# Wait for callback
	_update_status("Waiting for listener callback...")
	var result: Dictionary = await _listener_helper.wait_for_callback(5.0)

	if result.success:
		_update_status("✅ Listener test PASSED")
		return _success(
			{
				"operation": "child_removed_listener_test",
				"path": _active_path,
				"test_result": "PASSED",
				"callback_data": result.data,
				"timestamp": TimeUtils.now_ms()
			}
		)
	else:
		_update_status("❌ Listener test FAILED: " + result.error, true)
		return _failure(result.error)


func _on_child_removed(child_key: String, child_value: Variant) -> void:
	_listener_helper.mark_callback_received(child_key, child_value, {"listened_path": _active_path})
	_update_status("Callback received for removed key: %s" % child_key)
