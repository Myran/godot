class_name RTDBGetNestedPathAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.paths.get_nested"
	group = "Paths"
	description = "Retrieves data from nested paths in RTDB structure."


func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()

	var db: Object = get_firebase_database()
	if not db:
		return DebugAction.Result.new_failure(
			"Firebase database not available",
			"DATABASE_UNAVAILABLE",
			DebugAction.Result.ErrorCategory.DATABASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name
		)

	var nested_path: Array[Variant] = RTDBTestPaths.to_variant_array(RTDBTestPaths.NESTED_DATA)
	var nested_data: Dictionary = _create_nested_test_data()

	var setup_start: int = Time.get_ticks_msec()
	var setup_success: bool = await execute_simple_operation(
		"set_value_async", nested_path, nested_data, "Setup Nested Data"
	)
	var setup_duration: int = Time.get_ticks_msec() - setup_start

	if not setup_success:
		return DebugAction.Result.new_failure(
			"Failed to set up nested test data",
			"SETUP_FAILED",
			DebugAction.Result.ErrorCategory.DATABASE,
			null,
			Time.get_ticks_msec() - start_time,
			action_name,
			{
				"test_type": "rtdb_get_nested_path",
				"step": "setup",
				"path": nested_path,
				"setup_duration_ms": setup_duration
			}
		)

	var get_start: int = Time.get_ticks_msec()
	var get_success: bool = await execute_simple_operation(
		"get_value_async", nested_path, null, "Get Nested Data"
	)
	var get_duration: int = Time.get_ticks_msec() - get_start
	var total_duration: int = Time.get_ticks_msec() - start_time

	if get_success:
		return DebugAction.Result.new_success(
			"Successfully retrieved nested path data",
			total_duration,
			action_name,
			{
				"test_type": "rtdb_get_nested_path",
				"path": nested_path,
				"setup_duration_ms": setup_duration,
				"get_duration_ms": get_duration,
				"data_structure": nested_data.keys()
			}
		)

	return DebugAction.Result.new_failure(
		"Failed to retrieve nested path data",
		"GET_OPERATION_FAILED",
		DebugAction.Result.ErrorCategory.DATABASE,
		null,
		total_duration,
		action_name,
		{
			"test_type": "rtdb_get_nested_path",
			"path": nested_path,
			"setup_duration_ms": setup_duration,
			"get_duration_ms": get_duration
		}
	)


func execute_rtdb_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
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
