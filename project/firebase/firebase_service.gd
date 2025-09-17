extends Node

signal firebase_initialized
signal firebase_error(error: String)

var db: Object  # FirebaseDatabaseWrapper instance (using Object to avoid forward reference)
var _cpp_database: Object
var _is_initialized: bool = false
var _next_request_id: int = 1
var _pending_requests: Dictionary = {}
var _rate_limiter: RefCounted


func _ready() -> void:
	# Wrap in try-catch to prevent autoload crashes
	if Log == null:
		print("ERROR: Log not available in FirebaseService _ready()")
		return

	# Initialize rate limiter
	var firebase_rate_limiter_script: GDScript = load("res://firebase/firebase_rate_limiter.gd")
	_rate_limiter = firebase_rate_limiter_script.new()

	Log.info(
		"FirebaseService _ready() called - using LAZY INITIALIZATION",
		{"platform": OS.get_name(), "node_name": name},
		[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)
	# NOTE: Firebase will be initialized on first use instead of immediately


func _initialize_firebase() -> void:
	Log.debug(
		"Firebase service initialization started",
		{"platform": OS.get_name(), "time": Time.get_ticks_msec()},
		[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)

	# Step 1: Check if the FirebaseDatabase C++ class exists
	Log.debug("Step 1: Checking ClassDB.class_exists('FirebaseDatabase')", {}, [Log.TAG_FIREBASE])
	if not ClassDB.class_exists("FirebaseDatabase"):
		Log.error(
			"INITIALIZATION FAILED: FirebaseDatabase C++ module class not available",
			{"platform": OS.get_name()},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, Log.TAG_INITIALIZATION]
		)
		firebase_error.emit("FirebaseDatabase C++ module class not available")
		return

	Log.info("Step 1 SUCCESS: FirebaseDatabase class found in ClassDB", {}, [Log.TAG_FIREBASE])

	# Step 2: Instantiate the FirebaseDatabase C++ module
	Log.debug("Step 2: Attempting ClassDB.instantiate('FirebaseDatabase')", {}, [Log.TAG_FIREBASE])
	var cpp_db_instance: Object = ClassDB.instantiate("FirebaseDatabase")

	if not is_instance_valid(cpp_db_instance):
		Log.error(
			"INITIALIZATION FAILED: Failed to instantiate FirebaseDatabase C++ module",
			{
				"platform": OS.get_name(),
				"instance_valid": is_instance_valid(cpp_db_instance),
				"instance_value": cpp_db_instance
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, Log.TAG_INITIALIZATION]
		)
		firebase_error.emit("Failed to instantiate FirebaseDatabase C++ module")
		return

	Log.info(
		"Step 2 SUCCESS: FirebaseDatabase C++ instance created",
		{"instance_id": cpp_db_instance.get_instance_id()},
		[Log.TAG_FIREBASE]
	)

	# Step 3: Create Firebase database wrapper
	Log.debug("Step 3: Creating FirebaseDatabaseWrapper", {}, [Log.TAG_FIREBASE])
	db = FirebaseDatabaseWrapper.new(cpp_db_instance) as FirebaseDatabaseWrapper
	_cpp_database = cpp_db_instance  # Keep for backward compatibility

	if not is_instance_valid(db):
		Log.error(
			"INITIALIZATION FAILED: FirebaseDatabaseWrapper creation failed",
			{
				"db_valid": is_instance_valid(db),
				"cpp_instance_valid": is_instance_valid(cpp_db_instance)
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, Log.TAG_INITIALIZATION]
		)
		firebase_error.emit("FirebaseDatabaseWrapper creation failed")
		return

	Log.info(
		"Step 3 SUCCESS: FirebaseDatabaseWrapper created",
		{"db_instance_id": db.get_cpp_instance_id(), "wrapper_valid": db.is_valid()},
		[Log.TAG_FIREBASE]
	)

	# Step 4: Connect C++ signals
	Log.debug("Step 4: Connecting C++ signals", {}, [Log.TAG_FIREBASE])
	var signal_connect_result: bool = _connect_cpp_signals()
	if not signal_connect_result:
		Log.error(
			"INITIALIZATION FAILED: Signal connection failed",
			{"cpp_instance_valid": is_instance_valid(cpp_db_instance)},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, Log.TAG_INITIALIZATION]
		)
		firebase_error.emit("Signal connection failed")
		return

	Log.info("Step 4 SUCCESS: C++ signals connected", {}, [Log.TAG_FIREBASE])

	# Step 5: Mark as initialized and emit success signal
	_is_initialized = true
	Log.info(
		"INITIALIZATION COMPLETE: Firebase service initialized successfully",
		{
			"platform": OS.get_name(),
			"total_time_ms": Time.get_ticks_msec(),
			"is_available": is_available()
		},
		[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)
	firebase_initialized.emit()


func is_available() -> bool:
	# Lazy initialization - initialize on first availability check if not already done
	if not _is_initialized:
		Log.info(
			"LAZY INITIALIZATION: Initializing Firebase on first use",
			{"platform": OS.get_name()},
			[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
		)
		_initialize_firebase()

	return _is_initialized and db != null and db.is_valid()


func get_database_wrapper() -> Object:
	if not is_available():
		return null
	return db


func get_value(path: Array[Variant], key: String = "") -> FirebaseRequest:
	if not is_available():
		var error_request: FirebaseRequest = FirebaseRequest.new(-1)
		error_request.complete_with_error(
			"SERVICE_UNAVAILABLE", "Firebase service is not available"
		)
		return error_request

	# Path validation to prevent Firebase C++ SDK crashes
	var full_path: Array[Variant] = path.duplicate()
	if not key.is_empty():
		full_path.append(key)

	# Validate path before passing to Firebase C++ SDK
	if full_path.is_empty():
		Log.debug(
			"FirebaseService: Invalid empty path detected, returning null gracefully",
			{"original_path": path, "key": key},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		var error_request: FirebaseRequest = FirebaseRequest.new(-1)
		error_request.complete_with_success(null)  # Return null for invalid paths
		return error_request

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

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

	Log.debug(
		"Added request to pending requests",
		{
			"request_id": request_id,
			"request_valid": is_instance_valid(request),
			"pending_count": _pending_requests.size()
		},
		[Log.TAG_FIREBASE, "signal_debug"]
	)

	var full_path: Array[Variant] = path.duplicate()
	if not key.is_empty():
		full_path.append(key)

	# Use Firebase C++ method call
	Log.debug(
		"About to call db.call_method set_value_async",
		{
			"request_id": request_id,
			"db_valid": db != null and db.is_valid(),
			"path": full_path,
			"value": value
		},
		[Log.TAG_FIREBASE, Log.TAG_DEBUG]
	)
	db.call_method("set_value_async", [request_id, full_path, value])
	Log.debug(
		"set_value_async call completed",
		{"request_id": request_id},
		[Log.TAG_FIREBASE, Log.TAG_DEBUG]
	)
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

	# Apply Firebase C++ SDK rate limiting to prevent resource exhaustion
	var rate_limit_info: Dictionary = _rate_limiter.should_rate_limit()
	if rate_limit_info.should_limit:
		Log.debug(
			"Firebase operation rate limited",
			{"delay_ms": rate_limit_info.delay_ms, "reason": rate_limit_info.reason, "path": path},
			[Log.TAG_FIREBASE, "rate_limiter"]
		)
		await _rate_limiter.apply_rate_limit(rate_limit_info.delay_ms, rate_limit_info.reason)

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	# Record operation start for rate limiting
	_rate_limiter.record_operation_start()

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


func _resolve_pending_request(request_id: int, result: Variant) -> void:
	Log.debug(
		"_resolve_pending_request called",
		{
			"request_id": request_id,
			"result_status": result.get("status", "unknown"),
			"pending_requests": _pending_requests.keys(),
			"request_in_pending": request_id in _pending_requests
		},
		[Log.TAG_FIREBASE, "signal_debug"]
	)

	if request_id in _pending_requests:
		var request: FirebaseRequest = _pending_requests[request_id]
		_pending_requests.erase(request_id)

		Log.debug(
			"Found pending request, processing completion",
			{
				"request_id": request_id,
				"request_valid": is_instance_valid(request),
				"result_status": result.status
			},
			[Log.TAG_FIREBASE, "signal_debug"]
		)

		var success: bool = result.status == "ok"
		var duration_ms: int = 0
		if request.has_method("get_duration_ms"):
			duration_ms = request.get_duration_ms()

		# Record operation completion for rate limiting
		_rate_limiter.record_operation_complete(success, duration_ms)

		if success:
			Log.debug(
				"Completing request with success",
				{"request_id": request_id, "payload": result.payload},
				[Log.TAG_FIREBASE, Log.TAG_DEBUG]
			)
			request.complete_with_success(result.payload)
		else:
			Log.debug(
				"Completing request with error",
				{"request_id": request_id, "error": result},
				[Log.TAG_FIREBASE, Log.TAG_DEBUG]
			)
			request.complete_with_error(
				str(result.get("code", "UNKNOWN_ERROR")),
				str(result.get("message", "Unknown error occurred"))
			)
	else:
		Log.warning(
			"Received completion for unknown request",
			{"request_id": request_id, "pending_requests": _pending_requests.keys()},
			[Log.TAG_FIREBASE, Log.TAG_DEBUG]
		)


func cleanup_timed_out_request(request_id: int) -> void:
	"""Remove timed-out requests from pending dictionary to prevent memory leaks.
	Called by FirebaseRequest when timeout occurs but C++ SDK fails to emit callback."""

	if request_id in _pending_requests:
		_pending_requests.erase(request_id)

		# Record timeout as failure for rate limiting
		_rate_limiter.record_operation_complete(false, 45000)  # 45s timeout duration

		Log.warning(
			"Cleaned up timed-out Firebase request to prevent memory leak",
			{
				"request_id": request_id,
				"remaining_pending": _pending_requests.size(),
				"pending_requests": _pending_requests.keys()
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)


func get_rate_limiter_status() -> Dictionary:
	"""Get current Firebase rate limiter status for monitoring and debugging."""
	if _rate_limiter != null:
		return _rate_limiter.get_status()
	return {"error": "rate_limiter_not_initialized"}


func _connect_cpp_signals() -> bool:
	var signals_to_connect: Dictionary[String, Callable] = {
		"get_value_completed": _on_get_value_completed,
		"get_value_error": _on_get_value_error,
		"set_value_completed": _on_set_value_completed,
		"push_and_update_completed": _on_push_and_update_completed,
		"remove_value_completed": _on_remove_value_completed,
		"query_completed": _on_query_completed,
		"query_error": _on_query_error,
		"transaction_completed": _on_transaction_completed,
	}

	var failed_signals: Array[String] = []
	var connected_count: int = 0

	for signal_name: String in signals_to_connect:
		var handler: Callable = signals_to_connect[signal_name]
		var err: int = db.connect_signal(signal_name, handler, CONNECT_DEFERRED)
		if err != OK:
			Log.error(
				"Failed to connect C++ signal",
				{"signal": signal_name, "error": error_string(err as Error)},
				[Log.TAG_FIREBASE, Log.TAG_ERROR, Log.TAG_INITIALIZATION]
			)
			failed_signals.append(signal_name)
		else:
			connected_count += 1
			Log.debug(
				"Successfully connected C++ signal", {"signal": signal_name}, [Log.TAG_FIREBASE]
			)

	var total_signals: int = signals_to_connect.size()
	var success: bool = failed_signals.size() == 0

	Log.info(
		"C++ signal connection complete",
		{
			"connected": connected_count,
			"total": total_signals,
			"failed": failed_signals.size(),
			"success": success
		},
		[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)

	return success


func _on_get_value_completed(req_id: int, _key: String, value: Variant) -> void:
	var payload: Dictionary = {"status": "ok", "payload": value}
	_resolve_pending_request(req_id, payload)


func _on_get_value_error(req_id: int, _key: String, code: int, msg: String) -> void:
	var payload: Dictionary = {"status": "error", "code": code, "message": msg}
	_resolve_pending_request(req_id, payload)


func _on_set_value_completed(req_id: int, success: bool, error_msg: String) -> void:
	Log.debug(
		"_on_set_value_completed called",
		{
			"request_id": req_id,
			"success": success,
			"error_msg": error_msg,
			"pending_requests": _pending_requests.keys()
		},
		[Log.TAG_FIREBASE, "signal_debug"]
	)

	var payload: Dictionary
	if success:
		payload = {"status": "ok", "payload": success}
	else:
		payload = {"status": "error", "code": "SET_FAILED", "message": error_msg}

	Log.debug(
		"About to call _resolve_pending_request",
		{"request_id": req_id, "payload": payload, "payload_valid": payload != null},
		[Log.TAG_FIREBASE, "signal_debug"]
	)

	_resolve_pending_request(req_id, payload)


func _on_push_and_update_completed(
	req_id: int, push_id: String, success: bool, error_msg: String
) -> void:
	var payload: Dictionary

	if success:
		payload = {"status": "ok", "payload": push_id}
	else:
		payload = {"status": "error", "code": "PUSH_FAILED", "message": error_msg}

	_resolve_pending_request(req_id, payload)


func _on_remove_value_completed(req_id: int, success: bool, error_msg: String) -> void:
	var payload: Dictionary

	if success:
		payload = {"status": "ok", "payload": success}
	else:
		payload = {"status": "error", "code": "REMOVE_FAILED", "message": error_msg}

	_resolve_pending_request(req_id, payload)


func _on_query_completed(req_id: int, _key: String, value: Variant) -> void:
	var payload: Dictionary = {"status": "ok", "payload": value}
	_resolve_pending_request(req_id, payload)


func _on_query_error(req_id: int, _key: String, code: int, msg: String) -> void:
	var payload: Dictionary = {"status": "error", "code": code, "message": msg}
	_resolve_pending_request(req_id, payload)


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

	func call_method(method_name: String, args: Array[Variant]) -> Variant:
		if not is_valid():
			return null
		return _cpp_instance.callv(method_name, args)
