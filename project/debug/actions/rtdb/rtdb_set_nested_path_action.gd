class_name RTDBSetNestedPathAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.paths.set_nested"
	group = "Paths"
	description = "Creates/updates a nested JSON structure at a test path in RTDB."


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var firebase_backend: Object = get_firebase_database()
	if not firebase_backend:
		return TestUtils.make_failure_result(
			"Firebase database not available",
			TestConstants.ERROR_DATABASE_UNAVAILABLE,
			0,
			action_name,
			TestUtils.make_metadata("rtdb_set_nested_path")
		)

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

	var nested_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.NESTED_DATA)

	var set_op: Dictionary = await TestUtils.time_operation(
		"set_nested_operation",
		func() -> bool:
			return await execute_simple_operation(
				"set_value_async", nested_path, nested_data, action_name
			)
	)

	var duration: int = set_op.duration_ms

	if set_op.result:
		return TestUtils.make_success_result(
			"Successfully set nested path data",
			duration,
			action_name,
			TestUtils.make_metadata(
				"rtdb_set_nested_path",
				{
					"path": nested_path,
					"data_structure": nested_data.keys(),
					"data_size_bytes": str(nested_data).length()
				}
			)
		)

	return TestUtils.make_failure_result(
		"Failed to set nested path data",
		TestConstants.ERROR_OPERATION_FAILED,
		duration,
		action_name,
		TestUtils.make_metadata(
			"rtdb_set_nested_path",
			{"path": nested_path, "attempted_data_size_bytes": str(nested_data).length()}
		)
	)


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
