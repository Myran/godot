class_name FirebaseServiceBackend
extends DataBackend

# Service-oriented Firebase backend implementation
# Maintains API compatibility while using service-oriented architecture

var _firebase_service: Node
var _database_service: DatabaseService
var _initialized: bool = false
var _backend_instance_id_str: String


func _init() -> void:
	_backend_instance_id_str = str(get_instance_id())
	Log.info(
		"FirebaseServiceBackend _init (Service-Oriented Pattern)",
		{"instance_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)


func initialize() -> bool:
	Log.debug(
		"FirebaseServiceBackend initialize starting... (Service-Oriented Pattern)",
		{"instance_id": _backend_instance_id_str},
		[Log.TAG_DB, Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)

	if _initialized:
		Log.warning(
			"FirebaseServiceBackend already initialized. Emitting startup_completed again.",
			{"instance_id": _backend_instance_id_str},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		call_deferred("emit_signal", "startup_completed")
		return true

	# Use the global FirebaseService autoload
	_firebase_service = FirebaseService

	if not is_instance_valid(_firebase_service):
		Log.error(
			"FirebaseServiceBackend: Global FirebaseService autoload not available",
			{"instance_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	# Wait for Firebase service initialization if not already available
	if not _firebase_service.is_available():
		Log.debug(
			"FirebaseServiceBackend: Waiting for Firebase service initialization...",
			{"instance_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
		)

		# Create a signal completion tracker using a reference type
		var completion_state: Dictionary = {"complete": false, "error": ""}

		var firebase_initialized_handler: Callable = func() -> void:
			completion_state["complete"] = true
		var firebase_error_handler: Callable = func(error: String) -> void:
			completion_state["error"] = error
			completion_state["complete"] = true
			Log.error(
				"FirebaseServiceBackend: Firebase service initialization failed",
				{"error": error, "instance_id": _backend_instance_id_str},
				[Log.TAG_FIREBASE, Log.TAG_ERROR]
			)

		_firebase_service.firebase_initialized.connect(
			firebase_initialized_handler, CONNECT_ONE_SHOT
		)
		_firebase_service.firebase_error.connect(firebase_error_handler, CONNECT_ONE_SHOT)

		# Wait for either success or error signal
		while not completion_state["complete"]:
			await Engine.get_main_loop().process_frame

		# Clean up handlers
		if _firebase_service.firebase_initialized.is_connected(firebase_initialized_handler):
			_firebase_service.firebase_initialized.disconnect(firebase_initialized_handler)
		if _firebase_service.firebase_error.is_connected(firebase_error_handler):
			_firebase_service.firebase_error.disconnect(firebase_error_handler)

		# If there was an error, fail the backend initialization
		if completion_state["error"] != "":
			Log.error(
				"FirebaseServiceBackend initialization failed due to Firebase service error",
				{"error": completion_state["error"], "instance_id": _backend_instance_id_str},
				[Log.TAG_FIREBASE, Log.TAG_ERROR]
			)
			return false

	# Initialize Database service
	_database_service = DatabaseService.new(_firebase_service)

	# Connect database service signals
	if _database_service.value_received.connect(_on_database_value_received) != OK:
		Log.warning(
			"Failed to connect database service value_received signal",
			{"instance_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE]
		)

	_initialized = true
	Log.info(
		"FirebaseServiceBackend initialized successfully (Service-Oriented Pattern)",
		{"instance_id": _backend_instance_id_str},
		[Log.TAG_FIREBASE, Log.TAG_DB]
	)

	call_deferred("emit_signal", "startup_completed")
	return true


func is_available() -> bool:
	return (
		_initialized and is_instance_valid(_database_service) and _database_service.is_available()
	)


# Public API methods - maintain backward compatibility


func get_data(p_path: Array[Variant], key: String) -> Variant:
	if not is_available():
		Log.error(
			"FirebaseServiceBackend: Not available for get_data.",
			{"path": p_path, "key": key, "backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	return await _database_service.get_data(p_path, key)


func set_data(p_path: Array[Variant], key: String, data_to_set: Variant) -> bool:
	if not is_available():
		Log.error(
			"FirebaseServiceBackend: Not available for set_data.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	return await _database_service.set_data(p_path, key, data_to_set)


func push_data(p_path: Array[Variant], data_to_push: Variant) -> String:
	if not is_available():
		Log.error(
			"FirebaseServiceBackend: Not available for push_data.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return ""

	return await _database_service.push_data(p_path, data_to_push)


func remove_data(p_path: Array[Variant], key: String) -> bool:
	if not is_available():
		Log.error(
			"FirebaseServiceBackend: Not available for remove_data.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	return await _database_service.remove_data(p_path, key)


func query_data(p_path: Array[Variant], query_params: Dictionary) -> Variant:
	if not is_available():
		Log.error(
			"FirebaseServiceBackend: Not available for query_data.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	return await _database_service.query_data(p_path, query_params)


func run_increment_transaction(p_path: Array[Variant], increment_by: int = 1) -> Variant:
	if not is_available():
		Log.error(
			"FirebaseServiceBackend: Not available for run_increment_transaction.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	return await _database_service.run_increment_transaction(p_path, increment_by)


func set_server_timestamp(p_path: Array[Variant]) -> bool:
	if not is_available():
		Log.error(
			"FirebaseServiceBackend: Not available for set_server_timestamp.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return false

	return await _database_service.set_server_timestamp(p_path)


func start_listening(path_array: Array[Variant]) -> void:
	if not is_available():
		Log.error(
			"FirebaseServiceBackend: Not available for start_listening.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	_database_service.start_listening(path_array)


func stop_listening(path_array: Array[Variant]) -> void:
	if not is_available():
		Log.error(
			"FirebaseServiceBackend: Not available for stop_listening.",
			{"backend_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	_database_service.stop_listening(path_array)


# Signal handlers


func _on_database_value_received(data: Dictionary) -> void:
	# Forward the signal to maintain backward compatibility
	value_received.emit(data)


# Cleanup


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if not is_instance_valid(Log):
			return

		Log.debug(
			"FirebaseServiceBackend PREDELETE notification (Service-Oriented Pattern)",
			{"instance_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE]
		)

		# Don't queue_free the global FirebaseService autoload
		_database_service = null
		_firebase_service = null
