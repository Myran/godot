class_name FirebaseBackend
extends DataBackend


# Define the request class first
class FirebaseRequest:
	var key: String
	var completed: bool
	var value: Variant
	var start_time: float

	func _init(p_key: String) -> void:
		key = p_key
		completed = false
		value = null
		start_time = Time.get_unix_time_from_system()


# Firebase connection objects
var db: Object = null  # FirebaseDatabase instance
var internet_available: bool = false
var auth: Object = null

# Request tracking with explicit typing
var _pending_requests: Dictionary = {}  # Dictionary<int, FirebaseRequest>
var _next_request_id: int = 0


func _init() -> void:
	Log.info("FirebaseBackend initializing", {}, [Log.TAG_DB, Log.TAG_FIREBASE])


func initialize() -> bool:
	# Check for Firebase availability first
	if not ClassDB.class_exists("FirebaseDatabase"):
		Log.error("Firebase Database not available in ClassDB", {}, [Log.TAG_DB, Log.TAG_FIREBASE])
		return false

	# Check internet connectivity
	#var internet_status: Object = Engine.get_singleton("InternetStatus")

	# Create a reference to capture instead of a primitive
	var check_status: Dictionary = {"complete": false}

	if internet_status != null:
		internet_status.has_internet.connect(
			func() -> void:
				internet_available = true
				check_status.complete = true
				Log.info("Internet connection available", {}, [Log.TAG_NETWORK])
		)
		internet_status.no_internet.connect(
			func() -> void:
				internet_available = false
				check_status.complete = true
				Log.warning("No internet connection", {}, [Log.TAG_NETWORK])
		)
		internet_status.get_status()

		# Wait for internet check to complete
		while not check_status.complete:
			@warning_ignore("redundant_await")
			await Engine.get_main_loop().process_frame

	# If no internet, we can't use Firebase
	if not internet_available:
		Log.warning(
			"No internet connection, Firebase unavailable", {}, [Log.TAG_DB, Log.TAG_NETWORK]
		)
		return false

	# Initialize Firebase
	db = ClassDB.instantiate("FirebaseDatabase")

	if db == null:
		Log.error("Failed to instantiate FirebaseDatabase", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR])
		return false

	# Connect to signals - just once at initialization with explicit Callable types
	db.connect("get_value", Callable(self, "_on_get_value"))
	db.connect("child_changed", Callable(self, "_on_child_changed"))
	db.connect("child_moved", Callable(self, "_on_child_moved"))
	db.connect("child_removed", Callable(self, "_on_child_removed"))
	db.connect("child_added", Callable(self, "_on_child_added"))

	# Connect to our signal handler for value_received
	self.value_received.connect(Callable(self, "_on_value_received"))

	Log.info("Firebase backend initialized successfully", {}, [Log.TAG_FIREBASE])
	call_deferred("emit_signal", "startup_completed")
	return true


func is_available() -> bool:
	return db != null and internet_available


