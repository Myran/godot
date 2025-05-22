# project/debug/actions/rtdb/rtdb_child_added_listener_action.gd
@tool
class_name RTDBChildAddedListenerAction
extends DebugAction

# Store active listener ID to manage cleanup
var active_listener_id: String = ""


func _init():
	action_name = "Child Added Listener"
	category = "RTDB"
	group = "Listeners"
	description = "Sets up a listener for when children are added to a specific RTDB path."


func execute(target_node: Node = null) -> Array:
	var db = Engine.get_singleton("FirebaseDatabase")
	if not is_instance_valid(db):
		_update_status(target_node, "FirebaseDatabase module not found.", true)
		return _failure("FirebaseDatabase module not available.")

	var path_suffix: Array[Variant] = ["child_events"]
	var test_base_path: Array[Variant] = ["debug_tests", "rtdb"]
	var full_path: Array[Variant] = test_base_path + path_suffix

	_update_status(target_node, "Setting up child added listener for path '%s'..." % str(full_path))

# Create a callback object for the listener
	var callback_object = ChildAddedCallbackHandler.new()
	callback_object.setup(target_node, self, full_path)

# Add the child added listener
	active_listener_id = db.add_child_added_listener(full_path, callback_object, "on_child_added")

	if not active_listener_id.is_empty():
		_update_status(
			target_node,
			(
				"Child added listener active for path '%s' (ID: %s)"
				% [str(full_path), active_listener_id]
			)
		)

# Add some test child data to trigger the listener
		var child_key: String = "test_child_" + str(Time.get_ticks_msec())
		var child_data: Dictionary = {
			"timestamp": Time.get_ticks_msec(),
			"message": "Test child added for listener",
			"child_id": child_key
		}
		var child_path: Array[Variant] = full_path + [child_key]
		db.set_value_async(Time.get_ticks_msec() % 1000000, child_path, child_data)

		Log.debug(
			"RTDBChildAddedListenerAction executed successfully",
			{
				"path": full_path,
				"listener_id": active_listener_id,
				"operation": "add_child_listener"
			},
			["test", "rtdb", "listeners"]
		)

		return _success(
			{
				"operation": "child_added_listener",
				"path": full_path,
				"listener_id": active_listener_id,
				"timestamp": Time.get_ticks_msec(),
				"status": "listening"
			}
		)
	else:
		var error_msg: String = (
			"Failed to create child added listener for path '%s'" % str(full_path)
		)
		_update_status(target_node, error_msg, true)
		return _failure(error_msg, {"path": full_path, "operation": "child_added_listener"})


# Helper class to handle child added listener callbacks
class ChildAddedCallbackHandler:
	var target_node: Node
	var action_ref: RTDBChildAddedListenerAction
	var listened_path: Array[Variant]

	func setup(node: Node, action: RTDBChildAddedListenerAction, path: Array[Variant]):
		target_node = node
		action_ref = action
		listened_path = path

	func on_child_added(child_key: String, child_value: Variant, previous_child_key: String):
		if action_ref and is_instance_valid(target_node):
			var status_msg: String = (
				"Child added '%s' at '%s': %s (after: %s)"
				% [child_key, str(listened_path), str(child_value), previous_child_key]
			)
			action_ref._update_status(target_node, status_msg)

			Log.info(
				"RTDB Child Added Listener triggered",
				{
					"path": listened_path,
					"child_key": child_key,
					"child_value": child_value,
					"previous_child_key": previous_child_key,
					"listener_type": "child_added"
				},
				["rtdb", "listeners", "debug"]
			)
