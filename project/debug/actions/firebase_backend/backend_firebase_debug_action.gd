class_name BackendFirebaseDebugAction
extends DebugAction

var firebase_backend: FirebaseBackend = null


func _init() -> void:
	super._init()
	category = "Firebase Backend"
	action_callable = Callable(self, "execute_backend_action")


func get_firebase_backend_for_testing() -> FirebaseBackend:
	if firebase_backend != null and is_instance_valid(firebase_backend):
		return firebase_backend

	if not data_source:
		Log.error(
			"DataSource singleton not available for backend testing",
			{},
			["debug", "backend_firebase", "error"]
		)
		return null

	if not data_source.is_initialized():
		Log.error(
			"DataSource not yet initialized for backend testing",
			{},
			["debug", "backend_firebase", "error"]
		)
		return null

	var backend_instance: FirebaseBackend = data_source._backend
	if backend_instance and is_instance_valid(backend_instance):
		firebase_backend = backend_instance
		Log.debug(
			"Firebase backend acquired for testing",
			{"backend_type": firebase_backend.get_script().get_path()},
			["debug", "backend_firebase"]
		)
		return firebase_backend

	Log.error(
		"Backend is not Firebase type or is null",
		{"backend_type": backend_instance.get_class() if backend_instance else "null"},
		["debug", "backend_firebase", "error"]
	)
	return null


func test_backend_async_pattern(
	method_name: String,
	path: Array,
	key: String,
	value: Variant = null,
	operation_name: String = ""
) -> bool:
	var start_time: int = Time.get_ticks_msec()
	var backend: FirebaseBackend = get_firebase_backend_for_testing()

	if not backend:
		_update_status("ERROR: Backend not available", true)
		return false

	if not backend.is_available():
		_update_status("ERROR: Backend not initialized", true)
		return false

	var op_name: String = operation_name if not operation_name.is_empty() else method_name
	_update_status("Testing backend " + op_name + "...")

	var result: Variant

	match method_name:
		"get_data":
			@warning_ignore("redundant_await")
			result = await backend.get_data(path, key)
		"set_data":
			@warning_ignore("redundant_await")
			result = await backend.set_data(path, key, value)
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


func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	var error_message: String = (
		"_execute_action_logic() not implemented in " + get_script().get_path()
	)
	push_error(error_message)
	_update_status("ERROR: _execute_action_logic() not implemented", true)

	return DebugAction.Result.new_failure(
		error_message,
		"NOT_IMPLEMENTED",
		DebugAction.Result.ErrorCategory.SYSTEM,
		{"script_path": get_script().get_path()},
		0,
		action_name
	)


func execute_backend_action() -> bool:
	if has_method("_execute_action_logic"):
		@warning_ignore("redundant_await")
		var result: DebugAction.Result = await _execute_action_logic({})
		return result.is_success()

	push_error("execute_backend_action() not implemented in " + get_script().get_path())
	_update_status("ERROR: execute_backend_action() not implemented", true)
	return false
