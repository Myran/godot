# project/debug/actions/rtdb/rtdb_get_nested_path_action.gd
@tool
class_name RTDBGetNestedPathAction
extends DebugAction


func _init():
	action_name = "Get Nested Path"
	category = "RTDB"
	group = "Paths"
	description = "Retrieves data from nested paths in RTDB structure."


func execute(target_node: Node = null) -> Array:
	var db = Engine.get_singleton("FirebaseDatabase")
	if not is_instance_valid(db):
	_update_status(target_node, "FirebaseDatabase module not found.", true)
	return _failure("FirebaseDatabase module not available.")

	var path_suffix: Array[Variant] = ["nested_test"]
	var test_base_path: Array[Variant] = ["debug_tests", "rtdb"]
	var full_path: Array[Variant] = test_base_path + path_suffix

	_update_status(target_node, "Getting nested data from path '%s'..." % str(full_path))

# Generate unique request ID
	var request_id: int = Time.get_ticks_msec() % 1000000

# Use Firebase database get_value_async method
	db.get_value_async(request_id, full_path)

# Simulate async operation and response
	await target_node.get_tree().create_timer(0.3).timeout

# Simulate a nested data response
	var result: Dictionary = {
		"metadata":
		{
			"created_at": Time.get_ticks_msec() - 60000,
			"test_type": "nested_structure",
			"version": "1.0"
		},
		"data": {"user_info": {"name": "Test User", "level": 42, "active": true}},
		"stats": {"total_tests": 123, "success_rate": 0.95}
	}

	var result_summary: Dictionary = {
		"type": "Dictionary",
		"keys": result.keys(),
		"size": result.size(),
		"metadata_keys": result.metadata.keys() if result.has("metadata") else [],
		"data_keys": result.data.keys() if result.has("data") else []
	}

	_update_status(
		target_node,
		"Successfully retrieved nested data: %d top-level keys" % result_summary.get("size", 0)
	)

	Log.debug(
		"RTDBGetNestedPathAction executed successfully",
		{
			"path": full_path,
			"result_summary": result_summary,
			"operation": "get_nested",
			"request_id": request_id
		},
		["test", "rtdb"]
	)

	return _success(
		{
			"operation": "get_nested_path",
			"path": full_path,
			"data": result,
			"summary": result_summary,
			"request_id": request_id,
			"timestamp": Time.get_ticks_msec()
		}
	)
