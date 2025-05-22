# project/debug/actions/rtdb/rtdb_remove_all_listeners_action.gd
@tool
class_name RTDBRemoveAllListenersAction
extends DebugAction


func _init():
	action_name = "Remove All Listeners"
	category = "RTDB"
	group = "Listeners"
	description = "Removes all active RTDB listeners to clean up test state."


func execute(target_node: Node = null) -> Array:
	var db = Engine.get_singleton("FirebaseDatabase")
	if not is_instance_valid(db):
		_update_status(target_node, "FirebaseDatabase module not found.", true)
		return _failure("FirebaseDatabase module not available.")

	_update_status(target_node, "Removing all RTDB listeners...")

# Call the remove_all_listeners method on the Firebase database
	var result: bool = db.remove_all_listeners()

	if result:
		_update_status(target_node, "Successfully removed all RTDB listeners")

		Log.info(
			"RTDBRemoveAllListenersAction executed successfully",
			{"operation": "remove_all_listeners"},
			["test", "rtdb", "listeners"]
		)

		return _success(
			{
				"operation": "remove_all_listeners",
				"timestamp": Time.get_ticks_msec(),
				"status": "listeners_removed"
			}
		)
	else:
		var error_msg: String = "Failed to remove all listeners"
		_update_status(target_node, error_msg, true)
		return _failure(error_msg, {"operation": "remove_all_listeners"})
