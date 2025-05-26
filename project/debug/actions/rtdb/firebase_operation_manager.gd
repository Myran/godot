@tool
class_name FirebaseOperationManager
extends RefCounted
## Manages Firebase operations with proper signal handling and timeout management.
## This class encapsulates the complexity of async Firebase operations.

signal operation_completed(request_id: int, success: bool, data: Variant)

var _db: Object
var _pending_ops: Dictionary = {}


func _init(firebase_db: Object) -> void:
	assert(
		is_instance_valid(firebase_db), "FirebaseOperationManager requires valid database instance"
	)
	_db = firebase_db
	_connect_signals()


func execute(operation: String, args: Array, timeout_sec: float = 10.0) -> Dictionary:
	var request_id: int = RTDBDebugAction.generate_request_id()

	var op_data: Dictionary = {
		"operation": operation,
		"completed": false,
		"result": null,
		"error": null,
		"start_time": TimeUtils.now_ms()
	}
	_pending_ops[request_id] = op_data

	# Execute operation
	var executed: bool = _execute_operation(request_id, operation, args)
	if not executed:
		_pending_ops.erase(request_id)
		return {"success": false, "error": "Unknown operation: " + operation}

	# Wait for completion
	var result: Dictionary = await _wait_for_completion(request_id, timeout_sec)
	_pending_ops.erase(request_id)

	return result


func _execute_operation(request_id: int, operation: String, args: Array) -> bool:
	match operation:
		"get_value_async":
			_db.get_value_async(request_id, args[0])
			return true
		"set_value_async":
			_db.set_value_async(request_id, args[0], args[1])
			return true
		"remove_value_async":
			_db.remove_value_async(request_id, args[0])
			return true
		_:
			return false


func _wait_for_completion(request_id: int, timeout_sec: float) -> Dictionary:
	var deadline: int = TimeUtils.deadline_ms(timeout_sec)

	while _pending_ops.has(request_id):
		var op_data_check: Dictionary = _pending_ops[request_id]
		var completed_variant: Variant = op_data_check.get("completed")
		var completed_bool: bool = completed_variant
		if completed_bool:
			break

		await Engine.get_main_loop().process_frame

		if TimeUtils.is_past_deadline(deadline):
			var timeout_op_data: Dictionary = _pending_ops[request_id]
			var operation_variant: Variant = timeout_op_data.get("operation")
			var operation_str: String = str(operation_variant)
			var start_time_variant: Variant = timeout_op_data.get("start_time")
			var start_time_int: int = start_time_variant
			return {
				"success": false,
				"error": "Operation timed out after %.1f seconds" % timeout_sec,
				"operation": operation_str,
				"duration_ms": TimeUtils.elapsed_ms(start_time_int)
			}

	if not _pending_ops.has(request_id):
		return {"success": false, "error": "Operation data lost"}

	var op_data: Dictionary = _pending_ops[request_id]
	var error_variant: Variant = op_data.get("error")
	var has_error: bool = error_variant != null

	if has_error:
		var error_str: String = str(error_variant)
		var result_variant: Variant = op_data.get("result")
		var start_time_variant: Variant = op_data.get("start_time")
		var start_time_int: int = start_time_variant
		return {
			"success": false,
			"error": error_str,
			"data": result_variant,
			"duration_ms": TimeUtils.elapsed_ms(start_time_int)
		}
	else:
		var result_variant: Variant = op_data.get("result")
		var start_time_variant: Variant = op_data.get("start_time")
		var start_time_int: int = start_time_variant
		return {
			"success": true,
			"data": result_variant,
			"duration_ms": TimeUtils.elapsed_ms(start_time_int)
		}


func _connect_signals() -> void:
	if not is_instance_valid(_db):
		return

	# Connect to completion signals
	if _db.has_signal("get_value_completed"):
		_db.get_value_completed.connect(_on_get_completed)
	if _db.has_signal("get_value_error"):
		_db.get_value_error.connect(_on_get_error)
	if _db.has_signal("set_value_completed"):
		_db.set_value_completed.connect(_on_set_completed)
	if _db.has_signal("remove_value_completed"):
		_db.remove_value_completed.connect(_on_remove_completed)
	if _db.has_signal("db_error"):
		_db.db_error.connect(_on_general_error)


## Signal handlers
func _on_get_completed(request_id: int, rtdb_key: String, value: Variant) -> void:
	if _pending_ops.has(request_id):
		var op_data: Dictionary = _pending_ops[request_id]
		op_data["completed"] = true
		op_data["result"] = value
		op_data["key"] = rtdb_key
		_pending_ops[request_id] = op_data
		operation_completed.emit(request_id, true, value)


func _on_get_error(
	request_id: int, rtdb_key: String, error_code: String, error_message: String
) -> void:
	if _pending_ops.has(request_id):
		var op_data: Dictionary = _pending_ops[request_id]
		op_data["completed"] = true
		op_data["error"] = error_message
		op_data["error_code"] = error_code
		op_data["key"] = rtdb_key
		_pending_ops[request_id] = op_data
		operation_completed.emit(request_id, false, error_message)


func _on_set_completed(request_id: int, success: bool, error_message: String) -> void:
	if _pending_ops.has(request_id):
		var op_data: Dictionary = _pending_ops[request_id]
		op_data["completed"] = true
		op_data["result"] = success
		if not success:
			op_data["error"] = error_message
		_pending_ops[request_id] = op_data
		operation_completed.emit(request_id, success, null)


func _on_remove_completed(request_id: int, success: bool, error_message: String) -> void:
	if _pending_ops.has(request_id):
		var op_data: Dictionary = _pending_ops[request_id]
		op_data["completed"] = true
		op_data["result"] = success
		if not success:
			op_data["error"] = error_message
		_pending_ops[request_id] = op_data
		operation_completed.emit(request_id, success, null)


func _on_general_error(request_id: int, error_code: int, error_message: String) -> void:
	if _pending_ops.has(request_id):
		var op_data: Dictionary = _pending_ops[request_id]
		op_data["completed"] = true
		var formatted_error: String = "Error %d: %s" % [error_code, error_message]
		op_data["error"] = formatted_error
		_pending_ops[request_id] = op_data
		operation_completed.emit(request_id, false, error_message)
