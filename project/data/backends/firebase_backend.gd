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

			var err_msg: String = (
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
## This version includes the modified timeout_callable logic.
func _execute_rtdb_operation_and_await(
	cpp_method_name: String,
	full_path: Array[Variant],
	args: Array = [],
	timeout_sec: float = DEFAULT_TIMEOUT
) -> Variant:
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
	var signal_helper: RequestSignalHelper = RequestSignalHelper.new()
	var timer_instance_id: Variant = null

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
		_pending_direct_awaits.erase(request_id)
		return {
			"status": "error",
			"code": "TIMER_SETUP_FAIL",
			"message": "Root node unavailable for Timer creation."
		}

	var timeout_timer: Timer = Timer.new()
	timeout_timer.name = "FB_DirectTimer_%s_%d" % [_backend_instance_id_str, request_id]
	root_node.add_child(timeout_timer)
	timer_instance_id = timeout_timer.get_instance_id()
	_pending_direct_awaits[request_id]["timer_instance_id"] = timer_instance_id

	timeout_timer.wait_time = timeout_sec
	timeout_timer.one_shot = true

	var timeout_callable: Callable = func() -> void:
		if _is_being_freed:
			var timer_node_on_free: Timer = instance_from_id(timer_instance_id as int) as Timer
			if is_instance_valid(timer_node_on_free):
				timer_node_on_free.queue_free()
			return

		var timer_node_check: Timer = instance_from_id(timer_instance_id as int) as Timer
		if not is_instance_valid(timer_node_check):
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

		# Critical check: Is the request still genuinely pending in our tracking?
		if not _pending_direct_awaits.has(request_id):
			(
				Log
				. warning(
					(
						"FB_Backend: Timeout for req_id %d, but entry no longer in _pending_direct_awaits (likely completed by C++)."
						% request_id
					),
					{"backend_id": _backend_instance_id_str},
					[Log.TAG_FIREBASE]
				)
			)
			if (
				is_instance_valid(timer_node_check)
				and not timer_node_check.is_queued_for_deletion()
			):
				timer_node_check.queue_free()  # Clean up this timer as it's no longer needed
			return

		var await_entry_on_timeout: Dictionary = _pending_direct_awaits[request_id]

		# Double-check if `result_data` was set by a racing C++ callback *just before* timeout erased the entry.
		# If `result_data` is already populated, it means the C++ callback won the race to settle.
		if await_entry_on_timeout.get("result_data") != null:
			(
				Log
				. warning(
					(
						"FB_Backend: Timeout for req_id %d, but C++ callback likely just settled it (result_data found). Ignoring timeout action."
						% request_id
					),
					{
						"backend_id": _backend_instance_id_str,
						"existing_result": await_entry_on_timeout.get("result_data")
					},
					[Log.TAG_FIREBASE]
				)
			)
			# The C++ callback is responsible for cleaning the entry from _pending_direct_awaits.
			# If it's still here, _complete_direct_await had an issue or this is a very tight race.
			# For safety, let's ensure this timer gets cleaned.
			if (
				is_instance_valid(timer_node_check)
				and not timer_node_check.is_queued_for_deletion()
			):
				timer_node_check.queue_free()
			return

		# If we reach here, the timeout is the first to definitively settle the request.
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

		# Store the signal helper, then erase the main entry from _pending_direct_awaits
		var sig_helper_on_timeout: RequestSignalHelper = await_entry_on_timeout.signal_helper
		_pending_direct_awaits.erase(request_id)  # ERASE HERE

		if is_instance_valid(sig_helper_on_timeout):
			sig_helper_on_timeout.completed.emit(timeout_result)

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
		_pending_direct_awaits.erase(request_id)
		if is_instance_valid(timeout_timer):
			timeout_timer.free()
		return {
			"status": "error",
			"code": "TIMER_SETUP_FAIL",
			"message": "Failed to connect timer signal."
		}

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
	db.callv(cpp_method_name, call_args)
	timeout_timer.start()

	Log.debug(
		"FB_Backend: Awaiting completion signal from helper for req_id %d." % request_id,
		{"backend_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE]
	)
	var final_result_data: Variant = await signal_helper.completed

	Log.debug(
		(
			"FB_Backend: Completion signal received or timeout for req_id %d. Result from await: %s"
			% [request_id, str(final_result_data)]
		),
		{"backend_id": _backend_instance_id_str, "result_type": typeof(final_result_data)},
		[Log.TAG_FIREBASE]
	)

	# At this point, the entry in _pending_direct_awaits should have been cleaned up by
	# either _complete_direct_await (if C++ callback won) or the timeout_callable (if timeout won).
	# A final check is mostly for sanity/debugging during development.
	if _pending_direct_awaits.has(request_id):
		(
			Log
			. warning(
				(
					"FB_Backend: Entry for req_id %d STILL in _pending_direct_awaits after await AND settlement. This indicates a logic flaw in cleanup. Force cleaning."
					% request_id
				),
				{
					"backend_id": _backend_instance_id_str,
					"entry_data": _pending_direct_awaits[request_id]
				},
				[Log.TAG_FIREBASE, Log.TAG_ERROR]  # Elevate to error if this happens
			)
		)
		var timer_id_final_cleanup: Variant = _pending_direct_awaits[request_id].get(
			"timer_instance_id"
		)
		if timer_id_final_cleanup != null and typeof(timer_id_final_cleanup) == TYPE_INT:
			var timer_node_final_cleanup: Timer = (
				instance_from_id(timer_id_final_cleanup as int) as Timer
			)
			if is_instance_valid(timer_node_final_cleanup):
				timer_node_final_cleanup.queue_free()
		_pending_direct_awaits.erase(request_id)

	return final_result_data


## Called by C++ signal handlers (or timeout via its callable) to finalize an operation.
## This version ensures the pending request entry is removed *before* signaling completion.
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
		# During predelete, _pending_direct_awaits is cleared more aggressively.
		# Avoid modifying it here if already in that shutdown path.
		return

	if not _pending_direct_awaits.has(request_id):
		(
			Log
			. warning(
				(
					"FB_Backend: Received C++ completion for unknown or already handled/timed_out req_id: %d."
					% request_id
				),
				{"backend_id": _backend_instance_id_str},
				[Log.TAG_FIREBASE]
			)
		)
		return

	var await_entry: Dictionary = _pending_direct_awaits[request_id]
	var signal_helper_to_emit: RequestSignalHelper = await_entry.signal_helper
	var timer_id_to_stop: Variant = await_entry.timer_instance_id

	if timer_id_to_stop != null and typeof(timer_id_to_stop) == TYPE_INT:
		var timer_node: Node = instance_from_id(timer_id_to_stop as int)
		if is_instance_valid(timer_node) and timer_node is Timer:
			(timer_node as Timer).stop()
			timer_node.queue_free()

	if await_entry.get("result_data") != null:
		(
			Log
			. warning(
				(
					"FB_Backend: Attempt to complete (via C++ CB) an already settled (e.g., by timeout) req_id: %d. Ignoring current C++ CB."
					% request_id
				),
				{
					"backend_id": _backend_instance_id_str,
					"existing_result": await_entry.get("result_data")
				},
				[Log.TAG_FIREBASE]
			)
		)
		# If already settled, the entry should have been removed by the settler.
		# If still here, we erase for robustness.
		_pending_direct_awaits.erase(request_id)
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
			"FB_Backend: Completing await with error for req_id %d." % request_id,
			{"error_info": result_for_signal, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
	else:
		result_for_signal = {"status": "ok", "payload": result_payload}
		Log.debug(
			"FB_Backend: Completing await with success for req_id %d." % request_id,
			{"payload_type": typeof(result_payload), "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE]
		)

	# Store the signal helper, then erase the main entry from _pending_direct_awaits
	# This is the "settler cleans" pattern.
	var temp_signal_helper: RequestSignalHelper = signal_helper_to_emit  # Keep a reference before erasing
	_pending_direct_awaits.erase(request_id)  # ERASE HERE, BEFORE EMITTING

	if is_instance_valid(temp_signal_helper):
		temp_signal_helper.completed.emit(result_for_signal)
	else:
		(
			Log
			. error(
				(
					"FB_Backend: signal_helper_to_emit is invalid for req_id %d during completion (after erase)."
					% request_id
				),
				{"backend_id": _backend_instance_id_str},
				[Log.TAG_FIREBASE, Log.TAG_ERROR]
			)
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
