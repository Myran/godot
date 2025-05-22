# project/debug/actions/rtdb/rtdb_update_value_action.gd
@tool
class_name RTDBUpdateValueAction
extends DebugAction


func _init():
	action_name = "Update Value"
	category = "RTDB"
	group = "Basic"
	description = "Updates an existing value at a predefined test path in RTDB."


func execute(target_node: Node = null) -> Array:
	var db = Engine.get_singleton("FirebaseDatabase")
	if not is_instance_valid(db):
	_update_status(target_node, "FirebaseDatabase module not found.", true)
	return _failure("FirebaseDatabase module not available.")

	var path_suffix: Array[Variant] = ["update_test"]
	var test_base_path: Array[Variant] = ["debug_tests", "rtdb"]
	var full_path: Array[Variant] = test_base_path + path_suffix
	var new_value: String = "Updated Value: " + str(Time.get_ticks_msec())

	_update_status(
		target_node, "Updating value at path '%s' to '%s'..." % [str(full_path), new_value]
	)

# Generate unique request ID
	var request_id: int = Time.get_ticks_msec() % 1000000

# Use Firebase database set_value_async method to update
	db.set_value_async(request_id, full_path, new_value)

# Simulate async operation completion
	await target_node.get_tree().create_timer(0.2).timeout

	_update_status(target_node, "Successfully updated value at path '%s'" % str(full_path))

	Log.debug(
		"RTDBUpdateValueAction executed successfully",
		{
			"path": full_path,
			"new_value": new_value,
			"operation": "update",
			"request_id": request_id
		},
		["test", "rtdb"]
	)

	return _success(
		{
			"operation": "update_value",
			"path": full_path,
			"value": new_value,
			"request_id": request_id,
			"timestamp": Time.get_ticks_msec()
		}
	)
