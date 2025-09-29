class_name RTDBSetSimpleValueAction
extends RTDBDebugAction


func _init() -> void:
	super._init()
	action_name = "rtdb.database.set_value"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var test_value: String = _params.get("value_to_set", TestUtils.make_test_value("RTDB Set Test"))

	var firebase_backend: Object = get_firebase_database()
	if not TestValidation.validate_backend_available(firebase_backend, "Firebase RTDB"):
		return TestUtils.make_failure_result(
			"Firebase backend not available or not initialized",
			TestConstants.ERROR_CODES.BACKEND_NOT_INITIALIZED,
			0,
			action_name,
			TestUtils.make_metadata(TestConstants.TEST_TYPES.RTDB_SET_SIMPLE)
		)

	var path_variants: Array = RTDBTestPaths.to_variant_array(RTDBTestPaths.SIMPLE_VALUE)
	var key: String = path_variants[-1] if path_variants.size() > 0 else ""
	var path: Array[Variant] = path_variants.slice(0, -1) if path_variants.size() > 1 else []

	# Use timing helper for the set operation
	var set_op: Dictionary = await TestUtils.time_operation(
		"rtdb_set_simple_value",
		func() -> bool: return await firebase_backend.set_data(path, key, test_value)
	)

	var total_duration: int = TestUtils.get_duration_ms(set_op)

	if set_op.result:
		return TestUtils.make_success_result(
			"Successfully set value at simple path",
			total_duration,
			action_name,
			TestUtils.make_metadata(
				TestConstants.TEST_TYPES.RTDB_SET_SIMPLE,
				{
					"value_set": test_value,
					"path": path_variants,
					"operation_duration_ms": total_duration
				}
			)
		)

	return TestUtils.make_failure_result(
		"Set operation failed",
		TestConstants.ERROR_CODES.SET_FAILED,
		total_duration,
		action_name,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.RTDB_SET_SIMPLE,
			{
				"attempted_value": test_value,
				"path": path_variants,
				"operation_duration_ms": total_duration
			}
		)
	)


func execute_rtdb_action() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()
