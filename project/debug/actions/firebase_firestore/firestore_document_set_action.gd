class_name FirestoreDocumentSetAction
extends FirestoreDebugAction

# Test action for setting a Firestore document
# Creates a test document with sample data


func _init() -> void:
	super._init()
	action_name = "test.firestore.document_set"
	action_callable = Callable(self, "execute_document_set")


func execute_document_set() -> bool:
	var result: DebugActionResult = _execute_action_logic({})
	return result.is_success()


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	Log.info("Firestore Document Set Test START", {}, ["debug", "firestore", "test"])

	# Step 1: Check C++ class availability
	if not is_cpp_firestore_available():
		return DebugActionResult.new_failure(
			"FirebaseFirestore C++ class not available",
			"FIRESTORE_CPP_UNAVAILABLE",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	# Step 2: Get C++ instance
	var firestore: Object = get_cpp_firestore()
	if not is_instance_valid(firestore):
		return DebugActionResult.new_failure(
			"Failed to create FirebaseFirestore instance",
			"FIRESTORE_INSTANCE_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	# Step 3: Check for required methods
	if not firestore.has_method("initialize"):
		return DebugActionResult.new_failure(
			"FirebaseFirestore missing initialize method",
			"FIRESTORE_METHOD_MISSING",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	if not firestore.has_method("set_document_async"):
		return DebugActionResult.new_failure(
			"FirebaseFirestore missing set_document_async method",
			"FIRESTORE_METHOD_MISSING",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	# Step 4: Initialize Firestore
	_update_status("Initializing Firestore...")
	firestore.initialize()

	# Give initialization a moment
	await Engine.get_main_loop().process_frame

	# Step 5: Prepare test data
	var collection_name: String = get_test_collection_name()
	var document_id: String = get_test_document_id()
	var test_data: Dictionary = get_test_document_data()

	var document_path: String = collection_name + "/" + document_id

	Log.info(
		"Setting Firestore document",
		{"path": document_path, "data_keys": test_data.keys()},
		["debug", "firestore", "test"]
	)

	# Step 6: Set up signal connection for completion
	var request_id: int = 1001
	var operation_completed: bool = false
	var operation_success: bool = false
	var operation_error: String = ""

	var callable_handler: Callable = func(p_request_id: int, p_success: bool, p_error: String):
		if p_request_id == request_id:
			operation_completed = true
			operation_success = p_success
			operation_error = p_error
			Log.info(
				"Document set completed",
				{"request_id": p_request_id, "success": p_success, "error": p_error},
				["debug", "firestore", "test"]
			)

	if not firestore.document_set_completed.is_connected(callable_handler):
		firestore.document_set_completed.connect(callable_handler)

	# Step 7: Execute set_document_async
	_update_status("Setting document: " + document_path)
	var set_start: int = Time.get_ticks_msec()

	firestore.set_document_async(request_id, document_path, test_data)

	# Step 8: Wait for completion with timeout
	var timeout_ms: int = 10000  # 10 second timeout
	var waited_ms: int = 0

	while not operation_completed and waited_ms < timeout_ms:
		await Engine.get_main_loop().process_frame
		waited_ms += 16  # Approximately 60fps

	var set_duration: int = Time.get_ticks_msec() - set_start

	# Clean up signal connection
	if firestore.document_set_completed.is_connected(callable_handler):
		firestore.document_set_completed.disconnect(callable_handler)

	# Step 9: Evaluate result
	if not operation_completed:
		return DebugActionResult.new_failure(
			"Document set operation timed out after " + str(timeout_ms) + "ms",
			"FIRESTORE_TIMEOUT",
			DebugActionResult.ErrorCategory.TIMEOUT,
			null,
			set_duration,
			action_name,
			{"path": document_path, "timeout_ms": timeout_ms}
		)

	if not operation_success:
		return DebugActionResult.new_failure(
			"Document set failed: " + operation_error,
			"FIRESTORE_SET_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			set_duration,
			action_name,
			{"path": document_path, "error": operation_error}
		)

	var total_duration: int = Time.get_ticks_msec() - start_time

	Log.info(
		"Firestore Document Set Test PASSED",
		{
			"path": document_path,
			"duration_ms": set_duration,
			"total_ms": total_duration,
			"data_keys": test_data.keys()
		},
		["debug", "firestore", "test"]
	)

	return DebugActionResult.new_success(
		"Document set successfully: " + document_path,
		total_duration,
		action_name,
		{
			"path": document_path,
			"collection": collection_name,
			"document_id": document_id,
			"data": test_data,
			"duration_ms": set_duration
		}
	)
