# project/debug/actions/rtdb/rtdb_delete_value_action.gd
@tool
class_name RTDBDeleteValueAction
extends DebugAction


func _init():
	action_name = "Delete Value"
	category = "RTDB"
	group = "Basic"
	description = "Deletes a value from a predefined test path in RTDB."


func execute(target_node: Node = null) -> Array:
	var db = Engine.get_singleton("FirebaseDatabase")
	if not is_instance_valid(db):
	_update_status(target_node, "FirebaseDatabase module not found.", true)
	return _failure("FirebaseDatabase module not available.")

	var path_suffix: Array[Variant] = ["delete_test"]
	var test_base_path: Array[Variant] = ["debug_tests", "rtdb"]
	var full_path: Array[Variant] = test_base_path + path_suffix

	_update_status(target_node, "Deleting value at path '%s'..." % str(full_path))

# Generate unique request ID
	var request_id: int = Time.get_ticks_msec() % 1000000

# Use Firebase database remove_value_async method
	db.remove_value_async(request_id, full_path)

# Simulate async operation completion
	await target_node.get_tree().create_timer(0.2).timeout

	_update_status(target_node, "Successfully deleted value at path '%s'" % str(full_path))

	Log.debug(
		"RTDBDeleteValueAction executed successfully",
		{"path": full_path, "operation": "delete", "request_id": request_id},
		["test", "rtdb"]
	)

	return _success(
		{
			"operation": "delete_value",
			"path": full_path,
			"request_id": request_id,
			"timestamp": Time.get_ticks_msec(),
			"status": "deleted"
		}
	)
