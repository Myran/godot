class_name BackendFirebaseDebugAction
extends DebugAction

var firebase_backend: DataBackend = null  # Changed to support both backend types


func _init() -> void:
	super._init()
	category = "Firebase Backend"
	# CRITICAL FIX: Use _execute_action_logic as action_callable to go through base class properly
	# This prevents recursion and ensures completion events are emitted
	action_callable = Callable(self, "_execute_action_logic")


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
				"actual_backend_type": Utils.get_type(backend_instance),
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
			"backend_type": Utils.get_type(firebase_backend),
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
		{"backend_type": Utils.get_type(backend)},
		["debug", "backend_firebase", "trace"]
	)

	if not backend.is_available():
		Log.error(
			"TRACE: Backend not available (is_available returned false)",
			{"backend_type": Utils.get_type(backend)},
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
	# This base method should never be called - specific actions must override it
	# Return failure to identify inheritance issues quickly
	var error_message: String = (
		"CRITICAL: Base _execute_action_logic() called - this method MUST be overridden by specific Firebase actions.\n"
		+ "Action: "
		+ str(action_name)
		+ "\n"
		+ "Script: "
		+ str(get_script().get_path())
		+ "\n"
		+ "This indicates a broken inheritance pattern causing missing completion events."
	)

	Log.error(error_message, {}, ["debug", "backend_firebase", "inheritance_error"])

	return DebugActionResult.new_failure(
		error_message,
		"INHERITANCE_ERROR",
		DebugActionResult.ErrorCategory.SYSTEM,
		{"action": action_name, "script_path": get_script().get_path()},
		0,
		action_name
	)
