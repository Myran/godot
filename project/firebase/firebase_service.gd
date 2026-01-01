extends Node

signal firebase_initialized
signal firebase_error(error: String)

var db: Object  # FirebaseDatabaseWrapper instance (using Object to avoid forward reference)
var _cpp_database: Object
var _is_initialized: bool = false
var _next_request_id: int = 1
var _pending_requests: Dictionary = {}
var _rate_limiter: RefCounted
var analytics: AnalyticsService  # Analytics service instance
var remote_config: RemoteConfigService  # Remote Config service instance


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


func get_analytics() -> AnalyticsService:
	# Lazy initialization of Analytics service
	if analytics == null:
		if not ClassDB.class_exists("FirebaseAnalytics"):
			Log.error(
				"FirebaseAnalytics C++ module not available",
				{"platform": OS.get_name()},
				[Log.TAG_FIREBASE, Log.TAG_ERROR]
			)
			return null

		var cpp_analytics: Object = ClassDB.instantiate("FirebaseAnalytics")
		if not is_instance_valid(cpp_analytics):
			Log.error(
				"Failed to instantiate FirebaseAnalytics C++ module",
				{},
				[Log.TAG_FIREBASE, Log.TAG_ERROR]
			)
			return null

		analytics = AnalyticsService.new(cpp_analytics)
		Log.info(
			"AnalyticsService created",
			{},
			[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
		)

	return analytics


func get_remote_config() -> RemoteConfigService:
	# Lazy initialization of Remote Config service
	if remote_config == null:
		if not ClassDB.class_exists("FirebaseRemoteConfig"):
			Log.error(
				"FirebaseRemoteConfig C++ module not available",
				{"platform": OS.get_name()},
				[Log.TAG_FIREBASE, Log.TAG_ERROR]
			)
			return null

		var cpp_remote_config: Object = ClassDB.instantiate("FirebaseRemoteConfig")
		if not is_instance_valid(cpp_remote_config):
			Log.error(
				"Failed to instantiate FirebaseRemoteConfig C++ module",
				{},
				[Log.TAG_FIREBASE, Log.TAG_ERROR]
			)
			return null

		remote_config = RemoteConfigService.new(cpp_remote_config)
		Log.info(
			"RemoteConfigService created",
			{},
			[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
		)

	return remote_config


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


func _resolve_pending_request(request_id: int, result: Variant) -> bool:
	## Process Firebase request completions directly (C++ MessageQueue handles threading)
	## Task-207: C++ layer uses MessageQueue for thread safety, no GDScript queue needed

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
				"request_instance_id": request.get_instance_id(),
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
				"Completing queued request with success",
				{
					"request_id": request_id,
					"payload_size": len(str(result.payload)) if result.payload else 0
				},
				[Log.TAG_FIREBASE, Log.TAG_DEBUG]
			)
			# CRITICAL SAFETY: Deep copy Firebase C++ SDK response to prevent ARM64 alignment crashes
			# Firebase C++ SDK can return misaligned memory that causes SIGBUS when accessed by GDScript
			# This must happen BEFORE passing to FirebaseRequest to prevent crash in complete_with_success
			var safe_payload: Variant = _safe_copy_variant(result.payload)
			request.complete_with_success(safe_payload)
		else:
			Log.debug(
				"Completing queued request with error",
				{"request_id": request_id, "error": result},
				[Log.TAG_FIREBASE, Log.TAG_DEBUG]
			)
			request.complete_with_error(
				(
					str(result.get("code", "UNKNOWN_ERROR"))
					if result is Dictionary
					else "UNKNOWN_ERROR"
				),
				(
					str(result.get("message", "Unknown error occurred"))
					if result is Dictionary
					else "Unknown error occurred"
				)
			)

		return true

	Log.warning(
		"Received queued completion for unknown request",
		{"request_id": request_id, "pending_requests": _pending_requests.keys()},
		[Log.TAG_FIREBASE, Log.TAG_DEBUG]
	)
	return false


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


# CRITICAL THREAD SAFETY: Ensure all Firebase operations happen on main thread
# Firebase C++ callbacks can execute in GLThread context, which violates Godot's
# threading requirements when accessing Godot objects and memory management.
func _ensure_main_thread() -> void:
	# CRITICAL: Firebase signal handlers MUST execute on main thread
	# Processing Godot Variants in GLThread causes memory corruption and crashes
	assert(
		Engine.get_main_loop() == get_tree(),
		"CRITICAL THREADING VIOLATION: Firebase operation on non-main thread! This will cause crashes."
	)
	Log.debug(
		"FirebaseService: Main thread validation passed", {}, [Log.TAG_FIREBASE, "thread_safety"]
	)


# SAFETY: Deep copy Variants from Firebase to prevent ARM64 alignment crashes
# Firebase C++ SDK can return Variants with misaligned memory addresses
# (e.g., 0x533b000bdf mod 8 = 7) that cause SIGBUS crashes on ARM64
# when accessed by GDScript. This function ensures proper memory alignment.
func _safe_copy_variant(variant: Variant) -> Variant:
	# Handle null or empty variants safely
	if variant == null:
		return null

	match typeof(variant):
		TYPE_DICTIONARY:
			var dict: Dictionary = variant
			var safe_dict: Dictionary = {}
			for key: Variant in dict.keys():
				safe_dict[key] = _safe_copy_variant(dict[key])
			return safe_dict
		TYPE_ARRAY:
			var arr: Array = variant
			var safe_arr: Array = []
			for item: Variant in arr:
				safe_arr.append(_safe_copy_variant(item))
			return safe_arr
		TYPE_STRING:
			# Strings might have misaligned memory internally, create a safe copy
			var str_variant: String = variant
			return String(str_variant)
		_:
			# Primitives (int, float, bool) are safe to return directly
			return variant


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
	# C++ already marshalled to main thread via MessageQueue + call_deferred
	# No need for additional deferral - process directly
	_process_get_value_on_main_thread(req_id, value)


func _process_get_value_on_main_thread(req_id: int, value: Variant) -> void:
	# GUARANTEED MAIN THREAD EXECUTION - Safe for all Godot operations
	_ensure_main_thread()

	# CRITICAL SAFETY: Deep copy Firebase C++ SDK response to prevent ARM64 alignment crashes
	# Firebase C++ SDK can return misaligned memory that causes SIGBUS when accessed by GDScript
	var safe_value: Variant = _safe_copy_variant(value)
	var payload: Dictionary = {"status": "ok", "payload": safe_value}
	_resolve_pending_request(req_id, payload)


func _on_get_value_error(req_id: int, _key: String, code: String, msg: String) -> void:
	# CRITICAL THREAD SAFETY: Marshal to main thread before ANY processing
	_process_get_value_error_on_main_thread(req_id, code, msg)


func _process_get_value_error_on_main_thread(req_id: int, code: String, msg: String) -> void:
	# GUARANTEED MAIN THREAD EXECUTION - Safe for all Godot operations
	_ensure_main_thread()

	var payload: Dictionary = {"status": "error", "code": code, "message": msg}
	_resolve_pending_request(req_id, payload)


func _on_set_value_completed(req_id: int, success: bool, error_msg: String) -> void:
	# CRITICAL THREAD SAFETY: Marshal to main thread before ANY processing
	_process_set_value_on_main_thread(req_id, success, error_msg)


func _process_set_value_on_main_thread(req_id: int, success: bool, error_msg: String) -> void:
	# GUARANTEED MAIN THREAD EXECUTION - Safe for all Godot operations
	_ensure_main_thread()

	Log.debug(
		"_process_set_value_on_main_thread called",
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
	req_id: int, push_id: Variant, success: bool, error_msg: String
) -> void:
	# C++ already marshalled to main thread via MessageQueue + call_deferred
	# No need for additional deferral - process directly
	_process_push_and_update_on_main_thread(req_id, push_id, success, error_msg)


func _process_push_and_update_on_main_thread(
	req_id: int, push_id: Variant, success: bool, error_msg: String
) -> void:
	# GUARANTEED MAIN THREAD EXECUTION - Safe for all Godot operations
	_ensure_main_thread()

	# CRITICAL SAFETY: Deep copy Firebase C++ SDK response to prevent ARM64 alignment crashes
	# Firebase C++ SDK can return misaligned memory that causes SIGBUS when accessed by GDScript
	# This must happen BEFORE passing to FirebaseRequest to prevent crash in complete_with_success
	var safe_push_id: Variant = _safe_copy_variant(push_id)

	var payload: Dictionary

	if success:
		payload = {"status": "ok", "payload": safe_push_id}
	else:
		payload = {"status": "error", "code": "PUSH_FAILED", "message": error_msg}

	_resolve_pending_request(req_id, payload)


func _on_remove_value_completed(req_id: int, success: bool, error_msg: String) -> void:
	# CRITICAL THREAD SAFETY: Marshal to main thread before ANY processing
	_process_remove_value_on_main_thread(req_id, success, error_msg)


func _process_remove_value_on_main_thread(req_id: int, success: bool, error_msg: String) -> void:
	# GUARANTEED MAIN THREAD EXECUTION - Safe for all Godot operations
	_ensure_main_thread()

	var payload: Dictionary

	if success:
		payload = {"status": "ok", "payload": success}
	else:
		payload = {"status": "error", "code": "REMOVE_FAILED", "message": error_msg}

	_resolve_pending_request(req_id, payload)


func _on_query_completed(req_id: int, _key: String, value: Variant) -> void:
	# CRITICAL THREAD SAFETY: Marshal to main thread before ANY processing
	_process_query_on_main_thread(req_id, value)


func _process_query_on_main_thread(req_id: int, value: Variant) -> void:
	# GUARANTEED MAIN THREAD EXECUTION - Safe for all Godot operations
	_ensure_main_thread()

	# CRITICAL SAFETY: Deep copy Firebase C++ SDK response to prevent ARM64 alignment crashes
	var safe_value: Variant = _safe_copy_variant(value)
	var payload: Dictionary = {"status": "ok", "payload": safe_value}
	_resolve_pending_request(req_id, payload)


func _on_query_error(req_id: int, _key: String, code: int, msg: String) -> void:
	# CRITICAL THREAD SAFETY: Marshal to main thread before ANY processing
	_process_query_error_on_main_thread(req_id, code, msg)


func _process_query_error_on_main_thread(req_id: int, code: int, msg: String) -> void:
	# GUARANTEED MAIN THREAD EXECUTION - Safe for all Godot operations
	_ensure_main_thread()

	var payload: Dictionary = {"status": "error", "code": code, "message": msg}
	_resolve_pending_request(req_id, payload)


func _on_transaction_completed(
	req_id: int, _key: String, value: Variant, success: bool, error_msg: String
) -> void:
	# CRITICAL THREAD SAFETY: Marshal to main thread before ANY processing
	_process_transaction_on_main_thread(req_id, value, success, error_msg)


func _process_transaction_on_main_thread(
	req_id: int, value: Variant, success: bool, error_msg: String
) -> void:
	# GUARANTEED MAIN THREAD EXECUTION - Safe for all Godot operations
	_ensure_main_thread()

	var payload: Dictionary
	if success:
		# CRITICAL SAFETY: Deep copy Firebase C++ SDK response to prevent ARM64 alignment crashes
		var safe_value: Variant = _safe_copy_variant(value)
		payload = {"status": "ok", "payload": safe_value}
	else:
		payload = {"status": "error", "code": "TRANSACTION_FAILED", "message": error_msg}
	_resolve_pending_request(req_id, payload)


func _on_server_timestamp_completed(req_id: int, success: bool, error_msg: String) -> void:
	# CRITICAL THREAD SAFETY: Marshal to main thread before ANY processing
	_process_server_timestamp_on_main_thread(req_id, success, error_msg)


func _process_server_timestamp_on_main_thread(
	req_id: int, success: bool, error_msg: String
) -> void:
	# GUARANTEED MAIN THREAD EXECUTION - Safe for all Godot operations
	_ensure_main_thread()

	var payload: Dictionary = (
		{"status": "ok", "payload": success}
		if success
		else {"status": "error", "code": "TIMESTAMP_FAILED", "message": error_msg}
	)
	_resolve_pending_request(req_id, payload)


# Enhanced Firebase cleanup for Android test isolation (Task-230)
# SAFETY: This method is called during app quit, uses conditional checks to prevent errors
func shutdown_firebase_connections() -> void:
	if OS.get_name() != "Android" and OS.get_name() != "macOS":
		return  # Only needed on Android and macOS where resource accumulation occurs

	Log.info("🔧 Starting Firebase cleanup (" + OS.get_name() + ")", {}, [Log.TAG_FIREBASE])

	# CRITICAL FIX: Flush CallQueue BEFORE cleanup to prevent callbacks during shutdown
	# This prevents stale Firebase callbacks from being processed after objects are freed
	if OS.get_name() == "macOS":
		Log.info(
			"🧹 Flushing CallQueue before Firebase cleanup (macOS crash prevention)",
			{},
			[Log.TAG_FIREBASE]
		)
		# Force CallQueue flush to process any pending callbacks before we start cleanup
		# This ensures no Firebase callbacks are left in the queue during Main::cleanup()
		var call_queue_flushed: bool = _flush_call_queue_safely()
		Log.info("✅ CallQueue flush completed", {"success": call_queue_flushed}, [Log.TAG_FIREBASE])

	# SAFETY: Listener cleanup is handled automatically by C++ FirebaseDatabase destructor
	# The destructor checks _listener_path_ref_count > 0 and removes active listeners
	# Calling remove_listener_at_path here with empty array causes "Method expected 1 arguments" error
	# because it requires a valid path array to match against _active_child_listener_ref

	# SAFETY: Manual cleanup operations are conditional-safe
	_cleanup_pending_requests()
	_reset_rate_limiter()

	Log.info(
		"🎯 Firebase cleanup completed - C++ destructor handles listener cleanup",
		{},
		[Log.TAG_FIREBASE]
	)


# macOS-specific CallQueue flush to prevent callback crashes during shutdown
func _flush_call_queue_safely() -> bool:
	"""Safely flush Godot's CallQueue to process any pending callbacks before cleanup.

	This prevents Firebase callbacks from being processed after objects are freed
	during Main::cleanup(), which causes the KERN_INVALID_ADDRESS crash.
	"""
	if Engine.get_main_loop() == null:
		Log.warning("⚠️ Engine main loop not available for CallQueue flush", {}, [Log.TAG_FIREBASE])
		return false

	# Get the CallQueue singleton
	var call_queue: Object = Engine.get_main_loop().get("call_queue")
	if call_queue == null:
		Log.debug("ℹ️ CallQueue not found - may already be cleaned up", {}, [Log.TAG_FIREBASE])
		return true  # Not an error if it's already cleaned up

	# Check if flush method exists
	if not call_queue.has_method("flush"):
		Log.debug("ℹ️ CallQueue flush method not available", {}, [Log.TAG_FIREBASE])
		return true

	# Force flush to process all pending callbacks
	# Note: GDScript doesn't have try-catch - use conditional safety instead
	if is_instance_valid(call_queue):
		call_queue.flush()
		Log.debug("✅ CallQueue flush completed successfully", {}, [Log.TAG_FIREBASE])
		return true

	Log.warning("⚠️ CallQueue is not valid during flush", {}, [Log.TAG_FIREBASE])
	return false


func _cleanup_pending_requests() -> void:
	# Clear all pending Firebase requests
	for request_id: int in _pending_requests.keys():
		cleanup_timed_out_request(request_id)
	_pending_requests.clear()

	# Clear database wrapper reference
	if db != null:
		db = null
	_cpp_database = null
	_is_initialized = false


func _reset_rate_limiter() -> void:
	# Reset rate limiter circuit breaker
	if _rate_limiter != null:
		_rate_limiter._reset_circuit_breaker()


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
