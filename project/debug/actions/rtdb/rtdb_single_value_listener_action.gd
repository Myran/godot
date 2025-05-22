# project/debug/actions/rtdb/rtdb_single_value_listener_action.gd
@tool
class_name RTDBSingleValueListenerAction
extends DebugAction

# Store active listener ID to manage cleanup
var active_listener_id: String = ""


func _init():
	action_name = "Single Value Listener"
	category = "RTDB"
	group = "Listeners"
	description = "Sets up a listener for changes on a specific RTDB path."


func execute(target_node: Node = null) -> Array:
	var db = Engine.get_singleton("FirebaseDatabase")
	if not is_instance_valid(db):
		_update_status(target_node, "FirebaseDatabase module not found.", true)
		return _failure("FirebaseDatabase module not available.")

	var path_suffix: Array[Variant] = ["listener_test"]
	var test_base_path: Array[Variant] = ["debug_tests", "rtdb"]
	var full_path: Array[Variant] = test_base_path + path_suffix

	_update_status(target_node, "Setting up value listener for path '%s'..." % str(full_path))

# Create a callback object for the listener
	var callback_object = ListenerCallbackHandler.new()
	callback_object.setup(target_node, self, full_path)

# Add the value listener
	active_listener_id = db.add_value_listener(full_path, callback_object, "on_value_changed")

	if not active_listener_id.is_empty():
		_update_status(
			target_node,
			"Value listener active for path '%s' (ID: %s)" % [str(full_path), active_listener_id]
		)

# Set up some initial test data to trigger the listener
		var initial_value: String = "Listener Test: " + str(Time.get_ticks_msec())
		db.set_value_async(Time.get_ticks_msec() % 1000000, full_path, initial_value)

		Log.debug(
			"RTDBSingleValueListenerAction executed successfully",
			{"path": full_path, "listener_id": active_listener_id, "operation": "add_listener"},
			["test", "rtdb", "listeners"]
		)

		return _success(
			{
				"operation": "single_value_listener",
				"path": full_path,
				"listener_id": active_listener_id,
				"timestamp": Time.get_ticks_msec(),
				"status": "listening"
			}
		)
	else:
		var error_msg: String = "Failed to create value listener for path '%s'" % str(full_path)
		_update_status(target_node, error_msg, true)
		return _failure(error_msg, {"path": full_path, "operation": "single_value_listener"})


# Helper class to handle listener callbacks
class ListenerCallbackHandler:
	var target_node: Node
	var action_ref: RTDBSingleValueListenerAction
	var listened_path: Array[Variant]

	func setup(node: Node, action: RTDBSingleValueListenerAction, path: Array[Variant]):
		target_node = node
		action_ref = action
		listened_path = path

	func on_value_changed(path: Array[Variant], value: Variant):
		if action_ref and is_instance_valid(target_node):
			var status_msg: String = "Value changed at '%s': %s" % [str(path), str(value)]
			action_ref._update_status(target_node, status_msg)

			Log.info(
				"RTDB Value Listener triggered",
				{"path": path, "value": value, "listener_type": "single_value"},
				["rtdb", "listeners", "debug"]
			)
