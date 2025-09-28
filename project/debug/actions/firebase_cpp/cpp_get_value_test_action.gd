class_name CPPGetValueTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.get_value"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var test_path: Array[String] = TestUtils.make_test_path(
		TestConstants.FIREBASE_CPP_PREFIX, "get_value"
	)
	var test_value: String = TestConstants.test_value("CPP Get Test Value")

	# Use simple timing helper for set operation
	var set_op: Dictionary = await TestUtils.time_operation(
		"set_operation",
		func() -> Variant:
			return await execute_cpp_operation(
				TestConstants.FIREBASE_OPERATIONS.SET_VALUE,
				[test_path, test_value],
				TestConstants.operation_description("Set", "for Get test"),
				"set_value"
			)
	)

	if not TestValidation.validate_firebase_result(set_op.result, "set_for_get_test"):
		return TestUtils.make_failure_result(
			"Failed to set test value for C++ get operation",
			TestConstants.ERROR_CODES.SET_FAILED,
			TestUtils.get_duration_ms(set_op),
			action_name,
			TestUtils.make_metadata(
				TestConstants.TEST_TYPES.CPP_GET_VALUE,
				{
					"step": "setup",
					"path": test_path,
					"set_duration_ms": TestUtils.get_duration_ms(set_op)
				}
			)
		)

	# Use simple timing helper for get operation
	var get_op: Dictionary = await TestUtils.time_operation(
		"get_operation",
		func() -> Variant:
			return await execute_cpp_operation(
				TestConstants.FIREBASE_OPERATIONS.GET_VALUE,
				[test_path],
				TestConstants.operation_description("Get Value"),
				"get_value"
			)
	)

	var total_duration: int = TestUtils.get_duration_ms(set_op) + TestUtils.get_duration_ms(get_op)

	if TestValidation.validate_firebase_result(get_op.result, "get_test"):
		return TestUtils.make_success_result(
			"C++ get value operation successful",
			total_duration,
			action_name,
			TestUtils.make_metadata(
				TestConstants.TEST_TYPES.CPP_GET_VALUE,
				{
					"path": test_path,
					"set_duration_ms": TestUtils.get_duration_ms(set_op),
					"get_duration_ms": TestUtils.get_duration_ms(get_op),
					"test_value": test_value,
					"retrieved_result": str(get_op.result)
				}
			)
		)

	return TestUtils.make_failure_result(
		"C++ get value operation failed",
		TestConstants.ERROR_CODES.GET_FAILED,
		total_duration,
		action_name,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.CPP_GET_VALUE,
			{
				"path": test_path,
				"set_duration_ms": TestUtils.get_duration_ms(set_op),
				"get_duration_ms": TestUtils.get_duration_ms(get_op),
				"test_value": test_value
			}
		)
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
