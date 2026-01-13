class_name BackendFactory
extends RefCounted

enum BackendSelection { NONE, LOCAL, FIREBASE }


static func create_backend() -> DataBackend:
	var selected_backend_type: BackendSelection = BackendSelection.NONE

	var is_editor: bool = OS.has_feature("editor")
	var force_local: bool = ProjectSettings.get_setting("game/debug/force_local_data", false)

	# Task-434: Check debug config metadata for force_local_data flag (Windows RTDB crash workaround)
	# This MUST happen here in backend_factory because DataSource initializes before debug coordinator
	if not force_local:
		var config_metadata: Dictionary = _get_debug_config_metadata()
		force_local = config_metadata.get("force_local_data", false)
		if force_local:
			(
				Log
				. info(
					"Force local data mode enabled via debug config metadata (Task-434 - Windows RTDB workaround)",
					{},
					[Log.TAG_DB]
				)
			)

	Log.info(
		"Backend selection starting",
		{"is_editor": is_editor, "force_local_data": force_local, "platform": OS.get_name()},
		[Log.TAG_DB]
	)

	if is_editor:
		Log.info("Running in editor, selecting local data source", {}, [Log.TAG_DB])
		selected_backend_type = BackendSelection.LOCAL
	elif force_local:
		Log.info("Debug flag forcing local data source", {}, [Log.TAG_DB])
		selected_backend_type = BackendSelection.LOCAL
	else:
		# Unified logic for all platforms: Try Firebase first, fall back to local if it fails
		# Firebase SDK handles network unavailability gracefully with error codes, no need to pre-check internet
		Log.info(
			"Attempting Firebase backend (unified cross-platform logic)",
			{},
			[Log.TAG_DB, Log.TAG_FIREBASE]
		)
		selected_backend_type = BackendSelection.FIREBASE

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
		Log.error("Backend initialization failed", {}, [Log.TAG_DB, Log.TAG_ERROR])
		return null
	Log.error("Could not create backend instance", {}, [Log.TAG_DB, Log.TAG_ERROR])
	return null


static func create_firebase_backend() -> FirebaseServiceBackend:
	Log.debug("Creating FirebaseServiceBackend instance", {}, [Log.TAG_DB, Log.TAG_FIREBASE])

	# Check if FirebaseService autoload is available
	if not is_instance_valid(FirebaseService):
		Log.error(
			"FirebaseService autoload not available",
			{},
			[Log.TAG_DB, Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	var firebase_backend: FirebaseServiceBackend = FirebaseServiceBackend.new()
	if firebase_backend == null:
		Log.error(
			"Failed to create FirebaseServiceBackend instance",
			{},
			[Log.TAG_DB, Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return null

	Log.info(
		"FirebaseServiceBackend created successfully",
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


# Task-434: Read debug config metadata directly for force_local_data flag
# This is needed because DataSource initializes before debug coordinator runs
static func _get_debug_config_metadata() -> Dictionary:
	var config_path: String = _get_debug_config_path()
	if not FileAccess.file_exists(config_path):
		return {}

	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(json_text) != OK:
		return {}

	var data: Dictionary = json.data
	if data.has("metadata"):
		return data.metadata
	return {}


static func _get_debug_config_path() -> String:
	# Match DebugConfigReader logic for finding config file
	if OS.has_feature("mobile"):
		var external_path: String = "user://debug_startup_actions.json"
		if FileAccess.file_exists(external_path):
			return external_path
		return "res://debug_startup_actions.json"
	return "user://debug_startup_actions.json"
