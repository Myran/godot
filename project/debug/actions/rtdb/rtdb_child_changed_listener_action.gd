# project/debug/actions/rtdb/rtdb_child_changed_listener_action.gd
@tool
class_name RTDBChildChangedListenerAction
extends DebugAction

# Store active listener ID to manage cleanup
var active_listener_id: String = ""


func _init():
	action_name = "Child Changed Listener"
	category = "RTDB"
	group = "Listeners"
	description = "Sets up a listener for when children are changed at a specific RTDB path."


func execute(target_node: Node = null) -> Array:
	var db = Engine.get_singleton("FirebaseDatabase")
	if not is_instance_valid(db):
		_update_status(target_node, "FirebaseDatabase module not found.", true)
		return _failure("FirebaseDatabase module not available.")

	var path_suffix: Array[Variant] = ["child_events"]
	var test_base_path: Array[Variant] = ["debug_tests", "rtdb"]
	var full_path: Array[Variant] = test_base_path + path_suffix

	_update_status(
		target_node, "Setting up child changed listener for path '%s'..." % str(full_path)
	)

# Create a callback object for the listener
	var callback_object = ChildChangedCallbackHandler.new()
	callback_object.setup(target_node, self, full_path)

# Add the child changed listener
	active_listener_id = db.add_child_changed_listener(
		full_path, callback_object, "on_child_changed"
	)

	if not active_listener_id.is_empty():
		_update_status(
			target_node,
			(
				"Child changed listener active for path '%s' (ID: %s)"
				% [str(full_path), active_listener_id]
			)
		)

# Create and then modify a test child to trigger the listener
		var child_key: String = "test_child_" + str(Time.get_ticks_msec())
		var initial_data: Dictionary = {
			"timestamp": Time.get_ticks_msec(),
			"message": "Initial child data",
			"child_id": child_key,
			"version": 1
		}
		var child_path: Array[Variant] = full_path + [child_key]

		# Set initial data
		db.set_value_async(Time.get_ticks_msec() % 1000000, child_path, initial_data)

		# Wait briefly then update to trigger change listener
		await target_node.get_tree().create_timer(0.3).timeout
		var updated_data: Dictionary = {
			"timestamp": Time.get_ticks_msec(),
			"message": "Updated child data for change listener",
			"child_id": child_key,
			"version": 2
		}
		db.set_value_async((Time.get_ticks_msec() + 1) % 1000000, child_path, updated_data)

		Log.debug(
			"RTDBChildChangedListenerAction executed successfully",
			{
				"path": full_path,
				"listener_id": active_listener_id,
				"operation": "add_child_changed_listener"
			},
			["test", "rtdb", "listeners"]
		)

		return _success(
			{
				"operation": "child_changed_listener",
				"path": full_path,
				"listener_id": active_listener_id,
				"timestamp": Time.get_ticks_msec(),
				"status": "listening"
			}
		)
	else:
		var error_msg: String = (
			"Failed to create child changed listener for path '%s'" % str(full_path)
		)
		_update_status(target_node, error_msg, true)
		return _failure(error_msg, {"path": full_path, "operation": "child_changed_listener"})


# Helper class to handle child changed listener callbacks
class ChildChangedCallbackHandler:
	var target_node: Node
	var action_ref: RTDBChildChangedListenerAction
	var listened_path: Array[Variant]

	func setup(node: Node, action: RTDBChildChangedListenerAction, path: Array[Variant]):
		target_node = node
		action_ref = action
		listened_path = path

	func on_child_changed(child_key: String, child_value: Variant, previous_child_key: String):
		if action_ref and is_instance_valid(target_node):
			var status_msg: String = (
				"Child changed '%s' at '%s': %s (after: %s)"
				% [child_key, str(listened_path), str(child_value), previous_child_key]
			)
			action_ref._update_status(target_node, status_msg)

			Log.info(
				"RTDB Child Changed Listener triggered",
				{
					"path": listened_path,
					"child_key": child_key,
					"child_value": child_value,
					"previous_child_key": previous_child_key,
					"listener_type": "child_changed"
				},
				["rtdb", "listeners", "debug"]
			)
