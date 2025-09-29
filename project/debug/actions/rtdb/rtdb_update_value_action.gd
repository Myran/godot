class_name RTDBUpdateValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "rtdb.database.update_value"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var firebase_backend: Object = get_firebase_database()
	if not firebase_backend:
		return TestUtils.make_failure_result(
			"Firebase database not available",
			TestConstants.ERROR_DATABASE_UNAVAILABLE,
			0,
			action_name,
			TestUtils.make_metadata("rtdb_update_value")
		)

	var path_suffix: Array[Variant] = ["update_test"]
	var test_path: Array[Variant] = create_test_path(path_suffix)
	var test_value: String = TestConstants.test_value("Updated Value")

	var update_op: Dictionary = await TestUtils.time_operation(
		"update_operation",
		func() -> bool:
			return await execute_simple_operation(
				"set_value_async", test_path, test_value, action_name
			)
	)

	var duration: int = update_op.duration_ms

	if update_op.result:
		return TestUtils.make_success_result(
			"Successfully updated value",
			duration,
			action_name,
			TestUtils.make_metadata(
				"rtdb_update_value", {"path": test_path, "updated_value": test_value}
			)
		)

	return TestUtils.make_failure_result(
		"Failed to update value",
		TestConstants.ERROR_OPERATION_FAILED,
		duration,
		action_name,
		TestUtils.make_metadata(
			"rtdb_update_value", {"path": test_path, "attempted_value": test_value}
		)
	)


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
