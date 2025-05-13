# File: project/data/backends/firebase_backend.gd
class_name FirebaseBackend
extends DataBackend


# Helper class to emit unique signals for each request
class RequestSignalHelper:  # RefCounted so it's managed by Godot's GC
	signal completed(result_data: Variant)  # Signal to indicate operation completion (success or error)


const DEFAULT_TIMEOUT: float = 10.0  # Default timeout for operations in seconds

# Firebase C++ Database Module Instance
var db: Object = null

# Internal State
var _initialized: bool = false
# Structure: { request_id: int -> { "signal_helper": RequestSignalHelper, "result_data": Variant, "timer_instance_id": int } }
var _pending_direct_awaits: Dictionary = {}
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
				"pending_awaits_count": _pending_direct_awaits.size()
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		_is_being_freed = true  # Set flag to stop further processing

		# Clean up any pending operations and their associated resources
		var request_ids_to_clear: Array[int] = _pending_direct_awaits.keys()  # Iterate over a copy of keys
		for request_id: int in request_ids_to_clear:
			if _pending_direct_awaits.has(request_id):  # Re-check, as emit might modify
				var await_entry: Dictionary = _pending_direct_awaits[request_id]
				var timer_id_to_cancel: Variant = await_entry.get("timer_instance_id")
				var signal_h: RequestSignalHelper = await_entry.get("signal_helper")

				# Attempt to find and free the timer from the scene root
				if timer_id_to_cancel != null and typeof(timer_id_to_cancel) == TYPE_INT:
					var timer_node: Node = instance_from_id(timer_id_to_cancel as int)
					if is_instance_valid(timer_node) and timer_node is Timer:
						Log.debug(
							"FirebaseBackend PREDELETE: Cleaning up timer from root.",
							{
								"timer_id": timer_id_to_cancel,
								"req_id": request_id,
								"backend_id": _backend_instance_id_str
							},
							[Log.TAG_FIREBASE]
						)
						(timer_node as Timer).stop()
						timer_node.queue_free()

				# If a signal_helper is still pending (result_data not set),
				# emit its completed signal with a "cancelled" state to unblock any hanging awaits.
				if is_instance_valid(signal_h) and await_entry.get("result_data") == null:  # Check if not already settled
					var cancel_data: Dictionary = {
						"status": "error",
						"code": "BACKEND_FREED",
						"message": "Backend freed during operation"
					}
					await_entry["result_data"] = cancel_data  # Ensure it's marked as settled for this path
					Log.warning(
						"FirebaseBackend PREDELETE: Emitting completion for pending await.",
						{"req_id": request_id, "backend_id": _backend_instance_id_str},
						[Log.TAG_FIREBASE]
					)
					signal_h.completed.emit(cancel_data)

		_pending_direct_awaits.clear()  # Final clear of the tracking dictionary

		# db is a RefCounted C++ object. Godot handles its reference counting.
		# Setting to null here ensures this GDScript object releases its reference.
		if is_instance_valid(db):
			Log.debug(
				"FirebaseBackend: Releasing C++ db reference on predelete.",
				{"instance_id": _backend_instance_id_str},
				[Log.TAG_FIREBASE]
			)
		db = null  # Release reference


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

	db = ClassDB.instantiate("FirebaseDatabase")
	if not is_instance_valid(db):
		Log.error(
			"Failed to instantiate FirebaseDatabase C++ module.",
			{"instance_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		db = null  # Ensure db is null if instantiation failed
		return false
	Log.debug(
		"FirebaseDatabase C++ instance created.",
		{"db_instance_id": db.get_instance_id(), "backend_id": _backend_instance_id_str},
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


## Checks if the backend is initialized, the C++ db instance is valid, and not being freed.
func is_available() -> bool:
	return _initialized and is_instance_valid(db) and not _is_being_freed


#-----------------------------------------------------------------------------#
# C++ Module Signal Connection                                                #
#-----------------------------------------------------------------------------#


func _connect_signals() -> void:
	if not is_instance_valid(db):
		Log.error(
			"Cannot connect RTDB signals: C++ db instance is null or invalid.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	Log.debug(
		"Connecting Firebase RTDB C++ signals... (DirectAwait Pattern)",
		{"fb_backend_id": _backend_instance_id_str},
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
		if db.is_connected(signal_name, handler_callable):
			Log.debug(
				"RTDB signal '%s' already connected." % signal_name,
				{"backend_id": _backend_instance_id_str},
				[Log.TAG_FIREBASE]
			)
			continue

		var err: Error = db.connect(signal_name, handler_callable, CONNECT_DEFERRED)  # Use CONNECT_DEFERRED for safety
		if err != OK:
			var bound_object_info: String = "InvalidObject"
			if is_instance_valid(handler_callable.get_object()):
				bound_object_info = (
					handler_callable.get_object().get_class()
					+ " (ID: "
					+ str(handler_callable.get_object().get_instance_id())
					+ ")"
				)

			var err_msg := (
				"Failed to connect RTDB signal '%s' to %s::%s. Error: %s"
				% [signal_name, bound_object_info, handler_callable.get_method(), error_string(err)]
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
		"Finished attempting to connect RTDB signals (DirectAwait Pattern).",
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
func _execute_rtdb_operation_and_await(
	cpp_method_name: String,  # Name of the C++ method to call on `db`
	full_path: Array[Variant],  # Database path for the operation
	args: Array = [],  # Additional arguments for the C++ method (after request_id and path)
	timeout_sec: float = DEFAULT_TIMEOUT
) -> Variant:  # Returns a Dictionary: {"status": "ok", "payload": ...} or {"status": "error", "code": ..., "message": ...}
	if _is_being_freed:
		Log.error(
			"FB_Backend: Attempt to execute op while freeing. Aborting.",
			{"method": cpp_method_name, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {
			"status": "error",
			"code": "BACKEND_FREED",
			"message": "Backend instance is deallocating."
		}

	if not is_instance_valid(db):
		Log.error(
			"FB_Backend: DB instance invalid for op.",
			{"method": cpp_method_name, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {"status": "error", "code": "DB_NULL", "message": "Database instance not available."}

	if not full_path is Array:
		Log.error(
			"FB_Backend: Invalid path type for RTDB operation. Must be Array.",
			{"path": full_path, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {"status": "error", "code": "INVALID_PATH_TYPE", "message": "Path must be an Array."}

	var request_id: int = _get_next_request_id()
	var signal_helper := RequestSignalHelper.new()  # Helper object to emit the unique signal
	var timer_instance_id: Variant = null  # To store ObjectID of the Timer

	# Store info needed to correlate C++ callback and manage timeout
	_pending_direct_awaits[request_id] = {
		"signal_helper": signal_helper, "result_data": null, "timer_instance_id": null  # Will be populated by C++ callback or timeout
	}

	var root_node: Node = Engine.get_main_loop().root
	if not is_instance_valid(root_node):
		Log.error(
			"FB_Backend: Root node invalid, cannot create Timer for request.",
			{"req_id": request_id, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		_pending_direct_awaits.erase(request_id)  # Clean up the premature entry
		return {
			"status": "error",
			"code": "TIMER_SETUP_FAIL",
			"message": "Root node unavailable for Timer creation."
		}

	var timeout_timer := Timer.new()
	timeout_timer.name = "FB_DirectTimer_%s_%d" % [_backend_instance_id_str, request_id]  # Make timer name unique
	root_node.add_child(timeout_timer)  # Add timer to the scene tree root
	timer_instance_id = timeout_timer.get_instance_id()  # Get its ObjectID
	_pending_direct_awaits[request_id]["timer_instance_id"] = timer_instance_id  # Store the ObjectID

	timeout_timer.wait_time = timeout_sec
	timeout_timer.one_shot = true

	var timeout_callable := func() -> void:
		# This block executes when the timer fires
		if _is_being_freed:  # Check if backend is already being shut down
			var timer_node_on_free: Timer = instance_from_id(timer_instance_id as int) as Timer
			if is_instance_valid(timer_node_on_free):
				timer_node_on_free.queue_free()
			return

		# Retrieve timer by ID to ensure it's the correct one and still valid
		var timer_node_check: Timer = instance_from_id(timer_instance_id as int) as Timer
		if not is_instance_valid(timer_node_check):  # Timer might have been freed by an early C++ response
			(
				Log
				. debug(
					(
						"FB_Backend: Timeout callable fired, but timer (ID: %s) already freed for req_id: %d."
						% [str(timer_instance_id), request_id]
					),
					{"backend_id": _backend_instance_id_str},
					[Log.TAG_FIREBASE]
				)
			)
			return

		# Check if the request is still pending (i.e., C++ callback hasn't arrived yet)
		if _pending_direct_awaits.has(request_id):
			var await_entry_on_timeout: Dictionary = _pending_direct_awaits[request_id]
			if await_entry_on_timeout.get("result_data") == null:  # Check if not already settled
				var reason_str: String = (
					"Operation '%s' (req_id: %d) timed out after %s seconds"
					% [cpp_method_name, request_id, timeout_sec]
				)
				Log.warning(
					"FB_Backend: TIMEOUT for request.",
					{
						"req_id": request_id,
						"method": cpp_method_name,
						"backend_id": _backend_instance_id_str
					},
					[Log.TAG_FIREBASE, Log.TAG_ERROR]
				)

				var timeout_result: Dictionary = {
					"status": "error", "code": "TIMEOUT", "message": reason_str
				}
				await_entry_on_timeout["result_data"] = timeout_result  # Store the timeout error

				var sig_helper_on_timeout: RequestSignalHelper = (
					await_entry_on_timeout.signal_helper
				)
				if is_instance_valid(sig_helper_on_timeout):
					sig_helper_on_timeout.completed.emit(timeout_result)  # Emit signal with error data to unblock await

		# Ensure timer is freed if it fired (and wasn't already cleaned up)
		if is_instance_valid(timer_node_check) and not timer_node_check.is_queued_for_deletion():
			timer_node_check.queue_free()

	var connect_err: Error = timeout_timer.timeout.connect(timeout_callable, CONNECT_DEFERRED)
	if connect_err != OK:
		Log.error(
			"FB_Backend: Failed to connect timeout timer signal!",
			{
				"req_id": request_id,
				"error": error_string(connect_err),
				"backend_id": _backend_instance_id_str
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		_pending_direct_awaits.erase(request_id)  # Clean up before returning
		if is_instance_valid(timeout_timer):
			timeout_timer.free()  # Free the unusable timer
		return {
			"status": "error",
			"code": "TIMER_SETUP_FAIL",
			"message": "Failed to connect timer signal."
		}

	# Prepare arguments for the C++ call
	var call_args: Array = [request_id, full_path]
	call_args.append_array(args)

	Log.debug(
		"FB_Backend: Executing RTDB operation",
		{
			"req_id": request_id,
			"method": cpp_method_name,
			"path": full_path,
			"timer_id": timer_instance_id,
			"backend_id": _backend_instance_id_str
		},
		[Log.TAG_FIREBASE, Log.TAG_NETWORK]
	)
	db.callv(cpp_method_name, call_args)  # Make the call to the C++ module
	timeout_timer.start()  # Start the timeout timer

	Log.debug(
		"FB_Backend: Awaiting completion signal from helper for req_id %d." % request_id,
		{"backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE]
	)

	# Await the 'completed' signal from the signal_helper object.
	# The argument emitted by signal_helper.completed will be the return value of this await.
	var final_result_data: Variant = await signal_helper.completed

	Log.debug(
		(
			"FB_Backend: Completion signal received or timeout for req_id %d. Result from await: %s"
			% [request_id, str(final_result_data)]
		),
		{"backend_id": _backend_instance_id_str, "result_type": typeof(final_result_data)},
		[Log.TAG_FIREBASE]
	)

	# Entry in _pending_direct_awaits should have been cleaned up by _complete_direct_await or timeout_callable.
	# Add a final check/cleanup for robustness, though ideally it's already gone.
	if _pending_direct_awaits.has(request_id):
		(
			Log
			. warning(
				(
					"FB_Backend: Entry for req_id %d still in _pending_direct_awaits after await. Forcing cleanup."
					% request_id
				),
				{"backend_id": _backend_instance_id_str},
				[Log.TAG_FIREBASE]
			)
		)
		var timer_id_final_cleanup: Variant = _pending_direct_awaits[request_id].get(
			"timer_instance_id"
		)
		if timer_id_final_cleanup != null:
			var timer_node_final_cleanup: Timer = (
				instance_from_id(timer_id_final_cleanup as int) as Timer
			)
			if is_instance_valid(timer_node_final_cleanup):
				timer_node_final_cleanup.queue_free()
		_pending_direct_awaits.erase(request_id)

	# The signal_helper object is RefCounted and will be garbage collected when no longer referenced.
	return final_result_data


## Called by C++ signal handlers (or timeout via its callable) to finalize an operation.
func _complete_direct_await(
	request_id: int,
	result_payload: Variant,
	is_error: bool = false,
	error_code: String = "",
	error_message: String = ""
) -> void:
	if _is_being_freed:
		Log.warning(
			"FB_Backend: _complete_direct_await called while backend freeing.",
			{"req_id": request_id, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE]
		)
		# Attempt to clean up timer if entry still exists
		if _pending_direct_awaits.has(request_id):
			var timer_id_on_free: Variant = _pending_direct_awaits[request_id].get(
				"timer_instance_id"
			)
			if timer_id_on_free != null:
				var timer_node_on_free: Timer = instance_from_id(timer_id_on_free as int) as Timer
				if is_instance_valid(timer_node_on_free):
					timer_node_on_free.queue_free()
			# Do not erase here, let the awaiter clean up if it's still awaiting.
			# Or, if we are sure the awaiter will no longer access it, it can be erased.
			# For safety, we'll let the awaiter's resumption handle final cleanup of the entry.
		return

	if _pending_direct_awaits.has(request_id):
		var await_entry: Dictionary = _pending_direct_awaits[request_id]
		var signal_helper_to_emit: RequestSignalHelper = await_entry.signal_helper
		var timer_id_to_stop: Variant = await_entry.timer_instance_id

		# Stop and free the timer associated with this request, as the operation has now completed.
		if timer_id_to_stop != null and typeof(timer_id_to_stop) == TYPE_INT:
			var timer_node: Node = instance_from_id(timer_id_to_stop as int)
			if is_instance_valid(timer_node) and timer_node is Timer:
				(timer_node as Timer).stop()
				timer_node.queue_free()

		# Check if already settled (e.g., by a timeout that raced with this C++ callback)
		if await_entry.get("result_data") == null:
			var result_for_signal: Dictionary
			if is_error:
				result_for_signal = {
					"status": "error",
					"code": error_code,
					"message": error_message,
					"payload": result_payload
				}
				Log.error(
					"FB_Backend: Completing await with error for req_id %d." % request_id,
					{"error_info": result_for_signal, "backend_id": _backend_instance_id_str},
					[Log.TAG_FIREBASE, Log.TAG_ERROR]
				)
			else:
				result_for_signal = {"status": "ok", "payload": result_payload}
				Log.debug(
					"FB_Backend: Completing await with success for req_id %d." % request_id,
					{
						"payload_type": typeof(result_payload),
						"backend_id": _backend_instance_id_str
					},
					[Log.TAG_FIREBASE]
				)

			await_entry["result_data"] = result_for_signal  # Store result before emitting

			if is_instance_valid(signal_helper_to_emit):
				signal_helper_to_emit.completed.emit(result_for_signal)  # Emit signal WITH the result data
			else:  # Should not happen if entry exists
				(
					Log
					. error(
						(
							"FB_Backend: signal_helper_to_emit is invalid for req_id %d during completion."
							% request_id
						),
						{"backend_id": _backend_instance_id_str},
						[Log.TAG_FIREBASE, Log.TAG_ERROR]
					)
				)
		else:
			(
				Log
				. warning(
					(
						"FB_Backend: Attempt to complete already settled (e.g., by timeout) req_id: %d. Ignoring C++ callback."
						% request_id
					),
					{"backend_id": _backend_instance_id_str},
					[Log.TAG_FIREBASE]
				)
			)
			# The timer (if it caused the settlement) would have already been freed.
			# The _pending_direct_awaits entry will be cleaned up when the original _execute... function resumes.
	else:
		Log.warning(
			(
				"FB_Backend: Received C++ completion for unknown or already cleaned up req_id: %d."
				% request_id
			),
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE]
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
		return result_dict.get("payload") as bool  # C++ signal for set_value_completed sends success (bool) as payload
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
		return result_dict.get("payload") as String  # push_id
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
		return result_dict.get("payload") as bool  # true for success
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
		return result_dict.get("payload") as bool  # C++ signal sends success (bool)
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
