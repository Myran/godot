# project/data/backends/firebase_backend.gd
class_name FirebaseBackend
extends DataBackend

const PromiseClass: GDScript = preload("res://misc/promise.gd")  # Adjust path if necessary

# Firebase C++ Database Module Instance
var db: Object = null  # Will hold the FirebaseDatabase C++ instance

# Internal State
var _initialized: bool = false
var _pending_requests: Dictionary = {}  # Format: { request_id: int -> { promise: Promise, path: Array, operation: String } }
var _next_request_id: int = 0
var _signal_connect_errors: Dictionary = {}  # To track any signal connection failures

const DEFAULT_TIMEOUT: float = 15.0  # Default timeout for Firebase operations in seconds

#-----------------------------------------------------------------------------#
# Initialization & Availability                                               #
#-----------------------------------------------------------------------------#


func _init() -> void:
	Log.info(
		"FirebaseBackend constructing (Internet check handled by factory)",
		{},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)


## Initializes the Firebase backend. Assumes internet availability has been pre-checked by the factory.
func initialize() -> bool:
	Log.debug(
		"FirebaseBackend initialize called",
		{},
		[Log.TAG_DB, Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)
	if _initialized:
		Log.warning(
			"FirebaseBackend already initialized. Emitting startup_completed again.",
			{},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		call_deferred("emit_signal", "startup_completed")
		return true

	if not ClassDB.class_exists("FirebaseDatabase"):
		(
			Log
			. error(
				"FirebaseDatabase C++ module class not available in ClassDB. Cannot initialize FirebaseBackend.",
				{},
				[Log.TAG_DB, Log.TAG_FIREBASE, Log.TAG_ERROR]
			)
		)
		return false

	Log.debug("Proceeding with FirebaseDatabase C++ module instantiation.", {}, [Log.TAG_FIREBASE])
	db = ClassDB.instantiate("FirebaseDatabase")
	if db == null:
		Log.error(
			"Failed to instantiate FirebaseDatabase C++ module.",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	_connect_signals()

	_initialized = true
	Log.info("FirebaseBackend initialized successfully.", {}, [Log.TAG_FIREBASE, Log.TAG_DB])

	if not _signal_connect_errors.is_empty():
		Log.error(
			"FirebaseBackend initialized, but some C++ signals failed to connect.",
			{"errors": _signal_connect_errors},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)

	call_deferred("emit_signal", "startup_completed")
	return true


## Checks if the Firebase backend is initialized and the C++ module is available.
func is_available() -> bool:
	return _initialized and db != null


#-----------------------------------------------------------------------------#
# C++ Module Signal Connection                                                #
#-----------------------------------------------------------------------------#


func _connect_signals() -> void:
	if db == null:
		Log.error(
			"Cannot connect RTDB signals: C++ db instance is null.",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	Log.debug("Connecting Firebase RTDB C++ signals.", {}, [Log.TAG_FIREBASE])

	var connect_ok: Callable = func(signal_name: String, handler_callable: Callable) -> void:
		if not db.is_connected(signal_name, handler_callable):
			var err: Error = db.connect(signal_name, handler_callable, CONNECT_DEFERRED)
			if err != OK:
				var error_msg: String = (
					"Failed to connect RTDB signal '%s' to %s: Error %s"
					% [signal_name, handler_callable.get_method(), error_string(err)]
				)
				Log.error(error_msg, {}, [Log.TAG_FIREBASE, Log.TAG_ERROR])
				_signal_connect_errors[signal_name] = error_string(err)
			else:
				Log.debug("Connected RTDB signal: %s" % signal_name, {}, [Log.TAG_FIREBASE])

	# Request/Response Signals
	connect_ok.call("get_value_completed", Callable(self, "_on_get_value_completed"))
	connect_ok.call("get_value_error", Callable(self, "_on_get_value_error"))
	connect_ok.call("set_value_completed", Callable(self, "_on_set_value_completed"))
	connect_ok.call("push_and_update_completed", Callable(self, "_on_push_and_update_completed"))
	connect_ok.call("remove_value_completed", Callable(self, "_on_remove_value_completed"))
	connect_ok.call("query_completed", Callable(self, "_on_query_completed"))
	connect_ok.call("query_error", Callable(self, "_on_query_error"))
	connect_ok.call("transaction_completed", Callable(self, "_on_transaction_completed"))

	# Real-time Listener Signals
	connect_ok.call("child_added", Callable(self, "_on_child_added"))
	connect_ok.call("child_changed", Callable(self, "_on_child_changed"))
	connect_ok.call("child_moved", Callable(self, "_on_child_moved"))
	connect_ok.call("child_removed", Callable(self, "_on_child_removed"))

	# Status Signals
	connect_ok.call("connection_state_changed", Callable(self, "_on_connection_state_changed"))
	connect_ok.call("db_error", Callable(self, "_on_db_error"))


#-----------------------------------------------------------------------------#
# Internal Request Management                                                 #
#-----------------------------------------------------------------------------#


func _make_internal_request(
	operation_callable: Callable,
	full_path: Array,
	args: Array = [],
	timeout_sec: float = DEFAULT_TIMEOUT
) -> Promise:
	var request_id: int = _next_request_id
	_next_request_id += 1

	if not full_path is Array:
		Log.error(
			"Invalid full_path type for internal RTDB request. Must be Array.",
			{"path": full_path, "type": typeof(full_path)},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		var err_promise: Promise = PromiseClass.new()
		err_promise.reject({"code": "INVALID_ARGUMENT", "message": "Path must be an Array."})
		return err_promise

	var promise: Promise = PromiseClass.new(timeout_sec)
	_pending_requests[request_id] = {
		"promise": promise, "path": full_path, "operation": operation_callable.get_method()
	}

	var call_args: Array = [request_id, full_path]  # request_id and path are always first two args to C++ methods
	call_args.append_array(args)

	if Log._debug_filter_logging:  # Use the logger's own debug flag if available
		Log.debug(
			"Making Firebase RTDB request",
			{
				"req_id": request_id,
				"operation": operation_callable.get_method(),
				"path": full_path,
				"args_sent_count": args.size()
			},
			[Log.TAG_FIREBASE, Log.TAG_NETWORK]
		)

	db.callv(operation_callable.get_method(), call_args)  # Call the C++ method

	# Connect to promise signals to clean up _pending_requests
	var cleanup_callable: Callable = func(_result_or_reason: Variant) -> void:
		if _pending_requests.has(request_id):
			if Log._debug_filter_logging:
				Log.debug(
					"Cleaning up pending RTDB request entry",
					{"req_id": request_id},
					[Log.TAG_FIREBASE]
				)
			_pending_requests.erase(request_id)

	promise.fulfilled.connect(cleanup_callable, CONNECT_ONE_SHOT)
	promise.rejected.connect(cleanup_callable, CONNECT_ONE_SHOT)
	promise.timed_out.connect(cleanup_callable, CONNECT_ONE_SHOT)  # Also cleanup on timeout

	return promise


func _resolve_request(request_id: int, value: Variant = null) -> void:
	if _pending_requests.has(request_id):
		var req_data: Dictionary = _pending_requests[request_id]
		var promise_to_resolve: Promise = req_data.promise
		if promise_to_resolve.state == Promise.State.PENDING:
			Log.debug(
				"Resolving internal Firebase RTDB promise",
				{"req_id": request_id, "operation": req_data.operation},
				[Log.TAG_FIREBASE]
			)
			promise_to_resolve.resolve(value)
		# No else needed, promise.resolve handles already settled state
	else:
		Log.warning(
			"Received completion for unknown or timed-out RTDB request_id.",
			{"req_id": request_id},
			[Log.TAG_FIREBASE]
		)


func _reject_request(request_id: int, error_code: String, error_message: String) -> void:
	if _pending_requests.has(request_id):
		var req_data: Dictionary = _pending_requests[request_id]
		var promise_to_reject: Promise = req_data.promise
		if promise_to_reject.state == Promise.State.PENDING:
			var reason: Dictionary = {"code": error_code, "message": error_message}
			Log.error(
				"Rejecting internal Firebase RTDB promise",
				{"req_id": request_id, "operation": req_data.operation, "reason": reason},
				[Log.TAG_FIREBASE, Log.TAG_ERROR]
			)
			promise_to_reject.reject(reason)
		# No else needed, promise.reject handles already settled state
	else:
		Log.warning(
			"Received error for unknown or timed-out RTDB request_id.",
			{"req_id": request_id, "code": error_code, "msg": error_message},
			[Log.TAG_FIREBASE]
		)


#-----------------------------------------------------------------------------#
# C++ Signal Handlers for Requests                                            #
#-----------------------------------------------------------------------------#


func _on_get_value_completed(request_id: int, _key: String, value: Variant) -> void:
	_resolve_request(request_id, value)


func _on_get_value_error(
	request_id: int, _key: String, error_code: String, error_message: String
) -> void:
	_reject_request(request_id, error_code, error_message)


func _on_set_value_completed(request_id: int, success: bool, error_message: String) -> void:
	if success:
		_resolve_request(request_id, true)  # Resolve with true for success
	else:
		_reject_request(request_id, "SET_VALUE_FAILED", error_message)


func _on_push_and_update_completed(
	request_id: int, push_id: String, success: bool, error_message: String
) -> void:
	if success:
		_resolve_request(request_id, push_id)  # Resolve with the new push_id
	else:
		_reject_request(request_id, "PUSH_UPDATE_FAILED", error_message)


func _on_remove_value_completed(request_id: int, success: bool, error_message: String) -> void:
	if success:
		_resolve_request(request_id, true)  # Resolve with true for success
	else:
		_reject_request(request_id, "REMOVE_VALUE_FAILED", error_message)


func _on_query_completed(request_id: int, _key: String, value: Variant) -> void:
	_resolve_request(request_id, value)


func _on_query_error(
	request_id: int, _key: String, error_code: String, error_message: String
) -> void:
	_reject_request(request_id, error_code, error_message)


func _on_transaction_completed(
	request_id: int, _key: String, value: Variant, success: bool, error_message: String
) -> void:
	if success:
		_resolve_request(request_id, value)  # Resolve with the final value from transaction
	else:
		_reject_request(request_id, "TRANSACTION_FAILED", error_message)


#-----------------------------------------------------------------------------#
# C++ Signal Handlers for Real-time Listeners & Status                        #
#-----------------------------------------------------------------------------#


func _on_child_added(key: String, value: Variant) -> void:
	Log.debug(
		"[RTDB LISTENER] Child Added",
		{"key": key, "value_type": typeof(value)},
		[Log.TAG_FIREBASE, Log.TAG_EVENT]
	)
	# Potentially emit a Godot signal here for other parts of the game to react
	# emit_signal("rtdb_child_added", key, value)


func _on_child_changed(key: String, value: Variant) -> void:
	Log.debug(
		"[RTDB LISTENER] Child Changed",
		{"key": key, "value_type": typeof(value)},
		[Log.TAG_FIREBASE, Log.TAG_EVENT]
	)
	# emit_signal("rtdb_child_changed", key, value)


func _on_child_moved(key: String, value: Variant) -> void:  # Assuming previous_sibling might be added to C++ later
	Log.debug(
		"[RTDB LISTENER] Child Moved",
		{"key": key, "value_type": typeof(value)},
		[Log.TAG_FIREBASE, Log.TAG_EVENT]
	)
	# emit_signal("rtdb_child_moved", key, value, previous_sibling_key_if_any)


func _on_child_removed(key: String, value: Variant) -> void:  # Value might be null or previous value depending on SDK
	Log.debug(
		"[RTDB LISTENER] Child Removed",
		{"key": key, "value_type": typeof(value)},
		[Log.TAG_FIREBASE, Log.TAG_EVENT]
	)
	# emit_signal("rtdb_child_removed", key, value)


func _on_connection_state_changed(connected: bool) -> void:
	Log.info(
		"Firebase RTDB connection state changed.",
		{"connected": connected},
		[Log.TAG_FIREBASE, Log.TAG_NETWORK]
	)
	# This could be used to update UI or retry pending operations if desired.


func _on_db_error(code: String, message: String) -> void:
	Log.error(
		"General Firebase RTDB Error received from C++ module.",
		{"code": code, "message": message},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	# This is for unhandled errors from the C++ side, not specific request failures.


#-----------------------------------------------------------------------------#
# Public DataBackend API Implementation                                       #
#-----------------------------------------------------------------------------#


func get_data(p_path: Array[Variant], key: String) -> Variant:  # Returns Variant (can be null on error/timeout)
	if not is_available():
		Log.error(
			"Firebase not available for get_data.",
			{"path": p_path, "key": key},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	var full_path: Array = p_path.duplicate()  # Ensure it's a new array
	if not key.is_empty():
		full_path.append(key)

	if full_path.is_empty():
		Log.error("get_data requires a non-empty path.", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR])
		return null

	Log.debug(
		"Requesting get_data from Firebase RTDB.",
		{"path": full_path},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)
	var promise: Promise = _make_internal_request(Callable(db, "get_value_async"), full_path)
	var promise_result: Variant = await promise  # Await the promise to settle (fulfill, reject, or timeout)

	if promise.state == Promise.State.FULFILLED:
		Log.debug(
			"Firebase get_data fulfilled.",
			{"path": full_path, "value_type": typeof(promise.value)},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		return promise.value
	else:  # REJECTED or TIMED_OUT
		Log.error(
			"Firebase get_data failed or timed out.",
			{
				"path": full_path,
				"state": Promise.State.keys()[promise.state],
				"reason": promise.rejection_reason
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null


func set_data(p_path: Array[Variant], key: String, data_to_set: Variant) -> bool:
	if not is_available():
		Log.error(
			"Firebase not available for set_data.",
			{"path": p_path, "key": key},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	var full_path: Array = p_path.duplicate()
	if not key.is_empty():
		full_path.append(key)

	if full_path.is_empty():
		Log.error("set_data requires a non-empty path.", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR])
		return false

	Log.debug(
		"Requesting set_data to Firebase RTDB.",
		{"path": full_path, "data_type": typeof(data_to_set)},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)
	var promise: Promise = _make_internal_request(
		Callable(db, "set_value_async"), full_path, [data_to_set]
	)
	await promise  # Await settlement

	if promise.state == Promise.State.FULFILLED:
		Log.debug(
			"Firebase set_data fulfilled (Success).",
			{"path": full_path},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		return true  # C++ signal resolves with true for success
	else:
		Log.error(
			"Firebase set_data failed or timed out.",
			{
				"path": full_path,
				"state": Promise.State.keys()[promise.state],
				"reason": promise.rejection_reason
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false


func push_data(p_path: Array[Variant], data_to_push: Variant) -> String:  # Returns new push ID or empty string
	if not is_available():
		Log.error(
			"Firebase not available for push_data.",
			{"path": p_path},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return ""

	if not data_to_push is Dictionary:  # Firebase push typically expects a dictionary
		Log.error(
			"push_data to Firebase usually expects Dictionary data.",
			{"path": p_path, "type_provided": typeof(data_to_push)},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		# Allow if C++ module handles other types, but log warning.
		# return "" # Strict: uncomment to enforce Dictionary

	Log.debug(
		"Requesting push_data to Firebase RTDB.",
		{"path": p_path, "data_type": typeof(data_to_push)},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)
	var promise: Promise = _make_internal_request(
		Callable(db, "push_and_update_async"), p_path, [data_to_push]
	)
	await promise  # Await settlement

	if promise.state == Promise.State.FULFILLED:
		var push_id: String = promise.value if promise.value is String else ""
		Log.debug(
			"Firebase push_data fulfilled.",
			{"path": p_path, "push_id": push_id},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		return push_id
	else:
		Log.error(
			"Firebase push_data failed or timed out.",
			{
				"path": p_path,
				"state": Promise.State.keys()[promise.state],
				"reason": promise.rejection_reason
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return ""


func remove_data(p_path: Array[Variant], key: String) -> bool:
	if not is_available():
		Log.error(
			"Firebase not available for remove_data.",
			{"path": p_path, "key": key},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	var full_path: Array = p_path.duplicate()
	if not key.is_empty():
		full_path.append(key)

	if full_path.is_empty():
		Log.error("remove_data requires a non-empty path.", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR])
		return false

	Log.debug(
		"Requesting remove_data from Firebase RTDB.",
		{"path": full_path},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)
	var promise: Promise = _make_internal_request(Callable(db, "remove_value_async"), full_path)
	await promise  # Await settlement

	if promise.state == Promise.State.FULFILLED:
		Log.debug(
			"Firebase remove_data fulfilled (Success).",
			{"path": full_path},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		return true
	else:
		Log.error(
			"Firebase remove_data failed or timed out.",
			{
				"path": full_path,
				"state": Promise.State.keys()[promise.state],
				"reason": promise.rejection_reason
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false


#-----------------------------------------------------------------------------#
# Public Listener Management Methods                                          #
#-----------------------------------------------------------------------------#


func start_listening(path_array: Array[Variant]) -> void:
	if not is_available():
		Log.error(
			"Firebase not available to start listening at path.",
			{"path": path_array},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return
	if not path_array is Array:
		Log.error(
			"Invalid path type for start_listening. Must be Array.",
			{"path": path_array, "type": typeof(path_array)},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return
	if path_array.is_empty():
		Log.error(
			"start_listening requires a non-empty path array.",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	Log.info(
		"Requesting C++ module to start listening at path.",
		{"path": path_array},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)
	db.add_listener_at_path(path_array)


func stop_listening(path_array: Array[Variant]) -> void:
	if not is_available():
		Log.error(
			"Firebase not available to stop listening at path.",
			{"path": path_array},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return
	if not path_array is Array:
		Log.error(
			"Invalid path type for stop_listening. Must be Array.",
			{"path": path_array, "type": typeof(path_array)},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return
	if path_array.is_empty():
		Log.error(
			"stop_listening requires a non-empty path array.", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	Log.info(
		"Requesting C++ module to stop listening at path.",
		{"path": path_array},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)
	db.remove_listener_at_path(path_array)


#-----------------------------------------------------------------------------#
# Wrappers for Other Asynchronous Functions (Query, Transaction, Timestamp)   #
#-----------------------------------------------------------------------------#


func query_data(p_path: Array[Variant], query_params: Dictionary) -> Variant:  # Returns Variant (data or null)
	if not is_available():
		Log.error(
			"Firebase not available for query_data.",
			{"path": p_path},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	Log.debug(
		"Requesting query_data from Firebase RTDB.",
		{"path": p_path, "params": query_params},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)
	var promise: Promise = _make_internal_request(
		Callable(db, "query_ordered_data_async"), p_path, [query_params]
	)
	await promise  # Await settlement

	if promise.state == Promise.State.FULFILLED:
		Log.debug(
			"Firebase query_data fulfilled.",
			{"path": p_path, "params": query_params, "value_type": typeof(promise.value)},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		return promise.value
	else:
		Log.error(
			"Firebase query_data failed or timed out.",
			{
				"path": p_path,
				"params": query_params,
				"state": Promise.State.keys()[promise.state],
				"reason": promise.rejection_reason
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null


func run_increment_transaction(p_path: Array[Variant], increment_by: int = 1) -> Variant:  # Returns Variant (final value or null)
	if not is_available():
		Log.error(
			"Firebase not available for run_increment_transaction.",
			{"path": p_path},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	Log.debug(
		"Requesting run_increment_transaction on Firebase RTDB.",
		{"path": p_path, "increment_by": increment_by},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)
	var promise: Promise = _make_internal_request(
		Callable(db, "run_transaction_async"), p_path, [increment_by]
	)
	await promise  # Await settlement

	if promise.state == Promise.State.FULFILLED:
		Log.debug(
			"Firebase run_increment_transaction fulfilled.",
			{"path": p_path, "new_value_type": typeof(promise.value)},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		return promise.value
	else:
		Log.error(
			"Firebase run_increment_transaction failed or timed out.",
			{
				"path": p_path,
				"state": Promise.State.keys()[promise.state],
				"reason": promise.rejection_reason
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null


func set_server_timestamp(p_path: Array[Variant]) -> bool:
	if not is_available():
		Log.error(
			"Firebase not available for set_server_timestamp.",
			{"path": p_path},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false
	if p_path.is_empty():
		Log.error(
			"set_server_timestamp requires a non-empty path.", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	Log.debug(
		"Requesting set_server_timestamp on Firebase RTDB.",
		{"path": p_path},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)
	# Assuming set_server_timestamp_async is like set_value_async regarding its completion signal
	var promise: Promise = _make_internal_request(
		Callable(db, "set_server_timestamp_async"), p_path
	)
	await promise  # Await settlement

	if promise.state == Promise.State.FULFILLED:
		Log.debug(
			"Firebase set_server_timestamp fulfilled (Success).",
			{"path": p_path},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		# The C++ signal for this might resolve with true/false or just indicate completion.
		# Assuming it resolves with 'true' on success like set_value_completed.
		return promise.value if promise.value is bool else true
	else:
		Log.error(
			"Firebase set_server_timestamp failed or timed out.",
			{
				"path": p_path,
				"state": Promise.State.keys()[promise.state],
				"reason": promise.rejection_reason
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false
