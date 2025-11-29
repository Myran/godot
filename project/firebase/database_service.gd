class_name DatabaseService
extends RefCounted

# Firebase Database Service - Handles RTDB operations
# Handles all RTDB operations using FirebaseRequest pattern for async operations
# Integrates with Anti-Corruption Layer for clean service boundaries

@warning_ignore("unused_signal")
signal value_received(data: Dictionary)

# Firebase RTDB Listener signals - forwarded from C++ Firebase SDK
@warning_ignore("unused_signal")
signal child_added(key: String, value: Variant)
@warning_ignore("unused_signal")
signal child_changed(key: String, value: Variant)
@warning_ignore("unused_signal")
signal child_removed(key: String, value: Variant)

var _firebase_service: Node
var _is_initialized: bool = false


func _init(firebase_service: Node) -> void:
	_firebase_service = firebase_service
	_is_initialized = true

	# Connect to Firebase service listener signals to forward them up the service stack
	if (
		is_instance_valid(_firebase_service)
		and _firebase_service.has_method("get_database_wrapper")
	):
		var db_wrapper: Object = _firebase_service.get_database_wrapper()
		if is_instance_valid(db_wrapper):
			_connect_listener_signals(db_wrapper)

	Log.info(
		"DatabaseService initialized",
		{"service_id": get_instance_id()},
		[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)


func is_available() -> bool:
	return (
		_is_initialized
		and is_instance_valid(_firebase_service)
		and _firebase_service.is_available()
	)


func get_data(path: Array[Variant], key: String = "") -> Variant:
	if not is_available():
		Log.error(
			"DatabaseService: Not available for get_data",
			{"path": path, "key": key},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	var request: FirebaseRequest = _firebase_service.get_value(path, key)
	var result: Variant = await request.await_completion()

	if result.get("status") == "ok":
		var payload: Variant = result.get("payload")
		Log.debug(
			"DatabaseService: get_data completed successfully",
			{"path": path, "key": key, "value_type": typeof(payload)},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)

		# Emit value_received signal - using basic Dictionary type for Firebase C++ compatibility
		var signal_data: Dictionary = {
			"key": key if not key.is_empty() else (path[-1] if not path.is_empty() else ""),
			"value": payload
		}
		call_deferred("emit_signal", "value_received", signal_data)
		return payload

	Log.error(
		"DatabaseService: get_data failed",
		{"path": path, "key": key, "error": result},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return null


func set_data(path: Array[Variant], key: String, data_to_set: Variant) -> bool:
	if not is_available():
		Log.error(
			"DatabaseService: Not available for set_data",
			{"path": path, "key": key},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	var request: FirebaseRequest = _firebase_service.set_value(path, key, data_to_set)

	Log.debug(
		"DatabaseService: About to await request completion",
		{
			"path": path,
			"key": key,
			"request_id": request.get_request_id() if request else -1,
			"request_valid": is_instance_valid(request)
		},
		[Log.TAG_DB, Log.TAG_FIREBASE, "await_debug"]
	)

	var result: Variant = await request.await_completion()

	Log.debug(
		"DatabaseService: Request await completed",
		{
			"path": path,
			"key": key,
			"request_id": request.get_request_id() if request else -1,
			"result_status": result.get("status", "missing"),
			"result_keys": result.keys()
		},
		[Log.TAG_DB, Log.TAG_FIREBASE, "await_debug"]
	)

	if result.get("status") == "ok":
		var payload: Variant = result.get("payload")
		Log.debug(
			"DatabaseService: set_data completed successfully",
			{"path": path, "key": key},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		return _convert_to_bool(payload)

	Log.error(
		"DatabaseService: set_data failed",
		{"path": path, "key": key, "error": result},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return false


func push_data(path: Array[Variant], data_to_push: Variant) -> String:
	if not is_available():
		Log.error(
			"DatabaseService: Not available for push_data",
			{"path": path},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return ""

	if not data_to_push is Dictionary:
		Log.warning(
			"DatabaseService: push_data usually expects Dictionary",
			{"path": path, "type": typeof(data_to_push)},
			[Log.TAG_FIREBASE]
		)

	var request: FirebaseRequest = _firebase_service.push_data(path, data_to_push)
	var raw_result: Variant = await request.await_completion()

	# CRITICAL SAFETY: Deep copy IMMEDIATELY after Firebase response
	# Firebase C++ SDK returns misaligned memory that causes SIGBUS crashes
	# when accessed by GDScript in GLThread. Deep copy must happen before ANY access.
	var result: Variant = _safe_copy_variant(raw_result)

	if result.get("status") == "ok":
		var push_id: String = str(result.get("payload"))
		Log.debug(
			"DatabaseService: push_data completed successfully",
			{"path": path, "push_id": push_id},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		return push_id

	Log.error(
		"DatabaseService: push_data failed",
		{"path": path, "error": result},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return ""


func remove_data(path: Array[Variant], key: String = "") -> bool:
	if not is_available():
		Log.error(
			"DatabaseService: Not available for remove_data",
			{"path": path, "key": key},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	var request: FirebaseRequest = _firebase_service.remove_value(path, key)
	var result: Variant = await request.await_completion()

	if result.get("status") == "ok":
		var payload: Variant = result.get("payload")
		Log.debug(
			"DatabaseService: remove_data completed successfully",
			{"path": path, "key": key},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		return _convert_to_bool(payload)

	Log.error(
		"DatabaseService: remove_data failed",
		{"path": path, "key": key, "error": result},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return false


func query_data(path: Array[Variant], query_params: Dictionary) -> Variant:
	if not is_available():
		Log.error(
			"DatabaseService: Not available for query_data",
			{"path": path},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	var request: FirebaseRequest = _firebase_service.query_data(path, query_params)
	var result: Variant = await request.await_completion()

	if result.get("status") == "ok":
		var payload: Variant = result.get("payload")
		Log.debug(
			"DatabaseService: query_data completed successfully",
			{"path": path, "query_params": query_params, "result_type": typeof(payload)},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		return payload

	Log.error(
		"DatabaseService: query_data failed",
		{"path": path, "query_params": query_params, "error": result},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return null


func run_increment_transaction(path: Array[Variant], increment_by: int = 1) -> Variant:
	if not is_available():
		Log.error(
			"DatabaseService: Not available for run_increment_transaction",
			{"path": path},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	var request: FirebaseRequest = _firebase_service.run_transaction(path, increment_by)
	var result: Variant = await request.await_completion()

	if result.get("status") == "ok":
		var final_value: Variant = result.get("payload")
		Log.debug(
			"DatabaseService: run_increment_transaction completed successfully",
			{"path": path, "increment_by": increment_by, "final_value": final_value},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		return final_value

	Log.error(
		"DatabaseService: run_increment_transaction failed",
		{"path": path, "increment_by": increment_by, "error": result},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return null


func set_server_timestamp(path: Array[Variant]) -> bool:
	if not is_available():
		Log.error(
			"DatabaseService: Not available for set_server_timestamp",
			{"path": path},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	if path.is_empty():
		Log.error(
			"DatabaseService: set_server_timestamp requires non-empty path",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	var request: FirebaseRequest = _firebase_service.set_server_timestamp(path)
	var result: Variant = await request.await_completion()

	if result.get("status") == "ok":
		var payload: Variant = result.get("payload")
		Log.debug(
			"DatabaseService: set_server_timestamp completed successfully",
			{"path": path},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		return _convert_to_bool(payload)

	Log.error(
		"DatabaseService: set_server_timestamp failed",
		{"path": path, "error": result},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	return false


func start_listening(path: Array[Variant]) -> void:
	if not is_available():
		Log.error(
			"DatabaseService: Not available for start_listening",
			{"path": path},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	if path.is_empty():
		Log.error(
			"DatabaseService: Invalid path for start_listening",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	Log.info("DatabaseService: Starting listener", {"path": path}, [Log.TAG_DB, Log.TAG_FIREBASE])
	_firebase_service.start_listening(path)


func stop_listening(path: Array[Variant]) -> void:
	if not is_available():
		Log.error(
			"DatabaseService: Not available for stop_listening",
			{"path": path},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	if path.is_empty():
		Log.error(
			"DatabaseService: Invalid path for stop_listening",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	Log.info("DatabaseService: Stopping listener", {"path": path}, [Log.TAG_DB, Log.TAG_FIREBASE])
	_firebase_service.stop_listening(path)


# Helper function to convert various types to bool consistently
func _convert_to_bool(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int:
		@warning_ignore("unsafe_cast")
		return bool(value as int)
	if value is float:
		@warning_ignore("unsafe_cast")
		return bool(value as float)
	return false


# Connect to Firebase C++ listener signals and forward them up the service stack
func _connect_listener_signals(db_wrapper: Object) -> void:
	if not is_instance_valid(db_wrapper):
		Log.warning(
			"DatabaseService: Invalid database wrapper for listener signal connection",
			{},
			[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
		)
		return

	# Connect to C++ Firebase SDK listener signals through the database wrapper
	var signals_to_connect: Array[String] = ["child_added", "child_changed", "child_removed"]
	var connected_count: int = 0

	for signal_name: String in signals_to_connect:
		var handler: Callable
		match signal_name:
			"child_added":
				handler = _on_child_added
			"child_changed":
				handler = _on_child_changed
			"child_removed":
				handler = _on_child_removed

		if db_wrapper.has_method("connect_signal"):
			# CRITICAL FIX (task-207): Remove CONNECT_DEFERRED - same fix as firebase_service.gd
			var err: Error = db_wrapper.connect_signal(signal_name, handler, 0)
			if err == OK:
				connected_count += 1
				Log.debug(
					"DatabaseService: Connected listener signal",
					{"signal": signal_name},
					[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
				)
			else:
				Log.error(
					"DatabaseService: Failed to connect listener signal",
					{"signal": signal_name, "error": error_string(err)},
					[Log.TAG_FIREBASE, Log.TAG_ERROR, Log.TAG_INITIALIZATION]
				)

	Log.info(
		"DatabaseService: Listener signal connection complete",
		{"connected": connected_count, "total": signals_to_connect.size()},
		[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)


# Signal handlers - forward C++ Firebase listener signals up the service stack
func _on_child_added(key: String, value: Variant) -> void:
	Log.debug(
		"DatabaseService: Forwarding child_added signal",
		{"key": key, "value_type": typeof(value)},
		[Log.TAG_FIREBASE, Log.TAG_DB]
	)
	child_added.emit(key, value)


func _on_child_changed(key: String, value: Variant) -> void:
	Log.debug(
		"DatabaseService: Forwarding child_changed signal",
		{"key": key, "value_type": typeof(value)},
		[Log.TAG_FIREBASE, Log.TAG_DB]
	)
	child_changed.emit(key, value)


func _on_child_removed(key: String, value: Variant) -> void:
	Log.debug(
		"DatabaseService: Forwarding child_removed signal",
		{"key": key, "value_type": typeof(value)},
		[Log.TAG_FIREBASE, Log.TAG_DB]
	)
	child_removed.emit(key, value)


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
		_:
			# Primitives (int, float, string, bool) are safe to return directly
			return variant
