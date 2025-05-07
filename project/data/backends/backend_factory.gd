# project/data/backends/backend_factory.gd
class_name BackendFactory
extends RefCounted

# Forward declare or ensure these classes are loaded/available for type hinting
# If they are in the same directory or autoloads, direct usage is fine.
# Otherwise, you might need:
# const FirebaseBackend = preload("firebase_backend.gd")
# const LocalJSONBackend = preload("local_json_backend.gd")
# const DataBackend = preload("data_backend.gd") # If not implicitly known

enum BackendSelection { NONE, LOCAL, FIREBASE }


static func _check_internet_availability(timeout_sec: float = 7.0) -> bool:
	var internet_status_node: Node = Engine.get_singleton("internet_status")  # More specific type if InternetStatus is a class_name
	if internet_status_node == null:
		Log.warning(
			"InternetStatus singleton not found in BackendFactory. Assuming connected for check.",
			{},
			[Log.TAG_NETWORK]
		)
		return true

	Log.debug("BackendFactory: Requesting internet status check...", {}, [Log.TAG_NETWORK])
	internet_status_node.get_status()

	var internet_available_result: bool = false
	var check_completed: bool = false

	# Use a dictionary to hold connection status to avoid issues with lambda captures if not careful
	var connection_status := {"available": false, "completed": false}

	var has_internet_callable: Callable = func():
		connection_status.available = true
		connection_status.completed = true
	var no_internet_callable: Callable = func():
		connection_status.available = false
		connection_status.completed = true
	var timeout_callable: Callable = func():
		if not connection_status.completed:
			Log.error(
				"BackendFactory: Internet status check timed out after %s seconds" % timeout_sec,
				{},
				[Log.TAG_NETWORK, Log.TAG_ERROR]
			)
			connection_status.available = false
			connection_status.completed = true

	var has_internet_conn_err: Error = internet_status_node.has_internet.connect(
		has_internet_callable, CONNECT_ONE_SHOT
	)
	var no_internet_conn_err: Error = internet_status_node.no_internet.connect(
		no_internet_callable, CONNECT_ONE_SHOT
	)

	if has_internet_conn_err != OK or no_internet_conn_err != OK:
		Log.error(
			"Failed to connect to InternetStatus signals", {}, [Log.TAG_NETWORK, Log.TAG_ERROR]
		)
		# Decide a default behavior, e.g., assume no internet
		return false

	var timeout_timer: Timer = Timer.new()
	timeout_timer.name = "BackendFactoryInternetTimeout"
	Engine.get_main_loop().root.add_child(timeout_timer)
	timeout_timer.wait_time = timeout_sec
	timeout_timer.one_shot = true
	var timeout_conn_err: Error = timeout_timer.timeout.connect(timeout_callable, CONNECT_ONE_SHOT)
	if timeout_conn_err != OK:
		Log.error("Failed to connect timeout timer signal", {}, [Log.TAG_NETWORK, Log.TAG_ERROR])
		timeout_timer.queue_free()
		return false  # Or another default
	timeout_timer.start()

	while not connection_status.completed:
		await Engine.get_main_loop().process_frame

	# Disconnect signals (important for one-shot behavior if re-used)
	if internet_status_node.has_internet.is_connected(has_internet_callable):
		internet_status_node.has_internet.disconnect(has_internet_callable)
	if internet_status_node.no_internet.is_connected(no_internet_callable):
		internet_status_node.no_internet.disconnect(no_internet_callable)
	# Timer will be freed by queue_free if it hasn't fired, or it's already done.
	timeout_timer.queue_free()

	internet_available_result = connection_status.available

	if internet_available_result:
		Log.info(
			"BackendFactory: Internet connection determined to be available.", {}, [Log.TAG_NETWORK]
		)
	else:
		Log.warning(
			"BackendFactory: Internet connection determined to be unavailable or check timed out.",
			{},
			[Log.TAG_NETWORK]
		)

	return internet_available_result


