class_name BackendFactory
extends RefCounted

## Backend selection options
enum BackendSelection {
	NONE,
	LOCAL,
	FIREBASE
}

## Create the appropriate data backend based on runtime conditions
## @return A properly initialized DataBackend instance
static func create_backend() -> DataBackend:
	# Always use local data when in editor
	var selected_backend: BackendSelection = BackendSelection.NONE

	if OS.has_feature("editor"):
		Log.info("Running in editor, using local data source", {}, [Log.TAG_DB])
		selected_backend = BackendSelection.LOCAL

	# For non-editor builds, check for debug mode with forced local data
	if ProjectSettings.has_setting("game/debug/force_local_data") and ProjectSettings.get_setting("game/debug/force_local_data", false):
		Log.info("Debug flag forcing local data source", {}, [Log.TAG_DB])
		selected_backend = BackendSelection.LOCAL

	if selected_backend == BackendSelection.NONE:
		# Try to create firebase backend - it will check availability internally
		var firebase_backend_instance: DataBackend = create_firebase_backend()

		# Validate that we got a proper FirebaseBackend instance
		if firebase_backend_instance == null:
			Log.error("Failed to create Firebase backend", {}, [Log.TAG_DB, Log.TAG_ERROR])
			selected_backend = BackendSelection.LOCAL
		else:
			@warning_ignore("redundant_await")
			var firebase_init_result: bool = await firebase_backend_instance.initialize()
			if firebase_init_result:
				Log.info("Firebase backend initialized successfully", {}, [Log.TAG_DB])
				return firebase_backend_instance
			else:
				selected_backend = BackendSelection.LOCAL
				# Fall back to local if Firebase fails
				Log.info("Firebase initialization failed, falling back to local data", {}, [Log.TAG_DB])

	if selected_backend == BackendSelection.LOCAL:
		var local_backend_instance: DataBackend = create_local_backend()

		# Validate that we got a proper LocalJSONBackend instance
		if local_backend_instance == null:
			Log.error("Failed to create local backend", {}, [Log.TAG_DB, Log.TAG_ERROR])
			return null

		# We need the await here since initialize() is async
		@warning_ignore("redundant_await")
		var local_init_result: bool = await local_backend_instance.initialize()

		if not local_init_result:
			Log.error("Local backend initialization failed", {}, [Log.TAG_DB, Log.TAG_ERROR])
			return null

		Log.info("Local backend initialized successfully", {}, [Log.TAG_DB])
		return local_backend_instance

	Log.warning("No backend selection made", {}, [Log.TAG_DB, Log.TAG_WARNING])
	return null
## Create a new Firebase backend
## @return A FirebaseBackend instance or null if creation fails
static func create_firebase_backend() -> DataBackend:
	Log.debug("Creating Firebase backend", {}, [Log.TAG_DB])

	# Try to create the backend instance
	var backend: FirebaseBackend

	# Use a try-catch block to handle potential errors during creation
	var has_error: bool = false

	# Here we can't use try/catch in GDScript, so we'll check for problems after creation
	backend = FirebaseBackend.new()

	if backend == null or not (backend is FirebaseBackend):
		Log.error("Failed to create FirebaseBackend instance", {
			"error": "Creation failed"
		}, [Log.TAG_DB, Log.TAG_ERROR])
		has_error = true

	if has_error:
		return null

	return backend

## Create a new local JSON backend
## @param file_path Optional custom file path for the JSON data
## @return A LocalJSONBackend instance or null if creation fails
static func create_local_backend(file_path: String = "") -> DataBackend:
	Log.debug("Creating local JSON backend", {
		"custom_file_path": file_path != ""
	}, [Log.TAG_DB])

	# Try to create the backend instance
	var backend: LocalJSONBackend

	# Use a try-catch block to handle potential errors during creation
	var has_error: bool = false

	# Here we can't use try/catch in GDScript, so we'll check for problems after creation
	backend = LocalJSONBackend.new(file_path)

	if backend == null or not (backend is LocalJSONBackend):
		Log.error("Failed to create LocalJSONBackend instance", {
			"error": "Creation failed"
		}, [Log.TAG_DB, Log.TAG_ERROR])
		has_error = true

	if has_error:
		return null

	return backend
