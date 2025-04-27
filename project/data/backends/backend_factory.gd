class_name BackendFactory
extends RefCounted

## Create the appropriate data backend based on runtime conditions
static func create_backend() -> DataBackend:
	# Always use local data when in editor
	if OS.has_feature("editor"):
		Log.info("Running in editor, using local data source", {}, [Log.TAG_DB])
		return create_local_backend()

	# For non-editor builds, check for debug mode with forced local data
	if ProjectSettings.has_setting("game/debug/force_local_data") and ProjectSettings.get_setting("game/debug/force_local_data", false):
		Log.info("Debug flag forcing local data source", {}, [Log.TAG_DB])
		return create_local_backend()

	# Try to create firebase backend - it will check availability internally
	var firebase_backend_instance: DataBackend = create_firebase_backend()
	var firebase_init_result: bool = await firebase_backend_instance.initialize()
	if firebase_init_result:
		return firebase_backend_instance

	# Fall back to local if Firebase fails
	Log.info("Firebase initialization failed, falling back to local data", {}, [Log.TAG_DB])
	var local_backend_instance: DataBackend = create_local_backend()
	# We need the await here since initialize() is async
	var local_init_result: bool = await local_backend_instance.initialize()
	return local_backend_instance

## Create a new Firebase backend
static func create_firebase_backend() -> DataBackend:
	return FirebaseBackend.new() as DataBackend

## Create a new local JSON backend
static func create_local_backend(file_path: String = "") -> DataBackend:
	return LocalJSONBackend.new(file_path) as DataBackend
