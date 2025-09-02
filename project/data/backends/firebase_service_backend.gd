class_name FirebaseServiceBackend
extends DataBackend

# Service-oriented Firebase backend implementation
# Maintains API compatibility while using service-oriented architecture

var _firebase_service: Node
var _database_service: DatabaseService
var _initialized: bool = false
var _backend_instance_id_str: String
var _db_interface: Object

# Public properties for test compatibility
# gdlint: disable=class-definitions-order
var db: Object:
	get:
		return _get_database_interface()


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

	# Use the global FirebaseService autoload - never create direct instances
	_firebase_service = FirebaseService

	if not is_instance_valid(_firebase_service):
		Log.error(
			"FirebaseServiceBackend: Global FirebaseService autoload not available",
			{
				"instance_id": _backend_instance_id_str,
				"platform": OS.get_name(),
				"firebase_service_node": FirebaseService
			},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, Log.TAG_INITIALIZATION]
		)
		return false

	# Ensure Firebase service is available
	if not _firebase_service.is_available():
		Log.info(
			"FirebaseServiceBackend: Firebase service not available, initialization will proceed without it",
			{"instance_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
		)
		# Don't block backend initialization - Firebase may be unavailable in some contexts
	else:
		Log.debug(
			"FirebaseServiceBackend: Firebase service is available",
			{"instance_id": _backend_instance_id_str},
			[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
		)

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


# Get database interface for backward compatibility
func _get_database_interface() -> Object:
	if not is_available():
		return null
	if not _db_interface:
		_db_interface = DatabaseSignalInterface.new(_database_service)
	return _db_interface


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


func query_data(p_path: Array[Variant], query_params: Dictionary[String, Variant]) -> Variant:
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


func _on_database_value_received(data: Dictionary[String, Variant]) -> void:
	# Forward the signal to maintain DataBackend interface compatibility
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


# Database Signal Interface - Provides backward compatibility for test actions
# Supports the test pattern: db.db.connect_signal("child_added", callback)
class DatabaseSignalInterface:
	var _database_service: Object
	# gdlint: disable=class-definitions-order
	var db: DatabaseSignalWrapper

	func _init(database_service: Object) -> void:
		_database_service = database_service
		db = DatabaseSignalWrapper.new(database_service)


# Database Signal Wrapper - The "db.db" part of the interface
class DatabaseSignalWrapper:
	var _database_service: Object

	func _init(database_service: Object) -> void:
		_database_service = database_service

	func connect_signal(signal_name: String, callable: Callable, flags: int = 0) -> Error:
		if not is_instance_valid(_database_service):
			return ERR_INVALID_DATA

		# Connect to DatabaseService signals that forward from C++ Firebase SDK
		match signal_name:
			"child_added":
				return _database_service.child_added.connect(callable, flags)
			"child_changed":
				return _database_service.child_changed.connect(callable, flags)
			"child_removed":
				return _database_service.child_removed.connect(callable, flags)
			_:
				Log.warning(
					"DatabaseSignalWrapper: Unknown signal name",
					{"signal": signal_name},
					[Log.TAG_FIREBASE]
				)
				return ERR_INVALID_PARAMETER

	func is_signal_connected(signal_name: String, callable: Callable) -> bool:
		if not is_instance_valid(_database_service):
			return false

		# Check if signal is connected to DatabaseService
		match signal_name:
			"child_added":
				return _database_service.child_added.is_connected(callable)
			"child_changed":
				return _database_service.child_changed.is_connected(callable)
			"child_removed":
				return _database_service.child_removed.is_connected(callable)
			_:
				return false
