class_name BackendFirebaseDebugAction
extends DebugAction

var firebase_backend: DataBackend = null  # Changed to support both backend types


func _init() -> void:
	super._init()
	category = "Firebase Backend"
	action_callable = Callable(self, "execute_backend_action")


func get_firebase_backend_for_testing() -> DataBackend:
	if firebase_backend != null and is_instance_valid(firebase_backend):
		return firebase_backend

	# Only use the backend from DataSource - never create alternate instances

	if not data_source.is_initialized():
		Log.error(
			"DataSource not initialized for Firebase backend testing",
			{},
			["debug", "backend_firebase", "error"]
		)
		return null

	var backend_instance: DataBackend = data_source._backend
	if not backend_instance:
		Log.error("DataSource has no backend instance", {}, ["debug", "backend_firebase", "error"])
		return null

	if not (backend_instance is FirebaseServiceBackend):
		Log.error(
			"DataSource backend is not FirebaseServiceBackend",
			{
				"actual_backend_type": backend_instance.get_class(),
				"script_path":
				(
					backend_instance.get_script().get_path()
					if backend_instance.get_script()
					else "unknown"
				)
			},
			["debug", "backend_firebase", "error"]
		)
		return null

	firebase_backend = backend_instance
	Log.debug(
		"Firebase backend acquired from DataSource",
		{
			"backend_type": firebase_backend.get_class(),
			"script_path": firebase_backend.get_script().get_path(),
			"is_available": firebase_backend.is_available()
		},
		["debug", "backend_firebase"]
	)
	return firebase_backend


func test_backend_async_pattern(
	method_name: String,
	path: Array[Variant],
	key: String,
	value: Variant = null,
	operation_name: String = "",
	expect_error: bool = false
) -> bool:
	Log.info(
		"TRACE: test_backend_async_pattern called",
		{"method": method_name, "operation": operation_name},
		["debug", "backend_firebase", "trace"]
	)

	var start_time: int = Time.get_ticks_msec()

	Log.debug(
		"TRACE: About to call get_firebase_backend_for_testing",
		{},
		["debug", "backend_firebase", "trace"]
	)

	var backend: DataBackend = get_firebase_backend_for_testing()

	if not backend:
		Log.error(
			"TRACE: Backend not available from get_firebase_backend_for_testing",
			{},
			["debug", "backend_firebase", "trace"]
		)
		_update_status("ERROR: Backend not available", true)
		return false

	Log.debug(
		"TRACE: Backend obtained, checking is_available()",
		{"backend_type": backend.get_class()},
		["debug", "backend_firebase", "trace"]
	)

	if not backend.is_available():
		Log.error(
			"TRACE: Backend not available (is_available returned false)",
			{"backend_type": backend.get_class()},
			["debug", "backend_firebase", "trace"]
		)
		_update_status("ERROR: Backend not initialized", true)
		return false

	var op_name: String = operation_name if not operation_name.is_empty() else method_name
	_update_status("Testing backend " + op_name + "...")

	var result: Variant

	Log.debug(
		"TRACE: About to call backend method",
		{
			"method": method_name,
			"path": path,
			"key": key,
			"backend_available": backend.is_available() if backend else false
		},
		["debug", "backend_firebase", "trace"]
	)

	match method_name:
		"get_data":
			@warning_ignore("redundant_await")
			result = await backend.get_data(path, key)
		"set_data":
			@warning_ignore("redundant_await")
			result = await backend.set_data(path, key, value)
			Log.debug(
				"TRACE: backend.set_data returned",
				{"method": method_name, "result": result, "result_type": typeof(result)},
				["debug", "backend_firebase", "trace"]
			)
		"remove_data":
			@warning_ignore("redundant_await")
			result = await backend.remove_data(path, key)
		"push_data":
			@warning_ignore("redundant_await")
			result = await backend.push_data(path, value)
		_:
			_update_status("ERROR: Unsupported backend method: " + method_name, true)
			return false

	var duration_ms: int = Time.get_ticks_msec() - start_time
	var success: bool

	if expect_error:
		# For error handling tests, null/false results indicate graceful error handling
		success = result == null or result == false
	else:
		# For normal tests, non-null results indicate success
		success = result != null

	# NOTE: Firebase C++ SDK resource protection should be handled at service level
	# See: firebase_rate_limiter.gd and firebase_service.gd for proper resource management
	# Test code should not contain Firebase-specific delays (architectural separation)

	if success:
		Log.info(
			"Backend async pattern test successful",
			{"method": method_name, "duration_ms": duration_ms},
			["debug", "backend_firebase"]
		)
		_update_status(op_name + " completed (" + str(duration_ms) + "ms)")
	else:
		Log.error(
			"Backend async pattern test failed",
			{"method": method_name, "duration_ms": duration_ms},
			["debug", "backend_firebase", "error"]
		)
		_update_status("ERROR: " + op_name + " failed (" + str(duration_ms) + "ms)", true)

	return success


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var error_message: String = (
		"_execute_action_logic() not implemented in " + get_script().get_path()
	)
	push_error(error_message)
	_update_status("ERROR: _execute_action_logic() not implemented", true)

	return DebugActionResult.new_failure(
		error_message,
		"NOT_IMPLEMENTED",
		DebugActionResult.ErrorCategory.SYSTEM,
		{"script_path": get_script().get_path()},
		0,
		action_name
	)


func execute_backend_action() -> bool:
	# TRACE: Add comprehensive logging to understand execution path
	Log.info(
		"EXECUTION_PATH_TRACE: execute_backend_action called",
		{
			"action": action_name,
			"has_execute_action_logic": has_method("_execute_action_logic"),
			"action_callable": str(action_callable),
			"category": category,
			"group": group
		},
		["debug", "backend_firebase", "execution_trace"]
	)

	if has_method("_execute_action_logic"):
		Log.info(
			"EXECUTION_PATH_TRACE: About to call _execute_action_logic",
			{"action": action_name},
			["debug", "backend_firebase", "execution_trace"]
		)

		@warning_ignore("redundant_await")
		var result: DebugActionResult = await _execute_action_logic({})

		Log.info(
			"EXECUTION_PATH_TRACE: _execute_action_logic returned",
			{
				"action": action_name,
				"result_null": result == null,
				"result_success": result.is_success() if result else false
			},
			["debug", "backend_firebase", "execution_trace"]
		)

		# Add null safety check for stronger typing enforcement
		if result == null:
			Log.error(
				"_execute_action_logic returned null - action failed",
				{"action": action_name},
				["debug", "backend_firebase", "error"]
			)
			_update_status("ERROR: Action returned null result", true)
			return false

		var success: bool = result.is_success()

		# UNIFIED TEST REPORTING: Add missing DEBUG_TEST_SUCCESS logging
		# This ensures Firebase backend actions are properly collected in test results
		var duration_ms: int = result.duration_ms if result else 0
		var test_metadata: Dictionary = DebugConfigReader.get_test_metadata()
		var config_test_id: String = test_metadata.get("test_id", "")

		if config_test_id != "":
			if success:
				# Generate DEBUG_TEST_SUCCESS marker (was missing in Firebase backend actions)
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
						"duration_ms": duration_ms,
						"error_message": result.error_message if result else "Unknown error"
					},
					["debug", "test", "failure"]
				)

		# Note: Completion event emission now handled by DebugAction base class
		# Base class emits SequentialActionCompleteEvent for all actions with auto_continue=false
		return success

	push_error("execute_backend_action() not implemented in " + get_script().get_path())
	_update_status("ERROR: execute_backend_action() not implemented", true)
	return false
