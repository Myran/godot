# project/debug/actions/rtdb/rtdb_list_children_action.gd
@tool
class_name RTDBListChildrenAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "List Children"
	group = "Path Operations"
	description = "Lists all child keys from a specific RTDB path."


func execute() -> void:
	_update_status("Executing " + action_name + "...")

	# Converted from execute_legacy
	var db: Object = get_firebase_database()
	if not db:
		var error_result: Array = get_last_error_result()
		execution_completed.emit(false, error_result[1] if error_result.size() > 1 else {"error": "Database connection failed"})
		return

	var full_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.LIST_CHILDREN)
	var op_manager: FirebaseOperationManager = FirebaseOperationManager.new(db)

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
		execution_completed.emit(false, {"error": "Failed to setup test children"})

	# Get children back
	_update_status("Retrieving children list...")
	var get_result: Dictionary = await op_manager.execute("get_value_async", [full_path])

	if get_result.success:
		var children_data: Dictionary = get_result.get("data") if get_result.has("data") else {}
		var child_keys: Array = children_data.keys()

		_update_status("Found %d children: %s" % [child_keys.size(), str(child_keys)])

		execution_completed.emit(true, {
				"operation": "list_children",
				"path": full_path,
				"child_keys": child_keys,
				"child_count": child_keys.size(),
				"children_data": children_data,
				"timestamp": TimeUtils.now_ms()
			}
		)
	else:
		_update_status(
			"Failed to retrieve children: " + str(get_result.get("error", "unknown error")), true
		)
		execution_completed.emit(false, {"error": str(str(get_result.get("error", "unknown error")))})
