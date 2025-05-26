# project/debug/actions/rtdb/rtdb_get_nested_path_action.gd
@tool
class_name RTDBGetNestedPathAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Get Nested Path"
	group = "Paths"
	description = "Retrieves data from nested paths in RTDB structure."


func execute() -> Array:
	# First ensure nested data exists
	var db: Object = get_firebase_database()
	if not db:
		return get_last_error_result()

	var nested_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.NESTED_DATA)

	# Set up nested test data first
	var nested_data: Dictionary = _create_nested_test_data()
	var setup_result: Dictionary = await execute_firebase_operation(
		db, "set_value_async", [nested_path, nested_data]
	)

	if not setup_result.success:
		return _failure(
			"Failed to setup nested data: " + str(setup_result.get("error", "unknown error"))
		)

	# Now get the nested data
	return await execute_simple_operation("get_value_async", nested_path, null, "Get Nested Data")


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
