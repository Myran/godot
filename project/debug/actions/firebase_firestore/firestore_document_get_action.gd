class_name FirestoreDocumentGetAction
extends FirestoreDebugAction

# Test action for getting a Firestore document
# First sets a test document, then retrieves it to verify


func _init() -> void:
	super._init()
	action_name = "test.firestore.document_get"
	action_callable = Callable(self, "execute_document_get")


func execute_document_get() -> bool:
	var result: DebugActionResult = _execute_action_logic({})
	return result.is_success()


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	Log.info("Firestore Document Get Test START", {}, ["debug", "firestore", "test"])

	# Step 1: Get C++ instance
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

	# Step 2: Check for required methods
	if not firestore.has_method("get_document_async"):
		return DebugActionResult.new_failure(
			"FirebaseFirestore missing get_document_async method",
			"FIRESTORE_METHOD_MISSING",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	# Step 3: Initialize
	_update_status("Initializing Firestore...")
	firestore.initialize()
	await Engine.get_main_loop().process_frame

	# Step 4: First, SET a test document to retrieve
	var collection_name: String = get_test_collection_name()
	var document_id: String = get_test_document_id()
	var test_data: Dictionary = get_test_document_data()
	var document_path: String = collection_name + "/" + document_id

	Log.info(
		"Setting up test document first...", {"path": document_path}, ["debug", "firestore", "test"]
	)

	var set_request_id: int = 2001
	var set_completed: bool = false
	var set_success: bool = false

	var set_handler: Callable = func(p_request_id: int, p_success: bool, p_error: String):
		if p_request_id == set_request_id:
			set_completed = true
			set_success = p_success

	firestore.document_set_completed.connect(set_handler)
	firestore.set_document_async(set_request_id, document_path, test_data)

	var set_timeout: int = 5000
	var set_waited: int = 0
	while not set_completed and set_waited < set_timeout:
		await Engine.get_main_loop().process_frame
		set_waited += 16

	firestore.document_set_completed.disconnect(set_handler)

	if not set_completed or not set_success:
		return DebugActionResult.new_failure(
			"Failed to set up test document for get test",
			"FIRESTORE_SETUP_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			set_waited,
			action_name,
			{"set_completed": set_completed, "set_success": set_success}
		)

	Log.info(
		"Test document set successfully, now retrieving...",
		{"path": document_path},
		["debug", "firestore", "test"]
	)

	# Step 5: Now GET the document
	var get_request_id: int = 2002
	var get_completed: bool = false
	var get_exists: bool = false
	var get_data: Dictionary = {}
	var get_error: String = ""

	var get_handler: Callable = func(
		p_request_id: int,
		p_document_path: String,
		p_exists: bool,
		p_data: Dictionary,
		p_error: String
	):
		if p_request_id == get_request_id:
			get_completed = true
			get_exists = p_exists
			get_data = p_data
			get_error = p_error
			Log.info(
				"Document get completed",
				{"request_id": p_request_id, "exists": p_exists, "data_keys": p_data.keys()},
				["debug", "firestore", "test"]
			)

	firestore.document_get_completed.connect(get_handler)

	_update_status("Getting document: " + document_path)
	var get_start: int = Time.get_ticks_msec()

	firestore.get_document_async(get_request_id, document_path)

	# Step 6: Wait for completion
	var get_timeout: int = 5000
	var get_waited: int = 0
	while not get_completed and get_waited < get_timeout:
		await Engine.get_main_loop().process_frame
		get_waited += 16

	var get_duration: int = Time.get_ticks_msec() - get_start

	firestore.document_get_completed.disconnect(get_handler)

	# Step 7: Evaluate result
	if not get_completed:
		return DebugActionResult.new_failure(
			"Document get operation timed out",
			"FIRESTORE_TIMEOUT",
			DebugActionResult.ErrorCategory.TIMEOUT,
			null,
			get_duration,
			action_name,
			{"path": document_path}
		)

	if not get_exists:
		return DebugActionResult.new_failure(
			"Document does not exist after set",
			"FIRESTORE_DOCUMENT_NOT_FOUND",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			get_duration,
			action_name,
			{"path": document_path}
		)

	# Verify data integrity
	if get_data.is_empty():
		return DebugActionResult.new_failure(
			"Retrieved document has no data",
			"FIRESTORE_DATA_EMPTY",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			get_duration,
			action_name,
			{"path": document_path}
		)

	# Check key fields match
	var data_matches: bool = true
	var mismatched_fields: Array = []

	for key in test_data.keys():
		if not get_data.has(key):
			data_matches = false
			mismatched_fields.append(key + " (missing)")
		elif get_data[key] != test_data[key]:
			data_matches = false
			mismatched_fields.append(key + " (value mismatch)")

	if not data_matches:
		return DebugActionResult.new_failure(
			"Retrieved data doesn't match set data",
			"FIRESTORE_DATA_MISMATCH",
			DebugActionResult.ErrorCategory.ASSERTION,
			null,
			get_duration,
			action_name,
			{"path": document_path, "mismatched": mismatched_fields}
		)

	var total_duration: int = Time.get_ticks_msec() - start_time

	Log.info(
		"Firestore Document Get Test PASSED",
		{"path": document_path, "get_duration_ms": get_duration, "total_ms": total_duration},
		["debug", "firestore", "test"]
	)

	return DebugActionResult.new_success(
		"Document retrieved successfully: " + document_path,
		total_duration,
		action_name,
		{"path": document_path, "exists": true, "data": get_data, "duration_ms": get_duration}
	)
