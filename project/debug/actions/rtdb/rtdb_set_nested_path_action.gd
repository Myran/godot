# project/debug/actions/rtdb/rtdb_set_nested_path_action.gd
@tool
class_name RTDBSetNestedPathAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Set Nested Path"
	group = "Paths"
	description = "Creates/updates a nested JSON structure at a test path in RTDB."


func execute() -> Array:
	var nested_data: Dictionary = {
		"metadata":
		{"created_at": TimeUtils.now_ms(), "test_type": "nested_structure", "version": "2.0"},
		"data":
		{
			"user_info":
			{"name": "Test User " + str(TimeUtils.now_ms()), "level": 42, "active": true},
			"settings": {"theme": "dark", "notifications": true, "language": "en"}
		},
		"stats": {"total_tests": 456, "success_rate": 0.98, "last_updated": TimeUtils.now_ms()}
	}

	return await execute_simple_operation(
		"set_value_async",
		RTDBTestPaths.to_variant_array(RTDBTestPaths.NESTED_DATA),
		nested_data,
		action_name
	)
