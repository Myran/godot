# project/debug/actions/firebase_backend/backend_firebase_debug_action.gd
@tool
class_name BackendFirebaseDebugAction
extends DebugAction

# Firebase backend instance (wrapped, not direct C++)
var firebase_backend: FirebaseBackend = null

func _init() -> void:
	super._init()
	category = "Firebase Backend"
	action_callable = Callable(self, "execute_backend_action")

# Get Firebase backend instance through DataSource - follow RTDB pattern
func get_firebase_backend_for_testing() -> FirebaseBackend:
	if firebase_backend != null and is_instance_valid(firebase_backend):
		return firebase_backend
	
	if not data_source:
		Log.error("DataSource singleton not available for backend testing", {}, ["debug", "backend_firebase", "error"])
		return null
	
	if not data_source.is_initialized():
		Log.error("DataSource not yet initialized for backend testing", {}, ["debug", "backend_firebase", "error"])
		return null
	
	var backend: Variant = data_source._backend
	if backend and backend is FirebaseBackend:
		firebase_backend = backend as FirebaseBackend
		Log.debug("Firebase backend acquired for testing", 
			{"backend_type": firebase_backend.get_script().get_path()}, 
			["debug", "backend_firebase"])
		return firebase_backend
	else:
		Log.error("Backend is not Firebase type or is null", 
			{"backend_type": backend.get_class() if backend else "null"}, 
			["debug", "backend_firebase", "error"])
		return null

# Simplified backend async test - follow RTDB pattern
func test_backend_async_pattern(method_name: String, path: Array, key: String, value: Variant = null, operation_name: String = "") -> bool:
	var start_time = Time.get_ticks_msec()
	var backend = get_firebase_backend_for_testing()
	
	if not backend:
		_update_status("ERROR: Backend not available", true)
		return false
	
	if not backend.is_available():
		_update_status("ERROR: Backend not initialized", true)
		return false
	
	var op_name = operation_name if not operation_name.is_empty() else method_name
	_update_status("Testing backend " + op_name + "...")
	
	var result: Variant
	
	# Call backend method based on method name
	match method_name:
		"get_data":
			result = await backend.get_data(path, key)
		"set_data":
			result = await backend.set_data(path, key, value)
		"remove_data":
			result = await backend.remove_data(path, key)
		"push_data":
			result = await backend.push_data(path, value)
		_:
			_update_status("ERROR: Unsupported backend method: " + method_name, true)
			return false
	
	var duration_ms = Time.get_ticks_msec() - start_time
	var success = result != null
	
	if success:
		Log.info("Backend async pattern test successful", 
			{"method": method_name, "duration_ms": duration_ms}, 
			["debug", "backend_firebase"])
		_update_status(op_name + " completed (" + str(duration_ms) + "ms)")
	else:
		Log.error("Backend async pattern test failed", 
			{"method": method_name, "duration_ms": duration_ms}, 
			["debug", "backend_firebase", "error"])
		_update_status("ERROR: " + op_name + " failed (" + str(duration_ms) + "ms)", true)
	
	return success

# Default implementation - subclasses override this
func execute_backend_action() -> bool:
	push_error("execute_backend_action() not implemented in " + get_script().get_path())
	_update_status("ERROR: execute_backend_action() not implemented", true)
	execution_completed.emit(false, {"error": "Not implemented"})
	return false
