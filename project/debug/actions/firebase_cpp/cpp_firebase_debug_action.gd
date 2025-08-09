class_name CPPFirebaseDebugAction
extends DebugAction

var cpp_db: Object = null
var cpp_db_instance_id: int = -1


func _init() -> void:
	super._init()
	category = "C++ Firebase"
	action_callable = Callable(self, "_execute_action_logic")


func get_cpp_firebase_database() -> Object:
	if cpp_db != null and is_instance_valid(cpp_db):
		return cpp_db

	Log.debug("Creating direct C++ Firebase instance", {}, ["debug", "cpp_firebase"])

	if not ClassDB.class_exists("FirebaseDatabase"):
		Log.error(
			"FirebaseDatabase C++ class not available", {}, ["debug", "cpp_firebase", "error"]
		)
		return null

	cpp_db = ClassDB.instantiate("FirebaseDatabase")
	if not is_instance_valid(cpp_db):
		Log.error(
			"Failed to instantiate C++ FirebaseDatabase", {}, ["debug", "cpp_firebase", "error"]
		)
		return null

	cpp_db_instance_id = cpp_db.get_instance_id()
	Log.info(
		"C++ Firebase instance created",
		{"cpp_instance_id": cpp_db_instance_id},
		["debug", "cpp_firebase"]
	)
	return cpp_db


func execute_cpp_operation(
	method_name: String, args: Array, operation_name: String = "", operation_type: String = ""
) -> Variant:
	var start_time: int = Time.get_ticks_msec()
	var db: Object = get_cpp_firebase_database()

	if not is_instance_valid(db):
		_update_status("ERROR: C++ Firebase instance not available", true)
		return null

	var op_name: String = operation_name if not operation_name.is_empty() else method_name
	_update_status("🚀 Starting: " + op_name + "...")

	var request_id: int = Time.get_ticks_msec()
	var full_args: Array = [request_id] + args

	var op_data: Dictionary = {
		"operation": method_name,
		"completed": false,
		"result": null,
		"error": null,
		"start_time": start_time,
		"request_id": request_id
	}

	var signal_name: String = method_name.replace("_async", "_completed")
	var signal_string_name: StringName = StringName(signal_name)

	if not db.has_signal(signal_string_name):
		_update_status("ERROR: Signal not found: " + signal_name, true)
		return null

	var handler: Callable = _create_operation_handler(
		op_data, operation_type, request_id, start_time, op_name, method_name
	)
	db.connect(signal_string_name, handler, Object.CONNECT_ONE_SHOT)

	db.callv(method_name, full_args)

	while not op_data.completed:
		await Engine.get_main_loop().process_frame

	var duration: int = Time.get_ticks_msec() - start_time

	if op_data.error != null:
		_update_status("ERROR: " + op_name + " failed: " + str(op_data.error), true)
		return null

	_update_status(op_name + " completed (" + str(duration) + "ms)")
	return op_data.result




func _create_operation_handler(
	op_data: Dictionary,
	operation_type: String,
	request_id: int,
	start_time: int,
	op_name: String,
	method_name: String
) -> Callable:
	match operation_type:
		"get_value":
			return _create_get_value_state_handler(
				op_data, request_id, start_time, op_name, method_name
			)
		"set_value", "remove_value":
			return _create_set_value_state_handler(
				op_data, request_id, start_time, op_name, method_name
			)
		_:
			push_error("Unknown operation type: " + operation_type)
			return func() -> void:
				op_data.completed = true
				op_data.error = "Unknown operation type: " + operation_type


func _create_get_value_state_handler(
	op_data: Dictionary, request_id: int, start_time: int, _op_name: String, method_name: String
) -> Callable:
	return func(recv_request_id: int, rtdb_key: String, value: Variant) -> void:
		if recv_request_id == request_id:
			var duration: int = Time.get_ticks_msec() - start_time
			var success: bool = value != null

			op_data.completed = true
			if success:
				op_data.result = value
				Log.info(
					"C++ get_value operation completed",
					{
						"method": method_name,
						"duration_ms": duration,
						"rtdb_key": rtdb_key,
						"value_type": typeof(value)
					},
					["debug", "cpp_firebase"]
				)
			else:
				op_data.error = "Operation returned null"
				Log.error(
					"C++ get_value operation returned null",
					{"method": method_name, "duration_ms": duration, "rtdb_key": rtdb_key},
					["debug", "cpp_firebase", "error"]
				)


func _create_set_value_state_handler(
	op_data: Dictionary, request_id: int, start_time: int, _op_name: String, method_name: String
) -> Callable:
	return func(recv_request_id: int, success: bool, error_message: String) -> void:
		if recv_request_id == request_id:
			var duration: int = Time.get_ticks_msec() - start_time

			op_data.completed = true
			if success:
				op_data.result = true
				Log.info(
					"C++ set/remove operation completed",
					{"method": method_name, "duration_ms": duration},
					["debug", "cpp_firebase"]
				)
			else:
				op_data.error = error_message
				Log.error(
					"C++ set/remove operation failed",
					{"method": method_name, "duration_ms": duration, "error": error_message},
					["debug", "cpp_firebase", "error"]
				)


func execute_with_state_validation(
	session_id: String = "", sequence: int = -1
) -> DebugAction.Result:
	"""Execute C++ Firebase action with state validation integration"""
	var start_time: int = Time.get_ticks_msec()

	Log.info(
		"Executing C++ Firebase action with state validation",
		{"action_name": action_name, "session_id": session_id, "sequence": sequence},
		["debug", "cpp_firebase", "state_validation"]
	)

	var success: bool = execute_cpp_action()
	var duration: int = Time.get_ticks_msec() - start_time

	if success:
		Log.info(
			"C++ Firebase action completed successfully",
			{"action_name": action_name, "duration_ms": duration},
			["debug", "cpp_firebase", "success"]
		)
		return DebugAction.Result.new_success(
			success, duration, action_name, {"session_id": session_id, "sequence": sequence}
		)
	else:
		Log.error(
			"C++ Firebase action failed",
			{"action_name": action_name, "duration_ms": duration},
			["debug", "cpp_firebase", "error"]
		)
		return DebugAction.Result.new_failure(
			"C++ Firebase action failed",
			"C++_FIREBASE_FAILURE",
			DebugAction.Result.ErrorCategory.FIREBASE,
			null,
			duration,
			action_name,
			{"session_id": session_id, "sequence": sequence}
		)


func _execute_action_logic(_params: Dictionary = {}) -> DebugAction.Result:
	push_error("_execute_action_logic() not implemented in " + get_script().get_path())
	_update_status("ERROR: _execute_action_logic() not implemented", true)
	return DebugAction.Result.new_failure(
		str("_execute_action_logic() not implemented in " + get_script().get_path()),
		"NOT_IMPLEMENTED",
		DebugAction.Result.ErrorCategory.SYSTEM,
		{"error": "missing_implementation"},
		0,
		action_name,
		{}
	)


func execute_cpp_action() -> bool:
	push_error("execute_cpp_action() not implemented in " + get_script().get_path())
	_update_status("ERROR: execute_cpp_action() not implemented", true)
	return false
