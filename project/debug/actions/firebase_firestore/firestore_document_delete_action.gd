class_name FirestoreDocumentDeleteAction
extends FirestoreDebugAction

# Test action for deleting a Firestore document
# First sets a document, then deletes it, then verifies deletion


func _init() -> void:
	super._init()
	action_name = "test.firestore.document_delete"
	action_callable = Callable(self, "execute_document_delete")


func execute_document_delete() -> bool:
	var result: DebugActionResult = _execute_action_logic({})
	return result.is_success()


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	Log.info("Firestore Document Delete Test START", {}, ["debug", "firestore", "test"])

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
	if not firestore.has_method("delete_document_async"):
		return DebugActionResult.new_failure(
			"FirebaseFirestore missing delete_document_async method",
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

	# Step 4: Set up a document to delete
	var collection_name: String = get_test_collection_name()
	var document_id: String = get_test_document_id()
	var document_path: String = collection_name + "/" + document_id

	var test_data: Dictionary = {"name": "ToDelete", "value": 42}

	# Set document first
	var set_request_id: int = 4001
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
			"Failed to set up document for delete test",
			"FIRESTORE_SETUP_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			set_waited,
			action_name,
			{}
		)

	Log.info(
		"Test document created for deletion",
		{"path": document_path},
		["debug", "firestore", "test"]
	)

	# Step 5: Delete the document
	Log.info("Deleting document...", {"path": document_path}, ["debug", "firestore", "test"])

	var delete_request_id: int = 4002
	var delete_completed: bool = false
	var delete_success: bool = false
	var delete_error: String = ""

	var delete_handler: Callable = func(p_request_id: int, p_success: bool, p_error: String):
		if p_request_id == delete_request_id:
			delete_completed = true
			delete_success = p_success
			delete_error = p_error

	firestore.document_delete_completed.connect(delete_handler)

	_update_status("Deleting document: " + document_path)
	var delete_start: int = Time.get_ticks_msec()

	firestore.delete_document_async(delete_request_id, document_path)

	# Step 6: Wait for completion
	var delete_timeout: int = 5000
	var delete_waited: int = 0
	while not delete_completed and delete_waited < delete_timeout:
		await Engine.get_main_loop().process_frame
		delete_waited += 16

	var delete_duration: int = Time.get_ticks_msec() - delete_start

	firestore.document_delete_completed.disconnect(delete_handler)

	# Step 7: Verify deletion
	if not delete_completed or not delete_success:
		return DebugActionResult.new_failure(
			"Document delete failed: " + delete_error,
			"FIRESTORE_DELETE_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			delete_duration,
			action_name,
			{"path": document_path, "error": delete_error}
		)

	# Step 8: Verify document no longer exists
	var get_request_id: int = 4003
	var get_completed: bool = false
	var get_exists: bool = false

	var get_handler: Callable = func(
		p_request_id: int, p_path: String, p_exists: bool, p_data: Dictionary, p_error: String
	):
		if p_request_id == get_request_id:
			get_completed = true
			get_exists = p_exists

	firestore.document_get_completed.connect(get_handler)
	firestore.get_document_async(get_request_id, document_path)

	var get_timeout: int = 5000
	var get_waited: int = 0
	while not get_completed and get_waited < get_timeout:
		await Engine.get_main_loop().process_frame
		get_waited += 16

	firestore.document_get_completed.disconnect(get_handler)

	# Step 9: Verify deletion
	if not get_completed:
		return DebugActionResult.new_failure(
			"Failed to verify document deletion",
			"FIRESTORE_VERIFICATION_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			delete_duration,
			action_name,
			{}
		)

	if get_exists:
		return DebugActionResult.new_failure(
			"Document still exists after deletion",
			"FIRESTORE_DELETION_FAILED",
			DebugActionResult.ErrorCategory.ASSERTION,
			null,
			delete_duration,
			action_name,
			{"path": document_path}
		)

	var total_duration: int = Time.get_ticks_msec() - start_time

	Log.info(
		"Firestore Document Delete Test PASSED",
		{"path": document_path, "delete_duration_ms": delete_duration, "total_ms": total_duration},
		["debug", "firestore", "test"]
	)

	return DebugActionResult.new_success(
		"Document deleted and verified: " + document_path,
		total_duration,
		action_name,
		{
			"path": document_path,
			"deleted": true,
			"verified_not_exists": true,
			"duration_ms": delete_duration
		}
	)
