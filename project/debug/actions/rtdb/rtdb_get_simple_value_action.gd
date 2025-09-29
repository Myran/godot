class_name RTDBGetSimpleValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "rtdb.database.get_value"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var firebase_backend: Object = get_firebase_database()
	if not TestValidation.validate_backend_available(firebase_backend, "Firebase RTDB"):
		return TestUtils.make_failure_result(
			"Firebase backend not available or not initialized",
			TestConstants.ERROR_CODES.BACKEND_NOT_INITIALIZED,
			0,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.RTDB_GET_SIMPLE)
		)

	var path: RTDBTestPaths.Path = RTDBTestPaths.create_path(RTDBTestPaths.SIMPLE_VALUE)
	var test_path_variants: Array = path.as_variants()

	# Use timing helper for the get operation
	var get_op: Dictionary = await TestUtils.time_operation(
		"rtdb_get_simple_value",
		func() -> bool:
			return await execute_simple_operation(
				"get_value_async", test_path_variants, null, action_name
			)
	)

	var total_duration: int = TestUtils.get_duration_ms(get_op)

	if get_op.result:
		return TestUtils.make_success_result(
			"Successfully retrieved value from simple path",
			total_duration,
			action_name,
			TestUtils.make_metadata(
				TestConstants.TEST_TYPES.RTDB_GET_SIMPLE,
				{"path": test_path_variants, "operation_duration_ms": total_duration}
			)
		)

	return TestUtils.make_failure_result(
		"Failed to retrieve value from simple path",
		TestConstants.ERROR_CODES.GET_FAILED,
		total_duration,
		action_name,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.RTDB_GET_SIMPLE,
			{"path": test_path_variants, "operation_duration_ms": total_duration}
		)
	)


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