func get_data(p_path: Array[Variant], key: String) -> Variant:
	if not is_available():
		Log.error(
			"Cannot get database value - Firebase not available",
			{"path": p_path, "key": key},
			[Log.TAG_DB, Log.TAG_ERROR]
		)
		return null

	Log.debug("Getting Firebase data", {"path": p_path, "key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])

	# Set DB root
	db.set_db_root(p_path)

	# Create request ID and register this request
	var request_id: int = _next_request_id
	_next_request_id += 1

	# Store request information using the strongly typed FirebaseRequest class
	var request: FirebaseRequest = FirebaseRequest.new(key)
	_pending_requests[request_id] = request
	Log.debug(
		"Sending Firebase request",
		{"db_root": "/".join(p_path), "key": key, "full_path": "/".join(p_path) + "/" + key}  # Join array elements with "/"
	)

	# Send the request to Firebase
	db.get_value([key])

	# Wait for value to be received with timeout
	var timeout: float = 10.0  # 10 second timeout

	while _pending_requests.has(request_id) and not _pending_requests[request_id].completed:
		# Check for timeout
		var current_request: FirebaseRequest = _pending_requests[request_id]
		if Time.get_unix_time_from_system() - current_request.start_time > timeout:
			Log.error(
				"Timeout waiting for Firebase data",
				{"path": p_path, "key": key, "timeout_seconds": timeout},
				[Log.TAG_DB, Log.TAG_FIREBASE, Log.TAG_ERROR]
			)
			_pending_requests.erase(request_id)
			return null

		# Wait a frame
		@warning_ignore("redundant_await")
		await Engine.get_main_loop().process_frame

	# Get the result and clean up
	var result: Variant = null
	if _pending_requests.has(request_id):
		var completed_request: FirebaseRequest = _pending_requests[request_id]
		result = completed_request.value
		_pending_requests.erase(request_id)
		Log.debug(
			"Firebase data received", {"path": p_path, "key": key, 'Result': result}, [Log.TAG_DB, Log.TAG_FIREBASE]
		)
	else:
		Log.error(
			"Failed to get Firebase data",
			{"path": p_path, "key": key},
			[Log.TAG_DB, Log.TAG_FIREBASE, Log.TAG_ERROR]
		)

	return result


# Centralized handler for value_received signal with strongly typed parameter
func _on_value_received(data: Dictionary) -> void:
	# Let the type system enforce correctness - will crash if types don't match
	var key: String = data.key  # Must be String or will crash
	var value: Variant = data.value

	# Find requests waiting for this key
	var completed_requests: Array[int] = []

	for request_id: int in _pending_requests.keys():
		var request: FirebaseRequest = _pending_requests[request_id]
		if request.key == key:
			request.value = value
			request.completed = true
			completed_requests.append(request_id)

	# We don't remove the requests here, as the get_data function
	# needs to process the result before removal


func set_data(p_path: Array[Variant], key: String, data: Variant) -> bool:
	if not is_available():
		Log.error(
			"Cannot set database value - Firebase not available",
			{"path": p_path, "key": key},
			[Log.TAG_DB, Log.TAG_ERROR]
		)
		return false

	Log.debug("Setting Firebase data", {"path": p_path, "key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])

	# Prepare path
	var full_path: Array[Variant] = []
	for item: Variant in p_path:
		full_path.append(item)

	if not key.is_empty():
		full_path.append(key)

	# Set value
	if full_path.size() > 1:
		var root_path: Array[Variant] = []
		for i: int in range(full_path.size() - 1):
			root_path.append(full_path[i])
		db.set_db_root(root_path)
		db.set_value([full_path[-1]], data)
	else:
		db.set_db_root([])
		db.set_value([full_path[0]], data)

	return true


func push_data(p_path: Array[Variant], data: Variant) -> String:
	if not is_available():
		Log.error(
			"Cannot push database value - Firebase not available",
			{"path": p_path},
			[Log.TAG_DB, Log.TAG_ERROR]
		)
		return ""

	Log.debug("Pushing Firebase data", {"path": p_path}, [Log.TAG_DB, Log.TAG_FIREBASE])

	# Push child
	db.set_db_root(p_path)
	var push_id: String = db.push_child([""])

	# Update child data
	db.update_children([push_id], data)

	return push_id


func remove_data(p_path: Array[Variant], key: String) -> bool:
	if not is_available():
		Log.error(
			"Cannot remove database value - Firebase not available",
			{"path": p_path, "key": key},
			[Log.TAG_DB, Log.TAG_ERROR]
		)
		return false

	Log.debug(
		"Removing Firebase data", {"path": p_path, "key": key}, [Log.TAG_DB, Log.TAG_FIREBASE]
	)

	# Remove value
	db.set_db_root(p_path)
	db.remove_value([key])

	return true


# Signal handlers
func _on_get_value(key: String, value: Variant) -> void:
	call_deferred("emit_signal", "value_received", {"key": key, "value": value})


func _on_child_changed(key: String, _value: Variant) -> void:
	Log.debug("Firebase child changed", {"key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])


func _on_child_moved(key: String, _value: Variant) -> void:
	Log.debug("Firebase child moved", {"key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])


func _on_child_removed(key: String, _value: Variant) -> void:
	Log.debug("Firebase child removed", {"key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])


func _on_child_added(key: String, _value: Variant) -> void:
	Log.debug("Firebase child added", {"key": key}, [Log.TAG_DB, Log.TAG_FIREBASE])
