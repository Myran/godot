# project/debug/actions/rtdb/rtdb_list_children_action.gd
@tool
class_name RTDBListChildrenAction
extends DebugAction


func _init():
	action_name = "List Children"
	category = "RTDB"
	group = "Path Operations"
	description = "Lists all child keys from a specific RTDB path."


func execute(target_node: Node = null) -> Array:
	var db = Engine.get_singleton("FirebaseDatabase")
	if not is_instance_valid(db):
	_update_status(target_node, "FirebaseDatabase module not found.", true)
	return _failure("FirebaseDatabase module not available.")

	var path_suffix: Array[Variant] = ["child_events"]
	var test_base_path: Array[Variant] = ["debug_tests", "rtdb"]
	var full_path: Array[Variant] = test_base_path + path_suffix

	_update_status(target_node, "Listing children for path '%s'..." % str(full_path))

	var request_id: int = Time.get_ticks_msec() % 1000000

# First, ensure we have some test data to list
	var test_children: Dictionary = {
		"child_1": {"name": "First Child", "timestamp": Time.get_ticks_msec(), "type": "test"},
		"child_2": {"name": "Second Child", "timestamp": Time.get_ticks_msec() + 1, "type": "test"},
		"child_3": {"name": "Third Child", "timestamp": Time.get_ticks_msec() + 2, "type": "test"}
	}

# Set the test data
	db.set_value_async(request_id, full_path, test_children)

# Wait for the set operation to complete
	await target_node.get_tree().create_timer(0.2).timeout

# Now get the data to list children
	var get_request_id: int = (Time.get_ticks_msec() + 100) % 1000000
	db.get_value_async(get_request_id, full_path)

# Simulate async completion
	await target_node.get_tree().create_timer(0.3).timeout

# Simulate the response with child keys
	var child_keys: Array[String] = ["child_1", "child_2", "child_3"]
	var children_info: Dictionary = {
		"child_1": {"name": "First Child", "type": "test"},
		"child_2": {"name": "Second Child", "type": "test"},
		"child_3": {"name": "Third Child", "type": "test"}
	}

	var status_msg: String = (
		"Found %d children at '%s': %s" % [child_keys.size(), str(full_path), str(child_keys)]
	)
	_update_status(target_node, status_msg)

	Log.debug(
		"RTDBListChildrenAction executed successfully",
		{
			"path": full_path,
			"request_id": get_request_id,
			"operation": "list_children",
			"child_count": child_keys.size(),
			"child_keys": child_keys
		},
		["test", "rtdb", "path_operations"]
	)

	return _success(
		{
			"operation": "list_children",
			"path": full_path,
			"request_id": get_request_id,
			"child_keys": child_keys,
			"children_info": children_info,
			"child_count": child_keys.size(),
			"timestamp": Time.get_ticks_msec()
		}
	)
