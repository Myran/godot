class_name RTDBDeleteValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "rtdb.database.remove_value"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var firebase_backend: Object = get_firebase_database()
	if not TestValidation.validate_backend_available(firebase_backend, "Firebase RTDB"):
		return TestUtils.make_failure_result(
			"Firebase backend not available or not initialized",
			TestConstants.ERROR_CODES.BACKEND_NOT_INITIALIZED,
			0,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.RTDB_REMOVE_VALUE)
		)

	var unique_path: Array[Variant] = RTDBTestPaths.with_timestamp(RTDBTestPaths.SIMPLE_VALUE)
	var test_path: Array[Variant] = RTDBTestPaths.to_variant_array(unique_path)
	var test_value: String = TestUtils.make_test_value("RTDB Delete Test")

	# Step 1: Setup test data using timing helper
	var setup_op: Dictionary = await TestUtils.time_operation(
		"rtdb_setup_for_delete",
		func() -> bool:
			return await execute_simple_operation(
				"set_value_async", test_path, test_value, "Setup Delete Test Data"
			)
	)

	if not setup_op.result:
		return TestUtils.make_failure_result(
			"Failed to setup test data for deletion",
			TestConstants.ERROR_CODES.SET_FAILED,
			TestUtils.get_duration_ms(setup_op),
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.RTDB_REMOVE_VALUE)
		)

	# Step 2: Delete the data using timing helper
	var delete_op: Dictionary = await TestUtils.time_operation(
		"rtdb_remove_value",
		func() -> bool:
			return await execute_simple_operation(
				"remove_value_async", test_path, null, action_name
			)
	)

	if not delete_op.result:
		return TestUtils.make_failure_result(
			"Delete operation failed",
			TestConstants.ERROR_CODES.REMOVE_FAILED,
			TestUtils.get_duration_ms(setup_op) + TestUtils.get_duration_ms(delete_op),
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.RTDB_REMOVE_VALUE)
		)

	# Step 3: Validate deletion using timing helper
	var key: String = test_path[-1] if test_path.size() > 0 else ""
	var path: Array[Variant] = test_path.slice(0, -1) if test_path.size() > 1 else []

	var validation_op: Dictionary = await TestUtils.time_operation(
		"rtdb_validate_deletion",
		func() -> Variant: return await firebase_backend.get_data(path, key)
	)

	var total_duration: int = (
		TestUtils.get_duration_ms(setup_op)
		+ TestUtils.get_duration_ms(delete_op)
		+ TestUtils.get_duration_ms(validation_op)
	)

	if validation_op.result == null:
		return TestUtils.make_success_result(
			"Delete validation successful - data confirmed removed",
			total_duration,
			action_name,
			TestUtils.make_metadata(
				TestConstants.TEST_TYPES.RTDB_REMOVE_VALUE,
				{
					"path": test_path,
					"setup_duration_ms": TestUtils.get_duration_ms(setup_op),
					"delete_duration_ms": TestUtils.get_duration_ms(delete_op),
					"validation_duration_ms": TestUtils.get_duration_ms(validation_op),
					"test_value": test_value
				}
			)
		)

	return TestUtils.make_failure_result(
		"Delete validation failed - data still exists",
		TestConstants.ERROR_CODES.VALIDATION_FAILED,
		total_duration,
		action_name,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.RTDB_REMOVE_VALUE,
			{
				"path": test_path,
				"remaining_data": str(validation_op.result),
				"setup_duration_ms": TestUtils.get_duration_ms(setup_op),
				"delete_duration_ms": TestUtils.get_duration_ms(delete_op),
				"validation_duration_ms": TestUtils.get_duration_ms(validation_op)
			}
		)
	)


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
