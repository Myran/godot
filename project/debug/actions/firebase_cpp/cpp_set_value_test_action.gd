class_name CPPSetValueTestAction
extends CPPFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.set_value"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var test_path: Array[String] = TestUtils.make_test_path(
		TestConstants.FIREBASE_CPP_PREFIX, "set_value"
	)
	var test_value: String = TestConstants.test_value("CPP Direct Value")

	# Use simple timing helper for set operation
	var set_op: Dictionary = await TestUtils.time_operation(
		"set_operation",
		func() -> Variant:
			return await execute_cpp_operation(
				TestConstants.FIREBASE_OPERATIONS.SET_VALUE,
				[test_path, test_value],
				TestConstants.operation_description("Set Value"),
				"set_value"
			)
	)

	if TestValidation.validate_firebase_result(set_op.result, "set_value_test"):
		return TestUtils.make_success_result(
			"C++ set value operation successful",
			TestUtils.get_duration_ms(set_op),
			action_name,
			TestUtils.make_metadata(
				TestConstants.TEST_TYPES.CPP_SET_VALUE,
				{
					"path": test_path,
					"set_value": test_value,
					"operation_duration_ms": TestUtils.get_duration_ms(set_op),
					"result": str(set_op.result)
				}
			)
		)

	return TestUtils.make_failure_result(
		"C++ set value operation failed",
		TestConstants.ERROR_CODES.SET_FAILED,
		TestUtils.get_duration_ms(set_op),
		action_name,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.CPP_SET_VALUE,
			{
				"path": test_path,
				"attempted_value": test_value,
				"operation_duration_ms": TestUtils.get_duration_ms(set_op)
			}
		)
	)


func execute_cpp_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
