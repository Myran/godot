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
	if not data_source:
		Log.error(
			"DataSource singleton not available for Firebase backend testing",
			{},
			["debug", "backend_firebase", "error"]
		)
		return null

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
	operation_name: String = ""
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
	var success: bool = result != null

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
	if has_method("_execute_action_logic"):
		@warning_ignore("redundant_await")
		var result: DebugActionResult = await _execute_action_logic({})

		# Add null safety check for stronger typing enforcement
		if result == null:
			Log.error(
				"_execute_action_logic returned null - action failed",
				{"action": action_name},
				["debug", "backend_firebase", "error"]
			)
			_update_status("ERROR: Action returned null result", true)
			return false

		return result.is_success()

	push_error("execute_backend_action() not implemented in " + get_script().get_path())
	_update_status("ERROR: execute_backend_action() not implemented", true)
	return false
