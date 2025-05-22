# project/debug/actions/rtdb/rtdb_child_removed_listener_action.gd
@tool
class_name RTDBChildRemovedListenerAction
extends DebugAction

# Store active listener ID to manage cleanup
var active_listener_id: String = ""


func _init():
	action_name = "Child Removed Listener"
	category = "RTDB"
	group = "Listeners"
	description = "Sets up a listener for when children are removed from a specific RTDB path."


func execute(target_node: Node = null) -> Array:
	var db = Engine.get_singleton("FirebaseDatabase")
	if not is_instance_valid(db):
		_update_status(target_node, "FirebaseDatabase module not found.", true)
		return _failure("FirebaseDatabase module not available.")

	var path_suffix: Array[Variant] = ["child_events"]
	var test_base_path: Array[Variant] = ["debug_tests", "rtdb"]
	var full_path: Array[Variant] = test_base_path + path_suffix

	_update_status(
		target_node, "Setting up child removed listener for path '%s'..." % str(full_path)
	)

# Create a callback object for the listener
	var callback_object = ChildRemovedCallbackHandler.new()
	callback_object.setup(target_node, self, full_path)

# Add the child removed listener
	active_listener_id = db.add_child_removed_listener(
		full_path, callback_object, "on_child_removed"
	)

	if not active_listener_id.is_empty():
		_update_status(
			target_node,
			(
				"Child removed listener active for path '%s' (ID: %s)"
				% [str(full_path), active_listener_id]
			)
		)

# Create a test child and then remove it to trigger the listener
		var child_key: String = "temp_child_" + str(Time.get_ticks_msec())
		var child_data: Dictionary = {
			"timestamp": Time.get_ticks_msec(),
			"message": "Temporary child for removal test",
			"child_id": child_key
		}
		var child_path: Array[Variant] = full_path + [child_key]

		# Set the child data first
		db.set_value_async(Time.get_ticks_msec() % 1000000, child_path, child_data)

		# Wait briefly then remove to trigger removal listener
		await target_node.get_tree().create_timer(0.3).timeout
		db.remove_value_async((Time.get_ticks_msec() + 1) % 1000000, child_path)

		Log.debug(
			"RTDBChildRemovedListenerAction executed successfully",
			{
				"path": full_path,
				"listener_id": active_listener_id,
				"operation": "add_child_removed_listener"
			},
			["test", "rtdb", "listeners"]
		)

		return _success(
			{
				"operation": "child_removed_listener",
				"path": full_path,
				"listener_id": active_listener_id,
				"timestamp": Time.get_ticks_msec(),
				"status": "listening"
			}
		)
	else:
		var error_msg: String = (
			"Failed to create child removed listener for path '%s'" % str(full_path)
		)
		_update_status(target_node, error_msg, true)
		return _failure(error_msg, {"path": full_path, "operation": "child_removed_listener"})


# Helper class to handle child removed listener callbacks
class ChildRemovedCallbackHandler:
	var target_node: Node
	var action_ref: RTDBChildRemovedListenerAction
	var listened_path: Array[Variant]

	func setup(node: Node, action: RTDBChildRemovedListenerAction, path: Array[Variant]):
		target_node = node
		action_ref = action
		listened_path = path

	func on_child_removed(child_key: String, child_value: Variant):
		if action_ref and is_instance_valid(target_node):
			var status_msg: String = (
				"Child removed '%s' from '%s': %s"
				% [child_key, str(listened_path), str(child_value)]
			)
			action_ref._update_status(target_node, status_msg)

			Log.info(
				"RTDB Child Removed Listener triggered",
				{
					"path": listened_path,
					"child_key": child_key,
					"child_value": child_value,
					"listener_type": "child_removed"
				},
				["rtdb", "listeners", "debug"]
			)
