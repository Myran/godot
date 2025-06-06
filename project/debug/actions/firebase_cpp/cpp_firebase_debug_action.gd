# project/debug/actions/firebase_cpp/cpp_firebase_debug_action.gd
@tool
class_name CPPFirebaseDebugAction
extends DebugAction

# Direct C++ Firebase database instance (NOT wrapped)
var cpp_db: Object = null
var cpp_db_instance_id: int = -1

func _init() -> void:
	super._init()
	category = "C++ Firebase"
	action_callable = Callable(self, "execute_cpp_action")

# Initialize direct C++ Firebase instance
func get_cpp_firebase_database() -> Object:
	if cpp_db != null and is_instance_valid(cpp_db):
		return cpp_db
	
	Log.debug("Creating direct C++ Firebase instance", {}, ["debug", "cpp_firebase"])
	
	if not ClassDB.class_exists("FirebaseDatabase"):
		Log.error("FirebaseDatabase C++ class not available", {}, ["debug", "cpp_firebase", "error"])
		return null
	
	cpp_db = ClassDB.instantiate("FirebaseDatabase")
	if not is_instance_valid(cpp_db):
		Log.error("Failed to instantiate C++ FirebaseDatabase", {}, ["debug", "cpp_firebase", "error"])
		return null
	
	cpp_db_instance_id = cpp_db.get_instance_id()
	Log.info("C++ Firebase instance created", {"cpp_instance_id": cpp_db_instance_id}, ["debug", "cpp_firebase"])
	return cpp_db

# Simplified C++ operation - follow RTDB pattern
func execute_cpp_operation(method_name: String, args: Array, operation_name: String = "") -> Variant:
	var start_time = Time.get_ticks_msec()
	var db = get_cpp_firebase_database()
	
	if not is_instance_valid(db):
		_update_status("ERROR: C++ Firebase instance not available", true)
		return null
	
	var op_name = operation_name if not operation_name.is_empty() else method_name
	_update_status("Executing C++ " + op_name + "...")
	
	# Generate unique request ID
	var request_id = Time.get_ticks_msec()
	var full_args = [request_id] + args
	
	# Connect to completion signal for this request
	var signal_name = method_name.replace("_async", "_completed")
	var handler = func(recv_request_id: int, success: bool, data: Variant):
		if recv_request_id == request_id:
			var duration = Time.get_ticks_msec() - start_time
			if success:
				Log.info("C++ operation completed", {"method": method_name, "duration_ms": duration}, ["debug", "cpp_firebase"])
				_update_status(op_name + " completed (" + str(duration) + "ms)")
			else:
				Log.error("C++ operation failed", {"method": method_name, "error": data}, ["debug", "cpp_firebase", "error"])
				_update_status("ERROR: " + op_name + " failed", true)
	
	# Connect signal temporarily
	if db.has_signal(signal_name):
		db.connect(signal_name, handler, CONNECT_ONE_SHOT)
	
	# Call C++ method
	db.callv(method_name, full_args)
	
	# Wait briefly for response (simplified)
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().create_timer(1.0).timeout
	
	var duration = Time.get_ticks_msec() - start_time
	_update_status(op_name + " completed (" + str(duration) + "ms)")
	return true

# Class-level variables for signal handling
var _operation_result: Dictionary = {}
var _operation_completed: bool = false
var _operation_start_time: float = 0.0
var _operation_name: String = ""

# Execute C++ operation with timeout handling
func execute_cpp_operation_with_timeout(method_name: String, args: Array, timeout: float, operation_name: String = "") -> Dictionary:
	_operation_start_time = Time.get_ticks_msec()
	var db: Object = get_cpp_firebase_database()
	
	if not is_instance_valid(db):
		var error_result: Dictionary = {
			"status": "error",
			"code": "DB_UNAVAILABLE", 
			"message": "C++ Firebase instance not available",
			"duration_ms": Time.get_ticks_msec() - _operation_start_time
		}
		_update_status("ERROR: C++ Firebase instance not available", true)
		return error_result
	
	_operation_name = operation_name if not operation_name.is_empty() else method_name
	_update_status("Executing C++ " + _operation_name + " with timeout...")
	
	# Reset state
	_operation_result = {}
	_operation_completed = false
	
	# Generate unique request ID
	var request_id: int = Time.get_ticks_msec()
	var full_args: Array = [request_id] + args
	
	# Connect to completion signal for this request
	var signal_name: String = method_name.replace("_async", "_completed")
	
	# Use method-based handler instead of lambda
	if db.has_signal(signal_name):
		db.connect(signal_name, _on_cpp_operation_completed.bind(request_id, method_name), CONNECT_ONE_SHOT)
	
	# Call C++ method
	db.callv(method_name, full_args)
	
	# Wait for completion or timeout
	var timeout_ms: float = timeout * 1000.0
	var elapsed: float = 0.0
	
	while not _operation_completed and elapsed < timeout_ms:
		await Engine.get_main_loop().process_frame
		elapsed = Time.get_ticks_msec() - _operation_start_time
	
	# Handle timeout
	if not _operation_completed:
		_operation_result = {
			"status": "error",
			"code": "TIMEOUT",
			"message": "Operation timed out after " + str(timeout) + " seconds",
			"duration_ms": elapsed
		}
		_update_status("ERROR: " + _operation_name + " timed out", true)
	
	var duration: float = Time.get_ticks_msec() - _operation_start_time
	_update_status(_operation_name + " completed (" + str(duration) + "ms)")
	return _operation_result

# Signal handler for C++ operation completion
func _on_cpp_operation_completed(expected_request_id: int, method_name: String, recv_request_id: int, success: bool, data: Variant) -> void:
	if recv_request_id == expected_request_id and not _operation_completed:
		_operation_completed = true
		var duration: float = Time.get_ticks_msec() - _operation_start_time
		if success:
			_operation_result = {
				"status": "success",
				"result": data,
				"duration_ms": duration
			}
			Log.info("C++ operation completed", {"method": method_name, "duration_ms": duration}, ["debug", "cpp_firebase"])
			_update_status(_operation_name + " completed (" + str(duration) + "ms)")
		else:
			_operation_result = {
				"status": "error", 
				"code": "CPP_ERROR",
				"message": str(data),
				"result": data,
				"duration_ms": duration
			}
			Log.error("C++ operation failed", {"method": method_name, "error": data}, ["debug", "cpp_firebase", "error"])
			_update_status("ERROR: " + _operation_name + " failed", true)


# Default implementation - subclasses override this
func execute_cpp_action() -> bool:
	push_error("execute_cpp_action() not implemented in " + get_script().get_path())
	_update_status("ERROR: execute_cpp_action() not implemented", true)
	execution_completed.emit(false, {"error": "Not implemented"})
	return false
