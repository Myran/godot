class_name RTDBListChildrenAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.children.list"
	group = "Path Operations"
	description = "Lists all child keys from a specific RTDB path."


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")

	var full_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.LIST_CHILDREN)

	_update_status("Setting up test children...")

	var test_children: Dictionary = {
		"child_1": {"name": "First Child", "timestamp": TimeUtils.now_ms(), "type": "test"},
		"child_2": {"name": "Second Child", "timestamp": TimeUtils.now_ms() + 1, "type": "test"},
		"child_3": {"name": "Third Child", "timestamp": TimeUtils.now_ms() + 2, "type": "test"}
	}

	var setup_success: bool = await execute_simple_operation(
		"set_value_async", full_path, test_children, "Setup Test Children"
	)

	if not setup_success:
		return false

	_update_status("Retrieving children list...")
	var get_success: bool = await execute_simple_operation(
		"get_value_async", full_path, null, "Get Children List"
	)

	return get_success
