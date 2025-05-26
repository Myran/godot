# File: project/data/backends/firebase_backend.gd
class_name FirebaseBackend
extends DataBackend

#-----------------------------------------------------------------------------#
# Type-Safe Inner Classes                                                     #
#-----------------------------------------------------------------------------#


## Strongly-typed wrapper for Firebase C++ database instance
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


## Type-safe Timer management
class TimerManager:
	var _timer: Timer
	var _timer_id: int
	var _is_active: bool = false

	func _init(parent_node: Node, timer_name: String) -> void:
		_timer = Timer.new()
		_timer.name = timer_name
		parent_node.add_child(_timer)
		_timer_id = _timer.get_instance_id()
		_is_active = true

	func is_valid() -> bool:
		return _is_active and is_instance_valid(_timer)

	func get_timer_id() -> int:
		return _timer_id

	func configure(wait_time: float, one_shot: bool = true) -> void:
		if is_valid():
			_timer.wait_time = wait_time
			_timer.one_shot = one_shot

	func connect_timeout(callable: Callable, flags: int = CONNECT_DEFERRED) -> Error:
		if not is_valid():
			return ERR_INVALID_DATA
		return _timer.timeout.connect(callable, flags) as Error

	func start() -> void:
		if is_valid():
			_timer.start()

	func stop() -> void:
		if is_valid():
			_timer.stop()

	func cleanup() -> void:
		if is_valid():
			_timer.queue_free()
		_is_active = false


## Strongly-typed request tracking
class RequestTracker:
	var request_id: int
	var signal_helper: RequestSignalHelper
	var timer_manager: TimerManager
	var result_data: Variant = null
	var is_settled: bool = false

	func _init(req_id: int, sig_helper: RequestSignalHelper, timer_mgr: TimerManager) -> void:
		request_id = req_id
		signal_helper = sig_helper
		timer_manager = timer_mgr

	func settle_with_result(result: Variant) -> void:
		if is_settled:
			return
		result_data = result
		is_settled = true
		if timer_manager.is_valid():
			timer_manager.cleanup()

	func cleanup() -> void:
		if timer_manager.is_valid():
			timer_manager.cleanup()


## Helper class to emit unique signals for each request
class RequestSignalHelper:  # RefCounted so it's managed by Godot's GC
	signal completed(result_data: Variant)  # Signal to indicate operation completion (success or error)


const DEFAULT_TIMEOUT: float = 10.0  # Default timeout for operations in seconds

# Type-safe Firebase database wrapper
var db: FirebaseDatabaseWrapper = null

# Internal State
var _initialized: bool = false
# Strongly-typed request tracking
var _pending_requests: Dictionary = {}  # request_id: int -> RequestTracker
var _next_request_id: int = 0
var _signal_connect_errors: Dictionary = {}  # Stores errors from connecting C++ signals
var _is_being_freed: bool = false  # Flag to prevent actions during object deallocation
var _backend_instance_id_str: String  # Cached string of this instance's ID for logging

#-----------------------------------------------------------------------------#
# Initialization & Lifecycle                                                  #
#-----------------------------------------------------------------------------#


