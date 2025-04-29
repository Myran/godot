class_name FirebaseBackend
extends DataBackend

var db: Object = null  # FirebaseDatabase instance
var internet_available: bool = false

func _init():
	Log.info("FirebaseBackend initializing", {}, [Log.TAG_DB, Log.TAG_FIREBASE])

func initialize() -> bool:
	# Check for Firebase availability first
	if not ClassDB.class_exists("FirebaseDatabase"):
		Log.error("Firebase Database not available in ClassDB", {}, [Log.TAG_DB, Log.TAG_FIREBASE])
		return false
		
	# Check internet connectivity
	var internet_check_complete = false
	var internet_status = Engine.get_singleton("InternetStatus")
	
	if internet_status:
		internet_status.has_internet.connect(func(): 
			internet_available = true
			internet_check_complete = true
			Log.info("Internet connection available", {}, [Log.TAG_NETWORK])
		)
		internet_status.no_internet.connect(func():
			internet_available = false
			internet_check_complete = true
			Log.warning("No internet connection", {}, [Log.TAG_NETWORK])
		)
		internet_status.get_status()
		
		# Wait for internet check to complete
		while not internet_check_complete:
			await Engine.get_main_loop().process_frame
	
	# If no internet, we can't use Firebase
	if not internet_available:
		Log.warning("No internet connection, Firebase unavailable", {}, [Log.TAG_DB, Log.TAG_NETWORK])
		return false
	
	# Initialize Firebase
	db = ClassDB.instantiate("FirebaseDatabase")
	
	if not db:
		Log.error("Failed to instantiate FirebaseDatabase", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR])
		return false
		
	# Connect to signals
	db.connect("get_value", Callable(self, "_on_get_value"))
	db.connect("child_changed", Callable(self, "_on_child_changed"))
	db.connect("child_moved", Callable(self, "_on_child_moved"))
	db.connect("child_removed", Callable(self, "_on_child_removed"))
	db.connect("child_added", Callable(self, "_on_child_added"))
	
	Log.info("Firebase backend initialized successfully", {}, [Log.TAG_FIREBASE])
	call_deferred("emit_signal", "startup_completed")
	return true
	
func is_available() -> bool:
	return db != null and internet_available
	
func get_data(path: Array, key: String) -> Variant:
	if not is_available():
		Log.error("Cannot get database value - Firebase not available", {"path": path, "key": key}, [Log.TAG_DB, Log.TAG_ERROR])
		return null
		
	Log.debug("Getting Firebase data", {"path": path, "key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])
	
	# Set DB root
	db.set_db_root(path)
	
	# Get value
	var result = null
	db.get_value([key])
	var received = {"key": null}
	
	# Wait for value to be received via signal
	while received.key != key:
		received = await self.value_received
		result = received.value
		
	Log.debug("Firebase data received", {"path": path, "key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])
	return result
	
func set_data(path: Array, key: String, data: Variant) -> bool:
	if not is_available():
		Log.error("Cannot set database value - Firebase not available", {"path": path, "key": key}, [Log.TAG_DB, Log.TAG_ERROR])
		return false
		
	Log.debug("Setting Firebase data", {"path": path, "key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])
	
	# Prepare path
	var full_path = path.duplicate()
	if not key.is_empty():
		full_path.append(key)
		
	# Set value
	db.set_db_root(full_path.slice(0, -1))
	db.set_value([full_path[-1]], data)
	
	return true
	
func push_data(path: Array, data: Variant) -> String:
	if not is_available():
		Log.error("Cannot push database value - Firebase not available", {"path": path}, [Log.TAG_DB, Log.TAG_ERROR])
		return ""
		
	Log.debug("Pushing Firebase data", {"path": path}, [Log.TAG_DB, Log.TAG_FIREBASE])
	
	# Push child
	db.set_db_root(path)
	var push_id = db.push_child([""])
	
	# Update child data
	db.update_children([push_id], data)
	
	return push_id
	
func remove_data(path: Array, key: String) -> bool:
	if not is_available():
		Log.error("Cannot remove database value - Firebase not available", {"path": path, "key": key}, [Log.TAG_DB, Log.TAG_ERROR])
		return false
		
	Log.debug("Removing Firebase data", {"path": path, "key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])
	
	# Remove value
	db.set_db_root(path)
	db.remove_value([key])
	
	return true
	
# Signal handlers
func _on_get_value(key: String, value: Variant) -> void:
	call_deferred("emit_signal", "value_received", {"key": key, "value": value})
	
func _on_child_changed(key: String, value: Variant) -> void:
	Log.debug("Firebase child changed", {"key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])
	
func _on_child_moved(key: String, value: Variant) -> void:
	Log.debug("Firebase child moved", {"key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])
	
func _on_child_removed(key: String, value: Variant) -> void:
	Log.debug("Firebase child removed", {"key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])
	
func _on_child_added(key: String, value: Variant) -> void:
	Log.debug("Firebase child added", {"key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])
