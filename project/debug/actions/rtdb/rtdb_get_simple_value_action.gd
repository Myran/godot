func execute_rtdb_action() -> void:
	_update_status("Executing " + action_name + "...")

	var path: RTDBTestPaths.Path = RTDBTestPaths.create_path(RTDBTestPaths.SIMPLE_VALUE)
	var result: Array = await execute_simple_operation(
		"get_value_async", path.as_variants(), null, action_name
	)

	# Emit completion signal based on result
	var success: bool = result[0] if result.size() > 0 else false
	var payload: Variant = result[1] if result.size() > 1 else null
	execution_completed.emit(success, payload)
