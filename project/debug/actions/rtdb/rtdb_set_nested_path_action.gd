# project/debug/actions/rtdb/rtdb_set_nested_path_action.gd
@tool
class_name RTDBSetNestedPathAction
extends DebugAction


func _init():
	action_name = "Set Nested Path"
	category = "RTDB"
	group = "Paths"
	description = "Creates/updates a nested JSON structure at a test path in RTDB."


func execute(target_node: Node = null) -> Array:
	var db = Engine.get_singleton("FirebaseDatabase")
	if not is_instance_valid(db):
		_update_status(target_node, "FirebaseDatabase module not found.", true)
		return _failure("FirebaseDatabase module not available.")

	var path_suffix: Array[Variant] = ["nested_test"]
	var test_base_path: Array[Variant] = ["debug_tests", "rtdb"]
	var full_path: Array[Variant] = test_base_path + path_suffix

# Create nested test data structure
	var nested_data: Dictionary = {
		"metadata":
		{"created_at": Time.get_ticks_msec(), "test_type": "nested_structure", "version": "1.0"},
		"data":
		{
			"user_info": {"name": "Test User", "level": 42, "active": true},
			"settings": {"theme": "dark", "notifications": true, "language": "en"}
		},
		"stats":
		{
			"total_tests": 123,
			"success_rate": 0.95,
			"last_updated": str(Time.get_datetime_dict_from_system())
		}
	}

	_update_status(target_node, "Setting nested data at path '%s'..." % str(full_path))

# Generate unique request ID
	var request_id: int = Time.get_ticks_msec() % 1000000

# Use Firebase database set_value_async method with nested structure
	db.set_value_async(request_id, full_path, nested_data)

# Simulate async operation completion
	await target_node.get_tree().create_timer(0.3).timeout

	_update_status(target_node, "Successfully set nested data at path '%s'" % str(full_path))

	Log.debug(
		"RTDBSetNestedPathAction executed successfully",
		{
			"path": full_path,
			"data_keys": nested_data.keys(),
			"operation": "set_nested",
			"request_id": request_id
		},
		["test", "rtdb"]
	)

	return _success(
		{
			"operation": "set_nested_path",
			"path": full_path,
			"data_structure": nested_data,
			"request_id": request_id,
			"timestamp": Time.get_ticks_msec()
		}
	)
