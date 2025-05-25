# project/debug/actions/rtdb/rtdb_child_changed_listener_action.gd
@tool
class_name RTDBChildChangedListenerAction
extends RTDBDebugAction

var _listener_helper: ListenerTestHelper
var _active_path: Array[Variant] = []


func _init() -> void:
	action_name = "Child Changed Listener"
	group = "Listeners"
	description = "Sets up a listener for when children are changed at a specific RTDB path and verifies it works."


func execute() -> Array:
	var db: Object = get_firebase_database()
	if not db:
		return get_last_error_result()

	# Setup test path and helper
	_active_path = RTDBTestPaths.to_variant_array(RTDBTestPaths.CHILD_EVENTS)
	_listener_helper = ListenerTestHelper.new()
	_listener_helper.reset()

	_update_status("Setting up child changed listener...")

	# Connect to child_changed signal
	if not db.child_changed.is_connected(_on_child_changed):
		db.child_changed.connect(_on_child_changed.bind())

	# Add listener at path
	db.add_listener_at_path(_active_path)
	_update_status("Listener active for path: %s" % str(_active_path))

	# Create test data
	var child_key: String = "test_child_" + str(TimeUtils.now_ms())
	var child_path: Array[Variant] = _active_path + [child_key]

	# Set initial data
	var initial_data: Dictionary = {
		"timestamp": TimeUtils.now_ms(), "message": "Initial data", "version": 1
	}
	db.set_value_async(RTDBDebugAction.generate_request_id(), child_path, initial_data)

	# Wait briefly then update to trigger change listener
	await Engine.get_main_loop().create_timer(0.5).timeout

	# Update data to trigger listener
	var updated_data: Dictionary = {
		"timestamp": TimeUtils.now_ms(), "message": "Updated data", "version": 2
	}
	db.set_value_async(RTDBDebugAction.generate_request_id(), child_path, updated_data)

	# Wait for callback
	_update_status("Waiting for listener callback...")
	var result: Dictionary = await _listener_helper.wait_for_callback(5.0)

	if result.success:
		_update_status("✅ Listener test PASSED")
		return _success(
			{
				"operation": "child_changed_listener_test",
				"path": _active_path,
				"test_result": "PASSED",
				"callback_data": result.data,
				"timestamp": TimeUtils.now_ms()
			}
		)
	else:
		_update_status("❌ Listener test FAILED: " + result.error, true)
		return _failure(result.error)


func _on_child_changed(child_key: String, child_value: Variant) -> void:
	_listener_helper.mark_callback_received(child_key, child_value, {"listened_path": _active_path})
	_update_status("Callback received for key: %s" % child_key)
