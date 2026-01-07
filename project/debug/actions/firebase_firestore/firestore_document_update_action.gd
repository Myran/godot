class_name FirestoreDocumentUpdateAction
extends FirestoreDebugAction

# Test action for updating a Firestore document
# First sets a document, then updates specific fields


func _init() -> void:
	super._init()
	action_name = "test.firestore.document_update"
	action_callable = Callable(self, "execute_document_update")


func execute_document_update() -> bool:
	var result: DebugActionResult = _execute_action_logic({})
	return result.is_success()


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	Log.info("Firestore Document Update Test START", {}, ["debug", "firestore", "test"])

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
	if not firestore.has_method("update_document_async"):
		return DebugActionResult.new_failure(
			"FirebaseFirestore missing update_document_async method",
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

	# Step 4: Set up initial document
	var collection_name: String = get_test_collection_name()
	var document_id: String = get_test_document_id()
	var document_path: String = collection_name + "/" + document_id

	var initial_data: Dictionary = {
		"name": "TestPlayer", "level": 10, "score": 500, "is_active": true
	}

	# Set initial document
	var set_request_id: int = 3001
	var set_completed: bool = false
	var set_success: bool = false

	var set_handler: Callable = func(p_request_id: int, p_success: bool, p_error: String):
		if p_request_id == set_request_id:
			set_completed = true
			set_success = p_success

	firestore.document_set_completed.connect(set_handler)
	firestore.set_document_async(set_request_id, document_path, initial_data)

	var set_timeout: int = 5000
	var set_waited: int = 0
	while not set_completed and set_waited < set_timeout:
		await Engine.get_main_loop().process_frame
		set_waited += 16

	firestore.document_set_completed.disconnect(set_handler)

	if not set_completed or not set_success:
		return DebugActionResult.new_failure(
			"Failed to set initial document for update test",
			"FIRESTORE_SETUP_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			set_waited,
			action_name,
			{}
		)

	Log.info("Initial document set", {"path": document_path}, ["debug", "firestore", "test"])

	# Step 5: Update specific fields
	var update_data: Dictionary = {
		"level": 25, "score": 1500, "last_updated": Time.get_unix_time_from_system()  # Update existing field  # Update existing field  # Add new field
	}

	Log.info(
		"Updating document fields",
		{"path": document_path, "updates": update_data.keys()},
		["debug", "firestore", "test"]
	)

	var update_request_id: int = 3002
	var update_completed: bool = false
	var update_success: bool = false
	var update_error: String = ""

	var update_handler: Callable = func(p_request_id: int, p_success: bool, p_error: String):
		if p_request_id == update_request_id:
			update_completed = true
			update_success = p_success
			update_error = p_error

	firestore.document_update_completed.connect(update_handler)

	_update_status("Updating document: " + document_path)
	var update_start: int = Time.get_ticks_msec()

	firestore.update_document_async(update_request_id, document_path, update_data)

	# Step 6: Wait for completion
	var update_timeout: int = 5000
	var update_waited: int = 0
	while not update_completed and update_waited < update_timeout:
		await Engine.get_main_loop().process_frame
		update_waited += 16

	var update_duration: int = Time.get_ticks_msec() - update_start

	firestore.document_update_completed.disconnect(update_handler)

	# Step 7: Verify update by getting the document
	if not update_completed or not update_success:
		return DebugActionResult.new_failure(
			"Document update failed: " + update_error,
			"FIRESTORE_UPDATE_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			update_duration,
			action_name,
			{"path": document_path, "error": update_error}
		)

	# Step 8: Get updated document to verify
	var get_request_id: int = 3003
	var get_completed: bool = false
	var get_data: Dictionary = {}

	var get_handler: Callable = func(
		p_request_id: int, p_path: String, p_exists: bool, p_data: Dictionary, p_error: String
	):
		if p_request_id == get_request_id:
			get_completed = true
			get_data = p_data

	firestore.document_get_completed.connect(get_handler)
	firestore.get_document_async(get_request_id, document_path)

	var get_timeout: int = 5000
	var get_waited: int = 0
	while not get_completed and get_waited < get_timeout:
		await Engine.get_main_loop().process_frame
		get_waited += 16

	firestore.document_get_completed.disconnect(get_handler)

	# Step 9: Verify updates
	if not get_completed:
		return DebugActionResult.new_failure(
			"Failed to retrieve updated document for verification",
			"FIRESTORE_GET_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			update_duration,
			action_name,
			{}
		)

	# Check updated fields
	var verified: bool = true
	var errors: Array = []

	if get_data.get("level") != 25:
		verified = false
		errors.append("level not updated correctly (got " + str(get_data.get("level")) + ")")

	if get_data.get("score") != 1500:
		verified = false
		errors.append("score not updated correctly (got " + str(get_data.get("score")) + ")")

	if get_data.get("last_updated") == null:
		verified = false
		errors.append("last_updated field not added")

	# Check unchanged field remains
	if get_data.get("name") != "TestPlayer":
		verified = false
		errors.append("name field was incorrectly modified")

	if get_data.get("is_active") != true:
		verified = false
		errors.append("is_active field was incorrectly modified")

	if not verified:
		return DebugActionResult.new_failure(
			"Document update verification failed: " + ", ".join(errors),
			"FIRESTORE_UPDATE_VERIFICATION_FAILED",
			DebugActionResult.ErrorCategory.ASSERTION,
			null,
			update_duration,
			action_name,
			{"errors": errors, "retrieved_data": get_data}
		)

	var total_duration: int = Time.get_ticks_msec() - start_time

	Log.info(
		"Firestore Document Update Test PASSED",
		{"path": document_path, "update_duration_ms": update_duration, "total_ms": total_duration},
		["debug", "firestore", "test"]
	)

	return DebugActionResult.new_success(
		"Document updated and verified: " + document_path,
		total_duration,
		action_name,
		{
			"path": document_path,
			"updated_fields": update_data.keys(),
			"final_data": get_data,
			"duration_ms": update_duration
		}
	)