static func create_backend() -> DataBackend:  # Return type is DataBackend or null
	var selected_backend_type: BackendSelection = BackendSelection.NONE
	var internet_is_available: bool = false

	if OS.has_feature("editor"):
		Log.info("Running in editor, selecting local data source", {}, [Log.TAG_DB])
		selected_backend_type = BackendSelection.LOCAL
	elif ProjectSettings.get_setting("game/debug/force_local_data", false):
		Log.info("Debug flag forcing local data source", {}, [Log.TAG_DB])
		selected_backend_type = BackendSelection.LOCAL
	else:
		Log.debug(
			"BackendFactory: Attempting to use Firebase, checking internet...", {}, [Log.TAG_DB]
		)
		internet_is_available = await _check_internet_availability()

		if internet_is_available:
			Log.info(
				"BackendFactory: Internet available, selecting Firebase backend.",
				{},
				[Log.TAG_DB, Log.TAG_FIREBASE]
			)
			selected_backend_type = BackendSelection.FIREBASE
		else:
			Log.warning(
				"BackendFactory: Internet unavailable, falling back to local data source.",
				{},
				[Log.TAG_DB, Log.TAG_FIREBASE]
			)
			selected_backend_type = BackendSelection.LOCAL

	var backend_instance: DataBackend = null
	if selected_backend_type == BackendSelection.FIREBASE:
		backend_instance = create_firebase_backend()
		if backend_instance == null:
			Log.error(
				"Failed to create Firebase backend despite internet, falling back to local.",
				{},
				[Log.TAG_DB, Log.TAG_ERROR]
			)
			selected_backend_type = BackendSelection.LOCAL

	if selected_backend_type == BackendSelection.LOCAL:
		backend_instance = create_local_backend()

	if backend_instance != null:
		Log.debug(
			"BackendFactory: Initializing chosen backend: %s" % backend_instance.get_class(),
			{},
			[Log.TAG_DB]
		)
		var init_success: bool = await backend_instance.initialize()  # initialize is async
		if init_success:
			Log.info(
				(
					"BackendFactory: Successfully initialized backend: %s"
					% backend_instance.get_class()
				),
				{},
				[Log.TAG_DB]
			)
			return backend_instance
		else:
			(
				Log
				. error(
					(
						"BackendFactory: Failed to initialize chosen backend: %s. No backend will be used."
						% backend_instance.get_class()
					),
					{},
					[Log.TAG_DB, Log.TAG_ERROR]
				)
			)
			return null
	else:
		Log.error(
			"BackendFactory: Could not create any backend instance.",
			{},
			[Log.TAG_DB, Log.TAG_ERROR]
		)
		return null


static func create_firebase_backend() -> FirebaseBackend:  # Return type is FirebaseBackend or null
	Log.debug(
		"BackendFactory: Creating Firebase backend instance.", {}, [Log.TAG_DB, Log.TAG_FIREBASE]
	)
	if not ClassDB.class_exists("FirebaseDatabase"):  # Ensure FirebaseDatabase C++ class exists
		Log.error(
			"FirebaseDatabase C++ module class not found. Cannot create Firebase backend.",
			{},
			[Log.TAG_DB, Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null
	# Assuming FirebaseBackend.new() returns a FirebaseBackend typed object
	var fb_backend: FirebaseBackend = FirebaseBackend.new()
	return fb_backend


static func create_local_backend(file_path: String = "") -> LocalJSONBackend:  # Return type is LocalJSONBackend or null
	Log.debug(
		"BackendFactory: Creating local JSON backend instance.",
		{"custom_file_path": file_path != ""},
		[Log.TAG_DB, Log.TAG_LOCAL]
	)
	# Assuming LocalJSONBackend.new() returns a LocalJSONBackend typed object
	var local_backend: LocalJSONBackend = LocalJSONBackend.new(file_path)
	return local_backend
