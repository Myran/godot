# project/debug/actions/rtdb/rtdb_list_children_action.gd
@tool
class_name RTDBListChildrenAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "List Children"
	group = "Path Operations"
	description = "Lists all child keys from a specific RTDB path."


func execute() -> Array:
	var db: Object = get_firebase_database()
	if not db:
		return get_last_error_result()

	var full_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.LIST_CHILDREN)
	var op_manager := FirebaseOperationManager.new(db)

	_update_status("Setting up test children...")

	# Create test children
	var test_children: Dictionary = {
		"child_1": {"name": "First Child", "timestamp": TimeUtils.now_ms(), "type": "test"},
		"child_2": {"name": "Second Child", "timestamp": TimeUtils.now_ms() + 1, "type": "test"},
		"child_3": {"name": "Third Child", "timestamp": TimeUtils.now_ms() + 2, "type": "test"}
	}

	# Set test data
	var setup_result: Dictionary = await op_manager.execute(
		"set_value_async", [full_path, test_children]
	)

	if not setup_result.success:
		return _failure("Failed to setup test children")

	# Get children back
	_update_status("Retrieving children list...")
	var get_result: Dictionary = await op_manager.execute("get_value_async", [full_path])

	if get_result.success:
		var children_data: Dictionary = get_result.get("data", {})
		var child_keys: Array = children_data.keys()

		_update_status("Found %d children: %s" % [child_keys.size(), str(child_keys)])

		return _success(
			{
				"operation": "list_children",
				"path": full_path,
				"child_keys": child_keys,
				"child_count": child_keys.size(),
				"children_data": children_data,
				"timestamp": TimeUtils.now_ms()
			}
		)
	else:
		_update_status("Failed to retrieve children: " + get_result.error, true)
		return _failure(get_result.error)
