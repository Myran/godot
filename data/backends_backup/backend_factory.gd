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
	var firebase_backend = create_firebase_backend()
	@warning_ignore("redundant_await")
	if await firebase_backend.initialize():
		return firebase_backend
		
	# Fall back to local if Firebase fails
	Log.info("Firebase initialization failed, falling back to local data", {}, [Log.TAG_DB])
	var local_backend = create_local_backend()
	@warning_ignore("redundant_await")
	await local_backend.initialize()
	return local_backend
	
## Create a new Firebase backend
static func create_firebase_backend() -> DataBackend:
	return FirebaseBackend.new()
	
## Create a new local JSON backend
static func create_local_backend(file_path: String = "") -> DataBackend:
	return LocalJSONBackend.new(file_path)
