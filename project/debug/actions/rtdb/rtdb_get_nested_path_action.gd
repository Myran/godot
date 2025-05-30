# project/debug/actions/rtdb/rtdb_get_nested_path_action.gd
@tool
class_name RTDBGetNestedPathAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "Get Nested Path"
	group = "Paths"
	description = "Retrieves data from nested paths in RTDB structure."


func execute() -> void:
	_update_status("Executing " + action_name + "...")
	# First ensure nested data exists
	var db: Object = get_firebase_database()
	if not db:
		var error_result: Array = get_last_error_result()
		execution_completed.emit(
			false,
			error_result[1] if error_result.size() > 1 else {"error": "Database connection failed"}
		)
		return

	var nested_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.NESTED_DATA)

	# Set up nested test data first
	var nested_data: Dictionary = _create_nested_test_data()
	var setup_result: Dictionary = await execute_firebase_operation(
		db, "set_value_async", [nested_path, nested_data]
	)

	if not setup_result.success:
		execution_completed.emit(
			false,
			{
				"error":
				"Failed to setup nested data: " + str(setup_result.get("error", "unknown error"))
			}
		)
		return

	# Now get the nested data
	var result: Array = await execute_simple_operation(
		"get_value_async", nested_path, null, "Get Nested Data"
	)

	# Emit completion signal based on result
	var success: bool = result[0] if result.size() > 0 else false
	var payload: Variant = result[1] if result.size() > 1 else null
	execution_completed.emit(success, payload)


func _create_nested_test_data() -> Dictionary:
	return {
		"metadata":
		{"created_at": TimeUtils.now_ms(), "test_type": "nested_structure", "version": "1.0"},
		"data":
		{
			"user_info": {"name": "Test User", "level": 42, "active": true},
			"settings": {"theme": "dark", "notifications": true, "language": "en"}
		},
		"stats": {"total_tests": 123, "success_rate": 0.95, "last_updated": TimeUtils.now_ms()}
	}
