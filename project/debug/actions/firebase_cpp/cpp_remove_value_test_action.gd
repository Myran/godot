class_name CPPRemoveValueTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.remove_value"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var test_path: Array[String] = TestUtils.make_test_path(
		TestConstants.FIREBASE_CPP_PREFIX, "remove_value"
	)
	var test_value: String = TestConstants.test_value("CPP Remove Test Value")

	# Use simple timing helper for set operation (setup for remove test)
	var set_op: Dictionary = await TestUtils.time_operation(
		"set_operation",
		func() -> Variant:
			return await execute_cpp_operation(
				TestConstants.FIREBASE_OPERATIONS.SET_VALUE,
				[test_path, test_value],
				TestConstants.operation_description("Set", "for Remove test"),
				"set_value"
			)
	)

	if not TestValidation.validate_firebase_result(set_op.result, "set_for_remove_test"):
		return TestUtils.make_failure_result(
			"Failed to set test value for C++ remove operation",
			TestConstants.ERROR_CODES.SET_FAILED,
			TestUtils.get_duration_ms(set_op),
			action_name,
			TestUtils.make_metadata(
				TestConstants.TEST_TYPES.CPP_REMOVE_VALUE,
				{
					"step": "setup",
					"path": test_path,
					"set_duration_ms": TestUtils.get_duration_ms(set_op)
				}
			)
		)

	# Use simple timing helper for remove operation
	var remove_op: Dictionary = await TestUtils.time_operation(
		"remove_operation",
		func() -> Variant:
			return await execute_cpp_operation(
				TestConstants.FIREBASE_OPERATIONS.REMOVE_VALUE,
				[test_path],
				TestConstants.operation_description("Remove Value"),
				"remove_value"
			)
	)

	var total_duration: int = (
		TestUtils.get_duration_ms(set_op) + TestUtils.get_duration_ms(remove_op)
	)

	if TestValidation.validate_firebase_result(remove_op.result, "remove_value_test"):
		return TestUtils.make_success_result(
			"C++ remove value operation successful",
			total_duration,
			action_name,
			TestUtils.make_metadata(
				TestConstants.TEST_TYPES.CPP_REMOVE_VALUE,
				{
					"path": test_path,
					"set_duration_ms": TestUtils.get_duration_ms(set_op),
					"remove_duration_ms": TestUtils.get_duration_ms(remove_op),
					"test_value": test_value,
					"remove_result": str(remove_op.result)
				}
			)
		)

	return TestUtils.make_failure_result(
		"C++ remove value operation failed",
		TestConstants.ERROR_CODES.REMOVE_FAILED,
		total_duration,
		action_name,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.CPP_REMOVE_VALUE,
			{
				"path": test_path,
				"set_duration_ms": TestUtils.get_duration_ms(set_op),
				"remove_duration_ms": TestUtils.get_duration_ms(remove_op),
				"test_value": test_value
			}
		)
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
