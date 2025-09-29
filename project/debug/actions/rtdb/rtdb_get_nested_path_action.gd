class_name RTDBGetNestedPathAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.paths.get_nested"
	group = "Paths"
	description = "Retrieves data from nested paths in RTDB structure."


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var db: Object = get_firebase_database()
	if not db:
		return TestUtils.make_failure_result(
			"Firebase database not available",
			TestConstants.ERROR_DATABASE_UNAVAILABLE,
			0,
			action_name,
			TestUtils.make_metadata("rtdb_get_nested_path")
		)

	var nested_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.NESTED_DATA)
	var nested_data: Dictionary = _create_nested_test_data()

	var setup_op: Dictionary = await TestUtils.time_operation(
		"setup_nested_operation",
		func() -> bool:
			return await execute_simple_operation(
				"set_value_async", nested_path, nested_data, "Setup Nested Data"
			)
	)

	var setup_duration: int = setup_op.duration_ms

	if not setup_op.result:
		return TestUtils.make_failure_result(
			"Failed to set up nested test data",
			TestConstants.ERROR_SETUP_FAILED,
			setup_duration,
			action_name,
			TestUtils.make_metadata("rtdb_get_nested_path", {"step": "setup", "path": nested_path})
		)

	var get_op: Dictionary = await TestUtils.time_operation(
		"get_nested_operation",
		func() -> bool:
			return await execute_simple_operation(
				"get_value_async", nested_path, null, "Get Nested Data"
			)
	)

	var get_duration: int = get_op.duration_ms
	var total_duration: int = setup_duration + get_duration

	if get_op.result:
		return TestUtils.make_success_result(
			"Successfully retrieved nested path data",
			total_duration,
			action_name,
			TestUtils.make_metadata(
				"rtdb_get_nested_path",
				{
					"path": nested_path,
					"setup_duration_ms": setup_duration,
					"get_duration_ms": get_duration,
					"data_structure": nested_data.keys()
				}
			)
		)

	return TestUtils.make_failure_result(
		"Failed to retrieve nested path data",
		TestConstants.ERROR_OPERATION_FAILED,
		total_duration,
		action_name,
		TestUtils.make_metadata(
			"rtdb_get_nested_path",
			{
				"path": nested_path,
				"setup_duration_ms": setup_duration,
				"get_duration_ms": get_duration
			}
		)
	)


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()


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
