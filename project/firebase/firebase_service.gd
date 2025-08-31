extends Node

signal firebase_initialized
signal firebase_error(error: String)

var _cpp_database: Object
var db: FirebaseDatabaseWrapper  # Use same wrapper as old backend
var _pending_requests: Dictionary = {}
var _next_request_id: int = 1
var _is_initialized: bool = false


func _ready() -> void:
	_initialize_firebase()


func _initialize_firebase() -> void:
	# Check if the FirebaseDatabase C++ class exists first (same as original backend)
	if not ClassDB.class_exists("FirebaseDatabase"):
		Log.error(
			"FirebaseDatabase C++ module class not available. Cannot initialize Firebase service.",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		firebase_error.emit("FirebaseDatabase C++ module class not available")
		return

	# Use the same method as the original Firebase backend
	var cpp_db_instance: Object = ClassDB.instantiate("FirebaseDatabase")

	if not is_instance_valid(cpp_db_instance):
		Log.error(
			"Failed to instantiate FirebaseDatabase C++ module",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		firebase_error.emit("Failed to instantiate FirebaseDatabase C++ module")
		return

	# Create Firebase database wrapper
	db = FirebaseDatabaseWrapper.new(cpp_db_instance)
	_cpp_database = cpp_db_instance  # Keep for backward compatibility
	Log.debug(
		"FirebaseDatabase wrapper created",
		{"db_instance_id": db.get_cpp_instance_id()},
		[Log.TAG_FIREBASE]
	)

	_connect_cpp_signals()
	_is_initialized = true
	Log.info("Firebase service initialized successfully", {}, [Log.TAG_FIREBASE])
	firebase_initialized.emit()


func is_available() -> bool:
	return _is_initialized and db != null and db.is_valid()


func get_value(path: Array[Variant], key: String = "") -> FirebaseRequest:
	if not is_available():
		var error_request: FirebaseRequest = FirebaseRequest.new(-1)
		error_request.complete_with_error(
			"SERVICE_UNAVAILABLE", "Firebase service is not available"
		)
		return error_request

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	var full_path: Array[Variant] = path.duplicate()
	if not key.is_empty():
		full_path.append(key)

	# Use Firebase C++ method call
	db.call_method("get_value_async", [request_id, full_path])
	return request


func set_value(path: Array[Variant], key: String, value: Variant) -> FirebaseRequest:
	if not is_available():
		var error_request: FirebaseRequest = FirebaseRequest.new(-1)
		error_request.complete_with_error(
			"SERVICE_UNAVAILABLE", "Firebase service is not available"
		)
		return error_request

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	var full_path: Array[Variant] = path.duplicate()
	if not key.is_empty():
		full_path.append(key)

	# Use Firebase C++ method call
	db.call_method("set_value_async", [request_id, full_path, value])
	return request


func push_data(path: Array[Variant], data: Variant) -> FirebaseRequest:
	if not is_available():
		var error_request: FirebaseRequest = FirebaseRequest.new(-1)
		error_request.complete_with_error(
			"SERVICE_UNAVAILABLE", "Firebase service is not available"
		)
		return error_request

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	# Use Firebase C++ method call
	db.call_method("push_and_update_async", [request_id, path, data])
	return request


func remove_value(path: Array[Variant], key: String = "") -> FirebaseRequest:
	if not is_available():
		var error_request: FirebaseRequest = FirebaseRequest.new(-1)
		error_request.complete_with_error(
			"SERVICE_UNAVAILABLE", "Firebase service is not available"
		)
		return error_request

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	var full_path: Array[Variant] = path.duplicate()
	if not key.is_empty():
		full_path.append(key)

	# Use Firebase C++ method call
	db.call_method("remove_value_async", [request_id, full_path])
	return request


func run_transaction(path: Array[Variant], increment_by: int = 1) -> FirebaseRequest:
	if not is_available():
		var error_request: FirebaseRequest = FirebaseRequest.new(-1)
		error_request.complete_with_error(
			"SERVICE_UNAVAILABLE", "Firebase service is not available"
		)
		return error_request

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	# Use Firebase C++ method call
	db.call_method("run_transaction_async", [request_id, path, increment_by])
	return request


func set_server_timestamp(path: Array[Variant]) -> FirebaseRequest:
	if not is_available():
		var error_request: FirebaseRequest = FirebaseRequest.new(-1)
		error_request.complete_with_error(
			"SERVICE_UNAVAILABLE", "Firebase service is not available"
		)
		return error_request

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	# Use Firebase C++ method call
	db.call_method("set_server_timestamp_async", [request_id, path])
	return request


func start_listening(path: Array[Variant]) -> void:
	if not is_available():
		return

	# Use Firebase C++ method call
	db.call_method("add_listener_at_path", [path])


func query_data(path: Array[Variant], query_params: Dictionary) -> FirebaseRequest:
	if not is_available():
		var error_request: FirebaseRequest = FirebaseRequest.new(-1)
		error_request.complete_with_error(
			"SERVICE_UNAVAILABLE", "Firebase service is not available"
		)
		return error_request

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	# Use Firebase C++ method call
	db.call_method("query_ordered_data_async", [request_id, path, query_params])
	return request


func stop_listening(path: Array[Variant]) -> void:
	if not is_available():
		return

	# Use Firebase C++ method call
	db.call_method("remove_listener_at_path", [path])


func _get_next_request_id() -> int:
	var id: int = _next_request_id
	_next_request_id += 1
	return id


func _resolve_pending_request(request_id: int, result: Dictionary) -> void:
	if request_id in _pending_requests:
		var request: FirebaseRequest = _pending_requests[request_id]
		_pending_requests.erase(request_id)

		if result.status == "ok":
			request.complete_with_success(result.payload)
		else:
			request.complete_with_error(
				str(result.get("code", "UNKNOWN_ERROR")),
				str(result.get("message", "Unknown error occurred"))
			)


func _connect_cpp_signals() -> void:
	var signals_to_connect: Dictionary = {
		"get_value_completed": _on_get_value_completed,
		"get_value_error": _on_get_value_error,
		"set_value_completed": _on_set_value_completed,
		"push_and_update_completed": _on_push_and_update_completed,
		"remove_value_completed": _on_remove_value_completed,
		"query_completed": _on_query_completed,
		"query_error": _on_query_error,
		"transaction_completed": _on_transaction_completed,
		"set_server_timestamp_completed": _on_server_timestamp_completed,
	}

	for signal_name: String in signals_to_connect:
		var handler: Callable = signals_to_connect[signal_name]
		var err: int = db.connect_signal(signal_name, handler, CONNECT_DEFERRED)
		if err != OK:
			Log.error(
				"Failed to connect C++ signal",
				{"signal": signal_name, "error": error_string(err as Error)},
				[Log.TAG_FIREBASE]
			)


func _on_get_value_completed(req_id: int, _key: String, value: Variant) -> void:
	_resolve_pending_request(req_id, {"status": "ok", "payload": value})


func _on_get_value_error(req_id: int, _key: String, code: String, msg: String) -> void:
	_resolve_pending_request(req_id, {"status": "error", "code": code, "message": msg})


func _on_set_value_completed(req_id: int, success: bool, error_msg: String) -> void:
	var payload: Dictionary = (
		{"status": "ok", "payload": success}
		if success
		else {"status": "error", "code": "SET_FAILED", "message": error_msg}
	)
	_resolve_pending_request(req_id, payload)


func _on_push_and_update_completed(
	req_id: int, push_id: String, success: bool, error_msg: String
) -> void:
	var payload: Dictionary = (
		{"status": "ok", "payload": push_id}
		if success
		else {"status": "error", "code": "PUSH_FAILED", "message": error_msg}
	)
	_resolve_pending_request(req_id, payload)


func _on_remove_value_completed(req_id: int, success: bool, error_msg: String) -> void:
	var payload: Dictionary = (
		{"status": "ok", "payload": success}
		if success
		else {"status": "error", "code": "REMOVE_FAILED", "message": error_msg}
	)
	_resolve_pending_request(req_id, payload)


func _on_query_completed(req_id: int, _key: String, value: Variant) -> void:
	_resolve_pending_request(req_id, {"status": "ok", "payload": value})


func _on_query_error(req_id: int, _key: String, code: String, msg: String) -> void:
	_resolve_pending_request(req_id, {"status": "error", "code": code, "message": msg})


func _on_transaction_completed(
	req_id: int, _key: String, value: Variant, success: bool, error_msg: String
) -> void:
	var payload: Dictionary = (
		{"status": "ok", "payload": value}
		if success
		else {"status": "error", "code": "TRANSACTION_FAILED", "message": error_msg}
	)
	_resolve_pending_request(req_id, payload)


func _on_server_timestamp_completed(req_id: int, success: bool, error_msg: String) -> void:
	var payload: Dictionary = (
		{"status": "ok", "payload": success}
		if success
		else {"status": "error", "code": "TIMESTAMP_FAILED", "message": error_msg}
	)
	_resolve_pending_request(req_id, payload)


# FirebaseDatabaseWrapper - Wraps Firebase C++ instance for GDScript
class FirebaseDatabaseWrapper:
	var _cpp_instance: Object
	var _instance_id: int

	func _init(cpp_db_instance: Object) -> void:
		_cpp_instance = cpp_db_instance
		_instance_id = cpp_db_instance.get_instance_id()

	func is_valid() -> bool:
		return is_instance_valid(_cpp_instance)

	func get_cpp_instance_id() -> int:
		return _instance_id

	func connect_signal(signal_name: String, callable: Callable, flags: int = 0) -> Error:
		if not is_valid():
			return ERR_INVALID_DATA
		return _cpp_instance.connect(signal_name, callable, flags)

	func is_signal_connected(signal_name: String, callable: Callable) -> bool:
		return is_valid() and _cpp_instance.is_connected(signal_name, callable)

	func call_method(method_name: String, args: Array) -> Variant:
		if not is_valid():
			return null
		return _cpp_instance.callv(method_name, args)
