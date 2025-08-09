class_name FirebaseOperationManager
extends RefCounted

signal operation_completed(request_id: int, success: bool, data: Variant)

var _db: Object
var _pending_ops: Dictionary = {}


func _init(firebase_db: Object) -> void:
	assert(
		is_instance_valid(firebase_db), "FirebaseOperationManager requires valid database instance"
	)
	_db = firebase_db
	_connect_signals()


func execute(operation: String, args: Array, timeout_sec: float = 10.0) -> DebugAction.Result:
	var request_id: int = RTDBDebugAction.generate_request_id()

	var op_data: Dictionary = {
		"operation": operation,
		"completed": false,
		"result": null,
		"error": null,
		"start_time": TimeUtils.now_ms()
	}
	_pending_ops[request_id] = op_data

	var executed: bool = await _execute_operation(request_id, operation, args)
	if not executed:
		_pending_ops.erase(request_id)
		return DebugAction.Result.new_failure(
			"Unknown operation: " + operation,
			"UNKNOWN_OPERATION",
			DebugAction.Result.ErrorCategory.VALIDATION,
			null,
			0,
			operation
		)

	var result: DebugAction.Result = await _wait_for_completion(request_id, timeout_sec)
	_pending_ops.erase(request_id)

	return result


func _execute_operation(request_id: int, operation: String, args: Array) -> bool:
	match operation:
		"get_value_async":
			var path: Array = args[0] if args.size() > 0 else []
			var key: Variant = args[1] if args.size() > 1 else ""
			var result: Variant = await _db.get_data(path, key)
			_simulate_async_completion.call_deferred(request_id, "get", result, "")
			return true
		"set_value_async":
			var path: Array = args[0] if args.size() > 0 else []
			var key: Variant = args[1] if args.size() > 1 else ""
			var data: Variant = args[2] if args.size() > 2 else null
			var result: Variant = await _db.set_data(path, key, data)
			_simulate_async_completion.call_deferred(request_id, "set", result, "")
			return true
		"remove_value_async":
			var path: Array = args[0] if args.size() > 0 else []
			var key: Variant = args[1] if args.size() > 1 else ""
			var result: Variant = await _db.remove_data(path, key)
			_simulate_async_completion.call_deferred(request_id, "remove", result, "")
			return true
		_:
			return false


func _simulate_async_completion(
	request_id: int, operation_type: String, result: Variant, error: String
) -> void:
	await Engine.get_main_loop().process_frame

	if error != null and error != "":
		match operation_type:
			"get":
				_on_get_error(request_id, "", "API_ERROR", error)
			"set", "remove":
				_on_set_completed(request_id, false, error)
	else:
		match operation_type:
			"get":
				_on_get_completed(request_id, "", result)
			"set", "remove":
				_on_set_completed(request_id, true, "")


func _wait_for_completion(request_id: int, timeout_sec: float) -> DebugAction.Result:
	var deadline: int = TimeUtils.deadline_ms(timeout_sec)

	var operation_str: String = ""
	var start_time_variant: Variant = null
	var start_time_int: int = 0
	var duration_ms: int = 0

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
			operation_str = str(operation_variant)
			start_time_variant = timeout_op_data.get("start_time")
			start_time_int = start_time_variant
			duration_ms = TimeUtils.elapsed_ms(start_time_int)
			return DebugAction.Result.new_timeout(
				duration_ms, operation_str, "Operation timed out after %.1f seconds" % timeout_sec
			)

	if not _pending_ops.has(request_id):
		return DebugAction.Result.new_failure(
			"Operation data lost", "DATA_LOST", DebugAction.Result.ErrorCategory.SYSTEM
		)

	var op_data: Dictionary = _pending_ops[request_id]
	var error_variant: Variant = op_data.get("error")
	var has_error: bool = error_variant != null

	operation_str = str(op_data.get("operation", "Unknown"))
	start_time_variant = op_data.get("start_time")
	start_time_int = start_time_variant
	duration_ms = TimeUtils.elapsed_ms(start_time_int)

	if has_error:
		var error_str: String = str(error_variant)
		var result_variant: Variant = op_data.get("result")
		return DebugAction.Result.new_failure(
			error_str,
			"OPERATION_ERROR",
			DebugAction.Result.ErrorCategory.FIREBASE,
			result_variant,
			duration_ms,
			operation_str
		)
	else:
		var result_variant: Variant = op_data.get("result")
		return DebugAction.Result.new_success(result_variant, duration_ms, operation_str)


func _connect_signals() -> void:
	if not is_instance_valid(_db):
		return

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