func _init() -> void:
	_is_being_freed = false
	_backend_instance_id_str = str(get_instance_id())  # Cache for logging
	# Log with ERROR level to make multiple inits very obvious in logs, if they occur
	Log.info(
		"FirebaseBackend _init CALLED (DirectAwait Pattern)",
		{"instance_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		Log.error(
			"FirebaseBackend PREDELETE notification (DirectAwait Pattern)",
			{
				"instance_id": _backend_instance_id_str,
				"pending_awaits_count": _pending_requests.size()
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		_is_being_freed = true  # Set flag to stop further processing

		# Clean up pending requests using type-safe RequestTracker
		var request_ids_to_clear: Array[int] = _pending_requests.keys()
		for request_id: int in request_ids_to_clear:
			if _pending_requests.has(request_id):
				var request_tracker: RequestTracker = _pending_requests[request_id]

				Log.debug(
					"FirebaseBackend PREDELETE: Cleaning up request",
					{"req_id": request_id, "backend_id": _backend_instance_id_str},
					[Log.TAG_FIREBASE]
				)

				# Clean up timer safely
				request_tracker.cleanup()

				# Emit completion signal if not already settled
				if (
					not request_tracker.is_settled
					and is_instance_valid(request_tracker.signal_helper)
				):
					var cancel_data: Dictionary = {
						"status": "error",
						"code": "BACKEND_FREED",
						"message": "Backend freed during operation"
					}
					request_tracker.settle_with_result(cancel_data)
					Log.warning(
						"FirebaseBackend PREDELETE: Emitting completion for pending request",
						{"req_id": request_id, "backend_id": _backend_instance_id_str},
						[Log.TAG_FIREBASE]
					)
					request_tracker.signal_helper.completed.emit(cancel_data)

		_pending_requests.clear()

		# Release database wrapper reference
		if db != null and db.is_valid():
			Log.debug(
				"FirebaseBackend: Releasing database wrapper on predelete",
				{"instance_id": _backend_instance_id_str},
				[Log.TAG_FIREBASE]
			)
		db = null


## Initializes the Firebase backend, C++ module, and signal connections.
func initialize() -> bool:
	Log.debug(
		"FirebaseBackend initialize starting... (DirectAwait Pattern)",
		{"instance_id": _backend_instance_id_str},
		[Log.TAG_DB, Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)
	if _initialized:
		Log.warning(
			"FirebaseBackend already initialized. Emitting startup_completed again.",
			{"instance_id": _backend_instance_id_str},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		call_deferred("emit_signal", "startup_completed")
		return true

	if not ClassDB.class_exists("FirebaseDatabase"):
		Log.error(
			"FirebaseDatabase C++ module class not available. Cannot initialize FirebaseBackend.",
			{"instance_id": _backend_instance_id_str},
			[Log.TAG_DB, Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	var cpp_db_instance: Object = ClassDB.instantiate("FirebaseDatabase")
	if not is_instance_valid(cpp_db_instance):
		Log.error(
			"Failed to instantiate FirebaseDatabase C++ module",
			{"instance_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	# Create type-safe wrapper
	db = FirebaseDatabaseWrapper.new(cpp_db_instance)
	Log.debug(
		"FirebaseDatabase wrapper created",
		{"db_instance_id": db.get_cpp_instance_id(), "backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE]
	)

	_connect_signals()  # Connect C++ signals to GDScript handlers

	_initialized = true
	Log.info(
		"FirebaseBackend initialized successfully (DirectAwait Pattern).",
		{"instance_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_DB]
	)

	if not _signal_connect_errors.is_empty():
		Log.error(
			"FirebaseBackend initialized, but some C++ signals failed to connect.",
			{"errors": _signal_connect_errors, "instance_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		# Consider if any failed signal connections are critical enough to return false

	call_deferred("emit_signal", "startup_completed")  # Notify that backend setup is done
	return true


## Checks if the backend is initialized, the database wrapper is valid, and not being freed.
func is_available() -> bool:
	return _initialized and db != null and db.is_valid() and not _is_being_freed


#-----------------------------------------------------------------------------#
# C++ Module Signal Connection                                                #
#-----------------------------------------------------------------------------#


func _connect_signals() -> void:
	if db == null or not db.is_valid():
		Log.error(
			"Cannot connect RTDB signals: database wrapper invalid",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	Log.debug(
		"Connecting Firebase RTDB signals",
		{"backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE]
	)
	_signal_connect_errors.clear()

	var signals_map: Dictionary = {
		"get_value_completed": Callable(self, "_on_get_value_completed"),
		"get_value_error": Callable(self, "_on_get_value_error"),
		"set_value_completed": Callable(self, "_on_set_value_completed"),
		"push_and_update_completed": Callable(self, "_on_push_and_update_completed"),
		"remove_value_completed": Callable(self, "_on_remove_value_completed"),
		"query_completed": Callable(self, "_on_query_completed"),
		"query_error": Callable(self, "_on_query_error"),
		"transaction_completed": Callable(self, "_on_transaction_completed"),
		"child_added": Callable(self, "_on_child_added"),
		"child_changed": Callable(self, "_on_child_changed"),
		"child_moved": Callable(self, "_on_child_moved"),
		"child_removed": Callable(self, "_on_child_removed"),
		"connection_state_changed": Callable(self, "_on_connection_state_changed"),
		"db_error": Callable(self, "_on_db_error"),
	}

	for signal_name: String in signals_map:
		var handler_callable: Callable = signals_map[signal_name]
		if db.is_signal_connected(signal_name, handler_callable):
			Log.debug(
				"RTDB signal '%s' already connected" % signal_name,
				{"backend_id": _backend_instance_id_str},
				[Log.TAG_FIREBASE]
			)
			continue

		var err: Error = db.connect_signal(signal_name, handler_callable, CONNECT_DEFERRED)
		if err != OK:
			var err_msg: String = (
				"Failed to connect RTDB signal '%s': %s" % [signal_name, error_string(err)]
			)
			Log.error(
				err_msg, {"backend_id": _backend_instance_id_str}, [Log.TAG_FIREBASE, Log.TAG_ERROR]
			)
			_signal_connect_errors[signal_name] = error_string(err)
		else:
			Log.debug(
				"Connected RTDB signal: %s" % signal_name,
				{"backend_id": _backend_instance_id_str},
				[Log.TAG_FIREBASE]
			)

	Log.debug(
		"Finished connecting RTDB signals",
		{"backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE]
	)


#-----------------------------------------------------------------------------#
# Internal Request Management (Direct Signal Await)                           #
#-----------------------------------------------------------------------------#


func _get_next_request_id() -> int:
	_next_request_id += 1
	return _next_request_id


## Executes a C++ RTDB operation and returns its result after awaiting a unique signal.
## This version includes the modified timeout_callable logic.
func _execute_rtdb_operation_and_await(
	cpp_method_name: String,
	full_path: Array[Variant],
	args: Array = [],
	timeout_sec: float = DEFAULT_TIMEOUT
) -> Variant:
	if _is_being_freed:
		return {
			"status": "error", "code": "BACKEND_FREED", "message": "Backend instance deallocating"
		}

	if db == null or not db.is_valid():
		return {"status": "error", "code": "DB_NULL", "message": "Database instance not available"}

	if not full_path is Array:
		Log.error(
			"Invalid path type for RTDB operation",
			{"path": full_path, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {"status": "error", "code": "INVALID_PATH_TYPE", "message": "Path must be an Array"}

	var request_id: int = _get_next_request_id()
	var signal_helper: RequestSignalHelper = RequestSignalHelper.new()

	var root_node: Node = Engine.get_main_loop().root
	if not is_instance_valid(root_node):
		Log.error(
			"Root node invalid, cannot create Timer",
			{"req_id": request_id, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {"status": "error", "code": "TIMER_SETUP_FAIL", "message": "Root node unavailable"}

	# Create type-safe timer manager
	var timer_name: String = "FB_Timer_%s_%d" % [_backend_instance_id_str, request_id]
	var timer_manager: TimerManager = TimerManager.new(root_node, timer_name)
	timer_manager.configure(timeout_sec, true)

	# Create strongly-typed request tracker
	var request_tracker: RequestTracker = RequestTracker.new(
		request_id, signal_helper, timer_manager
	)
	_pending_requests[request_id] = request_tracker

	# Type-safe timeout handling
	var timeout_callable: Callable = func() -> void:
		if _is_being_freed:
			return

		if not _pending_requests.has(request_id):
			Log.warning(
				"Timeout for already completed request %d" % request_id,
				{"backend_id": _backend_instance_id_str},
				[Log.TAG_FIREBASE]
			)
			return

		var req_tracker: RequestTracker = _pending_requests[request_id]
		if req_tracker.is_settled:
			Log.warning(
				"Timeout for already settled request %d" % request_id,
				{"backend_id": _backend_instance_id_str},
				[Log.TAG_FIREBASE]
			)
			return

		# Timeout wins the race
		var timeout_result: Dictionary = {
			"status": "error",
			"code": "TIMEOUT",
			"message":
			(
				"Operation '%s' (req_id: %d) timed out after %s seconds"
				% [cpp_method_name, request_id, timeout_sec]
			)
		}

		Log.warning(
			"Request timeout",
			{
				"req_id": request_id,
				"method": cpp_method_name,
				"backend_id": _backend_instance_id_str
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)

		# Settle request and emit signal
		req_tracker.settle_with_result(timeout_result)
		_pending_requests.erase(request_id)

		if is_instance_valid(req_tracker.signal_helper):
			req_tracker.signal_helper.completed.emit(timeout_result)

	var connect_err: Error = timer_manager.connect_timeout(timeout_callable, CONNECT_DEFERRED)
	if connect_err != OK:
		Log.error(
			"Failed to connect timeout timer signal",
			{
				"req_id": request_id,
				"error": error_string(connect_err),
				"backend_id": _backend_instance_id_str
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		_pending_requests.erase(request_id)
		timer_manager.cleanup()
		return {
			"status": "error",
			"code": "TIMER_SETUP_FAIL",
			"message": "Failed to connect timer signal"
		}

	var call_args: Array = [request_id, full_path]
	call_args.append_array(args)

	Log.debug(
		"Executing RTDB operation",
		{
			"req_id": request_id,
			"method": cpp_method_name,
			"path": full_path,
			"backend_id": _backend_instance_id_str
		},
		[Log.TAG_FIREBASE, Log.TAG_NETWORK]
	)

	# Use type-safe database wrapper
	db.call_method(cpp_method_name, call_args)
	timer_manager.start()

	Log.debug(
		"Awaiting completion signal for req_id %d" % request_id,
		{"backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE]
	)
	var final_result_data: Variant = await signal_helper.completed

	Log.debug(
		"Completion signal received for req_id %d" % request_id,
		{"backend_id": _backend_instance_id_str, "result_type": typeof(final_result_data)},
		[Log.TAG_FIREBASE]
	)

	# Clean up any remaining request tracker
	if _pending_requests.has(request_id):
		Log.warning(
			"Request %d still in tracking after settlement, force cleaning" % request_id,
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		var remaining_tracker: RequestTracker = _pending_requests[request_id]
		remaining_tracker.cleanup()
		_pending_requests.erase(request_id)

	return final_result_data


## Type-safe completion handler using RequestTracker
func _complete_direct_await(
	request_id: int,
	result_payload: Variant,
	is_error: bool = false,
	error_code: String = "",
	error_message: String = ""
) -> void:
	if _is_being_freed:
		Log.warning(
			"Complete await called while backend freeing",
			{"req_id": request_id, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE]
		)
		return

	if not _pending_requests.has(request_id):
		Log.warning(
			"Received completion for unknown request %d" % request_id,
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE]
		)
		return

	var request_tracker: RequestTracker = _pending_requests[request_id]

	if request_tracker.is_settled:
		Log.warning(
			"Attempt to complete already settled request %d" % request_id,
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE]
		)
		_pending_requests.erase(request_id)
		return

	var result_for_signal: Dictionary
	if is_error:
		result_for_signal = {
			"status": "error",
			"code": error_code,
			"message": error_message,
			"payload": result_payload
		}
		Log.error(
			"Completing request %d with error" % request_id,
			{"error_info": result_for_signal, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
	else:
		result_for_signal = {"status": "ok", "payload": result_payload}
		Log.debug(
			"Completing request %d with success" % request_id,
			{"payload_type": typeof(result_payload), "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE]
		)

	# Settle request safely
	request_tracker.settle_with_result(result_for_signal)
	_pending_requests.erase(request_id)

	if is_instance_valid(request_tracker.signal_helper):
		request_tracker.signal_helper.completed.emit(result_for_signal)
	else:
		Log.error(
			"Signal helper invalid for request %d during completion" % request_id,
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)


#-----------------------------------------------------------------------------#
# C++ Signal Handlers (Calling _complete_direct_await)                        #
#-----------------------------------------------------------------------------#


func _on_get_value_completed(request_id: int, rtdb_key: String, value: Variant) -> void:
	Log.debug(
		"FB_Backend: _on_get_value_completed (DirectAwait) CALLED",
		{
			"req_id": request_id,
			"key": rtdb_key,
			"value_type": typeof(value),
			"fb_backend_id": _backend_instance_id_str
		},
		[Log.TAG_FIREBASE]
	)
	_complete_direct_await(request_id, value)


func _on_get_value_error(
	request_id: int, rtdb_key: String, error_code: String, error_message: String
) -> void:
	Log.error(
		"FB_Backend: _on_get_value_error (DirectAwait) CALLED",
		{
			"req_id": request_id,
			"key": rtdb_key,
			"code": error_code,
			"msg": error_message,
			"fb_backend_id": _backend_instance_id_str
		},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	_complete_direct_await(request_id, null, true, error_code, error_message)


func _on_set_value_completed(request_id: int, success: bool, error_message: String) -> void:
	Log.debug(
		"FB_Backend: _on_set_value_completed (DirectAwait)",
		{"req_id": request_id, "success": success, "fb_backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE]
	)
	if success:
		_complete_direct_await(request_id, true)
	else:
		_complete_direct_await(request_id, error_message, true, "SET_VALUE_FAILED", error_message)


func _on_push_and_update_completed(
	request_id: int, push_id: String, success: bool, error_message: String
) -> void:
	Log.debug(
		"FB_Backend: _on_push_and_update_completed (DirectAwait)",
		{
			"req_id": request_id,
			"success": success,
			"push_id": push_id if success else "N/A",
			"fb_backend_id": _backend_instance_id_str
		},
		[Log.TAG_FIREBASE]
	)
	if success:
		_complete_direct_await(request_id, push_id)
	else:
		_complete_direct_await(request_id, error_message, true, "PUSH_UPDATE_FAILED", error_message)


func _on_remove_value_completed(request_id: int, success: bool, error_message: String) -> void:
	Log.debug(
		"FB_Backend: _on_remove_value_completed (DirectAwait)",
		{"req_id": request_id, "success": success, "fb_backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE]
	)
	if success:
		_complete_direct_await(request_id, true)
	else:
		_complete_direct_await(
			request_id, error_message, true, "REMOVE_VALUE_FAILED", error_message
		)


func _on_query_completed(request_id: int, rtdb_key: String, value: Variant) -> void:
	Log.debug(
		"FB_Backend: _on_query_completed (DirectAwait)",
		{
			"req_id": request_id,
			"key": rtdb_key,
			"value_type": typeof(value),
			"fb_backend_id": _backend_instance_id_str
		},
		[Log.TAG_FIREBASE]
	)
	_complete_direct_await(request_id, value)


func _on_query_error(
	request_id: int, rtdb_key: String, error_code: String, error_message: String
) -> void:
	Log.error(
		"FB_Backend: _on_query_error (DirectAwait)",
		{
			"req_id": request_id,
			"key": rtdb_key,
			"code": error_code,
			"msg": error_message,
			"fb_backend_id": _backend_instance_id_str
		},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	_complete_direct_await(request_id, null, true, error_code, error_message)


func _on_transaction_completed(
	request_id: int, rtdb_key: String, value: Variant, success: bool, error_message: String
) -> void:
	Log.debug(
		"FB_Backend: _on_transaction_completed (DirectAwait)",
		{
			"req_id": request_id,
			"key": rtdb_key,
			"success": success,
			"fb_backend_id": _backend_instance_id_str
		},
		[Log.TAG_FIREBASE]
	)
	if success:
		_complete_direct_await(request_id, value)
	else:
		_complete_direct_await(request_id, error_message, true, "TRANSACTION_FAILED", error_message)


# --- Real-time Listener Signals (These don't use the request/await pattern) ---
func _on_child_added(key: String, value: Variant) -> void:
	Log.info(
		"[RTDB LISTENER] Child Added",
		{"key": key, "value_type": typeof(value), "fb_backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_EVENT]
	)


func _on_child_changed(key: String, value: Variant) -> void:
	Log.info(
		"[RTDB LISTENER] Child Changed",
		{"key": key, "value_type": typeof(value), "fb_backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_EVENT]
	)


func _on_child_moved(key: String, value: Variant) -> void:
	Log.info(
		"[RTDB LISTENER] Child Moved",
		{"key": key, "value_type": typeof(value), "fb_backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_EVENT]
	)


func _on_child_removed(key: String, value: Variant) -> void:
	Log.info(
		"[RTDB LISTENER] Child Removed",
		{"key": key, "old_value_type": typeof(value), "fb_backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_EVENT]
	)


func _on_connection_state_changed(connected: bool) -> void:
	Log.info(
		"Firebase RTDB connection state changed.",
		{"connected": connected, "fb_backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_NETWORK]
	)


func _on_db_error(code: String, message: String) -> void:
	Log.error(
		"General Firebase RTDB Error from C++.",
		{"code": code, "message": message, "fb_backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)


#-----------------------------------------------------------------------------#
# Public DataBackend API Implementation (Using Direct Signal Await)           #
#-----------------------------------------------------------------------------#


func get_data(p_path: Array[Variant], key: String) -> Variant:
	if not is_available():
		Log.error(
			"FB_Backend: Not available for get_data.",
			{"path": p_path, "key": key, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	var full_path: Array[Variant] = p_path.duplicate()
	if not key.is_empty():
		full_path.append(key)
	if full_path.is_empty():
		Log.error(
			"FB_Backend: get_data requires non-empty path.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	var result_dict: Dictionary = await _execute_rtdb_operation_and_await(
		"get_value_async", full_path
	)

	if result_dict.get("status") == "ok":
		Log.debug(
			"FB_Backend: get_data (DirectAwait) fulfilled.",
			{"path": full_path, "value_type": typeof(result_dict.get("payload"))},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		call_deferred(
			"emit_signal",
			"value_received",
			{
				"key": key if not key.is_empty() else full_path[-1],
				"value": result_dict.get("payload")
			}
		)
		return result_dict.get("payload")
	else:  # Error or Timeout
		Log.error(
			"FB_Backend: get_data (DirectAwait) failed.",
			{"path": full_path, "error_info": result_dict, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null


func set_data(p_path: Array[Variant], key: String, data_to_set: Variant) -> bool:
	if not is_available():
		Log.error(
			"FB_Backend: Not available for set_data.", {"backend_id": _backend_instance_id_str}
		)
		return false
	var full_path: Array[Variant] = p_path.duplicate()
	if not key.is_empty():
		full_path.append(key)
	if full_path.is_empty():
		Log.error(
			"FB_Backend: set_data requires non-empty path.",
			{"backend_id": _backend_instance_id_str}
		)
		return false

	var result_dict: Dictionary = await _execute_rtdb_operation_and_await(
		"set_value_async", full_path, [data_to_set]
	)

	if result_dict.get("status") == "ok":
		return result_dict.get("payload").to_bool() # C++ signal for set_value_completed sends success (bool) as payload
	Log.error(
		"FB_Backend: set_data (DirectAwait) failed.",
		{"path": full_path, "error_info": result_dict, "backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return false


func push_data(p_path: Array[Variant], data_to_push: Variant) -> String:
	if not is_available():
		return ""
	if not data_to_push is Dictionary:
		Log.warning(
			"FB_Backend: push_data usually expects Dictionary.",
			{"path": p_path, "type": typeof(data_to_push), "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE]
		)

	var result_dict: Dictionary = await _execute_rtdb_operation_and_await(
		"push_and_update_async", p_path, [data_to_push]
	)
	if result_dict.get("status") == "ok":
		return result_dict.get("payload").as_String()  # push_id
	Log.error(
		"FB_Backend: push_data (DirectAwait) failed.",
		{"path": p_path, "error_info": result_dict, "backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return ""


func remove_data(p_path: Array[Variant], key: String) -> bool:
	if not is_available():
		return false
	var full_path: Array[Variant] = p_path.duplicate()
	if not key.is_empty():
		full_path.append(key)
	if full_path.is_empty():
		return false

	var result_dict: Dictionary = await _execute_rtdb_operation_and_await(
		"remove_value_async", full_path
	)
	if result_dict.get("status") == "ok":
		return result_dict.get("payload").as_bool()  # true for success
	Log.error(
		"FB_Backend: remove_data (DirectAwait) failed.",
		{"path": full_path, "error_info": result_dict, "backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return false


func query_data(p_path: Array[Variant], query_params: Dictionary) -> Variant:
	if not is_available():
		return null
	var result_dict: Dictionary = await _execute_rtdb_operation_and_await(
		"query_ordered_data_async", p_path, [query_params]
	)
	if result_dict.get("status") == "ok":
		return result_dict.get("payload")
	Log.error(
		"FB_Backend: query_data (DirectAwait) failed.",
		{"path": p_path, "error_info": result_dict, "backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return null


func run_increment_transaction(p_path: Array[Variant], increment_by: int = 1) -> Variant:
	if not is_available():
		return null
	var result_dict: Dictionary = await _execute_rtdb_operation_and_await(
		"run_transaction_async", p_path, [increment_by]
	)
	if result_dict.get("status") == "ok":
		return result_dict.get("payload")  # final value
	Log.error(
		"FB_Backend: run_increment_transaction (DirectAwait) failed.",
		{"path": p_path, "error_info": result_dict, "backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return null


func set_server_timestamp(p_path: Array[Variant]) -> bool:
	if not is_available():
		return false
	if p_path.is_empty():
		Log.error(
			"FB_Backend: set_server_timestamp requires non-empty path.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	var result_dict: Dictionary = await _execute_rtdb_operation_and_await(
		"set_server_timestamp_async", p_path
	)
	if result_dict.get("status") == "ok":
		return result_dict.get("payload").as_bool() # C++ signal sends success (bool)
	Log.error(
		"FB_Backend: set_server_timestamp (DirectAwait) failed.",
		{"path": p_path, "error_info": result_dict, "backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return false


# Listener Management methods are unchanged as they are not promise-based.
func start_listening(path_array: Array[Variant]) -> void:
	if not is_available():
		Log.error(
			"FB_Backend: Not available for start_listening.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return
	if not path_array is Array or path_array.is_empty():
		Log.error(
			"FB_Backend: Invalid path for start_listening.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return
	Log.info(
		"FB_Backend: Requesting C++ to start listening.",
		{"path": path_array, "backend_id": _backend_instance_id_str},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)
	if is_instance_valid(db):
		db.add_listener_at_path(path_array)


func stop_listening(path_array: Array[Variant]) -> void:
	if not is_available():
		Log.error(
			"FB_Backend: Not available for stop_listening.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return
	if not path_array is Array or path_array.is_empty():
		Log.error(
			"FB_Backend: Invalid path for stop_listening.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return
	Log.info(
		"FB_Backend: Requesting C++ to stop listening.",
		{"path": path_array, "backend_id": _backend_instance_id_str},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)
	if is_instance_valid(db):
		db.remove_listener_at_path(path_array)
