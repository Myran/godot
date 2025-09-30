class_name RTDBDebugAction
extends DebugAction

static var _next_request_id: int = 1


func _init() -> void:
	category = "RTDB"

	# Use wrapper that emits completion events for sequential processing
	action_callable = Callable(self, "_execute_rtdb_action_with_completion")


func execute_rtdb_action() -> bool:
	# RTDB actions override this method to implement their specific logic
	# This base implementation is for actions that haven't been converted yet
	push_error("execute_rtdb_action() not implemented in " + get_script().get_path())
	_update_status("ERROR: execute_rtdb_action() not implemented", true)
	return false  # Return false to indicate failure


func _execute_rtdb_action_with_completion() -> bool:
	# Wrapper that adds completion event emission for sequential processing
	# Mirrors the pattern from BackendFirebaseDebugAction (lines 198-288)
	Log.info(
		"EXECUTION_PATH_TRACE: _execute_rtdb_action_with_completion called",
		{
			"action": action_name,
			"has_execute_rtdb_action": has_method("execute_rtdb_action"),
			"category": category,
			"group": group,
			"auto_continue": auto_continue
		},
		["debug", "rtdb", "execution_trace"]
	)

	# Call the child class's execute_rtdb_action implementation
	@warning_ignore("redundant_await")
	var success: bool = await execute_rtdb_action()

	Log.info(
		"EXECUTION_PATH_TRACE: execute_rtdb_action returned",
		{"action": action_name, "success": success, "auto_continue": auto_continue},
		["debug", "rtdb", "execution_trace"]
	)

	# Emit unified test reporting (DEBUG_TEST_SUCCESS/FAILURE markers)
	var test_metadata: Dictionary = DebugConfigReader.get_test_metadata()
	var config_test_id: String = test_metadata.get("test_id", "")

	if config_test_id != "":
		if success:
			# Generate DEBUG_TEST_SUCCESS marker for test result collection
			var duration_ms: int = 0  # RTDB actions don't return DebugActionResult yet
			DebugAction._log_test_success(action_name, category, group, duration_ms, {})
		else:
			# Generate DEBUG_TEST_FAILURE marker for consistency
			Log.error(
				"DEBUG_TEST_FAILURE",
				{
					"test_id": config_test_id,
					"action": action_name,
					"category": category,
					"group": group,
					"error_message": "RTDB action returned false"
				},
				["debug", "test", "failure"]
			)

	# CRITICAL: Emit completion event for RTDB actions with auto_continue=false
	# This allows sequential execution without waiting for game state events
	if not auto_continue:
		Log.info(
			"RTDB action completed - emitting completion event",
			{
				"action": action_name,
				"success": success,
				"auto_continue": auto_continue,
				"completion_event": "RTDBCompleteEvent"
			},
			["debug", "rtdb", "completion"]
		)
		core.action(core.RTDBCompleteEvent.new(action_name, success))

	return success


func get_firebase_database() -> Object:
	if not data_source.is_initialized():
		Log.error(
			"DataSource not yet initialized for RTDB operations", {}, ["debug", "rtdb", "error"]
		)
		return null

	var backend: DataBackend = data_source._backend
	if backend:
		if backend is FirebaseServiceBackend:
			Log.debug(
				"Found Firebase backend for RTDB operations",
				{
					"backend_type":
					backend.get_script().get_path() if backend.get_script() else "unknown"
				},
				["debug", "rtdb"]
			)
			return backend

		Log.warning(
			"Backend is not Firebase type",
			{
				"backend_type":
				backend.get_script().get_path() if backend.get_script() else backend.get_class()
			},
			["debug", "rtdb", "warning"]
		)
		return null

	Log.error("Backend is null in DataSource", {}, ["debug", "rtdb", "error"])
	return null


func execute_simple_operation(
	method: String, path_variants: Array, value: Variant, operation_name: String
) -> bool:
	var start_time_ms: int = Time.get_ticks_msec()
	Log.debug(
		"Executing RTDB operation",
		{
			"method": method,
			"path": path_variants,
			"operation": operation_name,
			"has_value": value != null
		},
		["debug", "rtdb"]
	)

	var firebase_backend: Object = get_firebase_database()

	var error_msg: String = ""
	var key: String = ""
	var path: Array[Variant] = []
	var duration_ms: int = 0

	if not firebase_backend:
		error_msg = "Firebase backend not available for " + operation_name
		Log.error(error_msg, {}, ["debug", "rtdb", "error"])
		_update_status("ERROR: " + error_msg, true)
		return false

	if not firebase_backend.is_available():
		error_msg = "Firebase backend not initialized for " + operation_name
		Log.error(error_msg, {}, ["debug", "rtdb", "error"])
		_update_status("ERROR: " + error_msg, true)
		return false

	var result: Variant
	_update_status("Executing " + operation_name + "...")

	match method:
		"get_value_async":
			key = path_variants[-1] if path_variants.size() > 0 else ""
			path = path_variants.slice(0, -1) if path_variants.size() > 1 else []
			result = await firebase_backend.get_data(path, key)

		"set_value_async":
			key = path_variants[-1] if path_variants.size() > 0 else ""
			path = path_variants.slice(0, -1) if path_variants.size() > 1 else []
			result = await firebase_backend.set_data(path, key, value)

		"remove_value_async":
			key = path_variants[-1] if path_variants.size() > 0 else ""
			path = path_variants.slice(0, -1) if path_variants.size() > 1 else []
			result = await firebase_backend.remove_data(path, key)

		"push_value_async":
			result = await firebase_backend.push_data(path_variants, value)

		_:
			duration_ms = Time.get_ticks_msec() - start_time_ms
			error_msg = "Unsupported RTDB method: " + method
			Log.error(
				error_msg,
				{
					"method": method,
					"duration_ms": duration_ms,
					"available_methods":
					["get_value_async", "set_value_async", "remove_value_async", "push_value_async"]
				},
				["debug", "rtdb", "error"]
			)
			_update_status("ERROR: " + error_msg + " (" + str(duration_ms) + "ms)", true)
			return false

	duration_ms = Time.get_ticks_msec() - start_time_ms

	if result != null:
		Log.info(
			"RTDB operation completed successfully",
			{
				"operation": operation_name,
				"method": method,
				"result_type": typeof(result),
				"duration_ms": duration_ms,
				"performance":
				"GOOD" if duration_ms < 500 else ("SLOW" if duration_ms < 2000 else "VERY_SLOW")
			},
			["debug", "rtdb", "success"]
		)
		_update_status(operation_name + " completed successfully (" + str(duration_ms) + "ms)")
		return true

	Log.warning(
		"RTDB operation returned null",
		{"operation": operation_name, "method": method, "duration_ms": duration_ms},
		["debug", "rtdb", "warning"]
	)
	_update_status(operation_name + " completed (null result, " + str(duration_ms) + "ms)")
	return true


func get_last_error_result() -> Array:
	return [false, {"error": "get_last_error_result not implemented"}]


func create_test_path(path_suffix: Array = []) -> Array[Variant]:
	var base_path: Array[Variant] = [
		"debug_tests", "rtdb", str(int(Time.get_unix_time_from_system()))
	]
	base_path.append_array(path_suffix)
	return base_path


func execute_firebase_operation(_db: Object, _operation: String, _args: Array) -> Dictionary:
	push_error("execute_firebase_operation() not implemented in base RTDBDebugAction")
	return {"success": false, "error": "execute_firebase_operation not implemented"}


static func generate_request_id() -> int:
	_next_request_id += 1
	return _next_request_id
