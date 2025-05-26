# project/data/backends/backend_factory.gd
class_name BackendFactory
extends RefCounted

enum BackendSelection { NONE, LOCAL, FIREBASE }


static func _check_internet_availability(timeout_sec: float = 7.0) -> bool:
	if internet_status == null:
		Log.warning("InternetStatus singleton not found, assuming connected", {}, [Log.TAG_NETWORK])
		return true

	Log.debug("Requesting internet status check", {}, [Log.TAG_NETWORK])
	internet_status.get_status()

	var connection_status: Dictionary = {"available": false, "completed": false}

	var has_internet_callable: Callable = func() -> void:
		connection_status.available = true
		connection_status.completed = true
	var no_internet_callable: Callable = func() -> void:
		connection_status.available = false
		connection_status.completed = true
	var timeout_callable: Callable = func() -> void:
		if not connection_status.completed:
			Log.error(
				"Internet status check timed out after %s seconds" % timeout_sec,
				{},
				[Log.TAG_NETWORK, Log.TAG_ERROR]
			)
			connection_status.available = false
			connection_status.completed = true

	var has_internet_err: int = internet_status.has_internet.connect(
		has_internet_callable, CONNECT_ONE_SHOT
	)
	var no_internet_err: int = internet_status.no_internet.connect(
		no_internet_callable, CONNECT_ONE_SHOT
	)

	if has_internet_err != OK or no_internet_err != OK:
		Log.error(
			"Failed to connect to InternetStatus signals", {}, [Log.TAG_NETWORK, Log.TAG_ERROR]
		)
		return false

	var timeout_timer: Timer = Timer.new()
	timeout_timer.name = "BackendFactoryInternetTimeout"
	Engine.get_main_loop().root.add_child(timeout_timer)
	timeout_timer.wait_time = timeout_sec
	timeout_timer.one_shot = true

	var timeout_err: int = timeout_timer.timeout.connect(
		timeout_callable, ConnectFlags.CONNECT_DEFERRED
	)
	if timeout_err != OK:
		Log.error("Failed to connect timeout timer signal", {}, [Log.TAG_NETWORK, Log.TAG_ERROR])
		timeout_timer.queue_free()
		return false
	timeout_timer.start()

	while not connection_status.completed:
		await Engine.get_main_loop().process_frame

	# Cleanup
	if internet_status.has_internet.is_connected(has_internet_callable):
		internet_status.has_internet.disconnect(has_internet_callable)
	if internet_status.no_internet.is_connected(no_internet_callable):
		internet_status.no_internet.disconnect(no_internet_callable)
	timeout_timer.queue_free()

	var internet_available: bool = connection_status.available
	if internet_available:
		Log.info("Internet connection available", {}, [Log.TAG_NETWORK])
	else:
		Log.warning("Internet connection unavailable or timed out", {}, [Log.TAG_NETWORK])

	return internet_available


static func create_backend() -> DataBackend:
	var selected_backend_type: BackendSelection = BackendSelection.NONE

	if OS.has_feature("editor"):
		Log.info("Running in editor, selecting local data source", {}, [Log.TAG_DB])
		selected_backend_type = BackendSelection.LOCAL
	elif ProjectSettings.get_setting("game/debug/force_local_data", false):
		Log.info("Debug flag forcing local data source", {}, [Log.TAG_DB])
		selected_backend_type = BackendSelection.LOCAL
	else:
		Log.debug("Attempting to use Firebase, checking internet", {}, [Log.TAG_DB])
		var internet_is_available: bool = await _check_internet_availability()

		if internet_is_available:
			Log.info(
				"Internet available, selecting Firebase backend", {}, [Log.TAG_DB, Log.TAG_FIREBASE]
			)
			selected_backend_type = BackendSelection.FIREBASE
		else:
			Log.warning(
				"Internet unavailable, falling back to local data source",
				{},
				[Log.TAG_DB, Log.TAG_FIREBASE]
			)
			selected_backend_type = BackendSelection.LOCAL

	var backend_instance: DataBackend = null

	if selected_backend_type == BackendSelection.FIREBASE:
		backend_instance = create_firebase_backend()
		if backend_instance == null:
			Log.error(
				"Failed to create Firebase backend, falling back to local",
				{},
				[Log.TAG_DB, Log.TAG_ERROR]
			)
			selected_backend_type = BackendSelection.LOCAL

	if selected_backend_type == BackendSelection.LOCAL:
		backend_instance = create_local_backend()

	if backend_instance != null:
		Log.debug(
			"Initializing backend",
			{"instance_id": backend_instance.get_instance_id()},
			[Log.TAG_DB]
		)
		@warning_ignore("redundant_await")
		var init_success: bool = await backend_instance.initialize()
		if init_success:
			Log.info(
				"Backend initialized successfully",
				{"instance_id": backend_instance.get_instance_id()},
				[Log.TAG_DB]
			)
			return backend_instance
		else:
			Log.error("Backend initialization failed", {}, [Log.TAG_DB, Log.TAG_ERROR])
			return null
	else:
		Log.error("Could not create backend instance", {}, [Log.TAG_DB, Log.TAG_ERROR])
		return null


static func create_firebase_backend() -> FirebaseBackend:
	Log.debug("Creating FirebaseBackend instance", {}, [Log.TAG_DB, Log.TAG_FIREBASE])

	# Only essential check: C++ module availability
	if not ClassDB.class_exists("FirebaseDatabase"):
		Log.error(
			"FirebaseDatabase C++ module not available",
			{},
			[Log.TAG_DB, Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	# Direct instantiation with strong typing - no defensive checks needed
	var firebase_backend: FirebaseBackend = FirebaseBackend.new()
	if firebase_backend == null:
		Log.error(
			"Failed to create FirebaseBackend instance",
			{},
			[Log.TAG_DB, Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	Log.info(
		"FirebaseBackend created successfully",
		{"instance_id": firebase_backend.get_instance_id()},
		[Log.TAG_DB, Log.TAG_FIREBASE]
	)
	return firebase_backend


static func create_local_backend(file_path: String = "") -> LocalJSONBackend:
	Log.debug(
		"Creating LocalJSONBackend instance",
		{"custom_file_path": file_path != ""},
		[Log.TAG_DB, Log.TAG_LOCAL]
	)

	# Direct instantiation with strong typing
	var local_backend: LocalJSONBackend = LocalJSONBackend.new(file_path)
	if local_backend == null:
		Log.error(
			"Failed to create LocalJSONBackend instance",
			{},
			[Log.TAG_DB, Log.TAG_LOCAL, Log.TAG_ERROR]
		)
		return null

	Log.info(
		"LocalJSONBackend created successfully",
		{"instance_id": local_backend.get_instance_id()},
		[Log.TAG_DB, Log.TAG_LOCAL]
	)
	return local_backend
