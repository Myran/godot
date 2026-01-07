class_name FirestoreCollectionQueryAction
extends FirestoreDebugAction

# Test action for querying Firestore collections
# Creates multiple documents, then queries with filters


func _init() -> void:
	super._init()
	action_name = "test.firestore.collection_query"
	action_callable = Callable(self, "execute_collection_query")


func execute_collection_query() -> bool:
	var result: DebugActionResult = _execute_action_logic({})
	return result.is_success()


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	Log.info("Firestore Collection Query Test START", {}, ["debug", "firestore", "test"])

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
	if not firestore.has_method("query_collection_async"):
		return DebugActionResult.new_failure(
			"FirebaseFirestore missing query_collection_async method",
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

	# Step 4: Create test collection with multiple documents
	var collection_name: String = get_test_collection_name()
	var test_docs: Array = [
		{"id": "doc1", "data": {"name": "Player1", "score": 100, "level": 5, "active": true}},
		{"id": "doc2", "data": {"name": "Player2", "score": 200, "level": 10, "active": true}},
		{"id": "doc3", "data": {"name": "Player3", "score": 150, "level": 7, "active": false}},
		{"id": "doc4", "data": {"name": "Player4", "score": 300, "level": 15, "active": true}}
	]

	# Set up all test documents
	var setup_errors: Array = []
	for doc in test_docs:
		var doc_path: String = collection_name + "/" + doc.id
		var req_id: int = 5000 + int(doc.id.trim_prefix("doc"))
		var completed: bool = false
		var success: bool = false

		var handler: Callable = func(p_request_id: int, p_success: bool, p_error: String):
			if p_request_id == req_id:
				completed = true
				success = p_success

		firestore.document_set_completed.connect(handler)
		firestore.set_document_async(req_id, doc_path, doc.data)

		var timeout: int = 3000
		var waited: int = 0
		while not completed and waited < timeout:
			await Engine.get_main_loop().process_frame
			waited += 16

		firestore.document_set_completed.disconnect(handler)

		if not completed or not success:
			setup_errors.append(doc.id)

	if setup_errors.size() > 0:
		return DebugActionResult.new_failure(
			"Failed to set up test documents: " + ", ".join(setup_errors),
			"FIRESTORE_SETUP_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{"failed_docs": setup_errors}
		)

	Log.info(
		"Test collection created",
		{"collection": collection_name, "doc_count": test_docs.size()},
		["debug", "firestore", "test"]
	)

	# Give Firestore a moment to index
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame

	# Step 5: Query collection with filter (score >= 150)
	var query_request_id: int = 5100
	var query_completed: bool = false
	var query_success: bool = false
	var query_documents: Array = []
	var query_error: String = ""

	var query_handler: Callable = func(
		p_request_id: int, p_success: bool, p_documents: Array, p_error: String
	):
		if p_request_id == query_request_id:
			query_completed = true
			query_success = p_success
			query_documents = p_documents
			query_error = p_error

	firestore.query_completed.connect(query_handler)

	_update_status("Querying collection: " + collection_name)
	var query_start: int = Time.get_ticks_msec()

	# Query: score >= 150, limit 3 results
	var query_params: Dictionary = {
		"where": {"field": "score", "op": ">=", "value": 150}, "limit": 3
	}

	Log.info(
		"Executing query",
		{"collection": collection_name, "params": query_params},
		["debug", "firestore", "test"]
	)

	firestore.query_collection_async(query_request_id, collection_name, query_params)

	# Step 6: Wait for completion
	var query_timeout: int = 8000  # Queries may take longer
	var query_waited: int = 0
	while not query_completed and query_waited < query_timeout:
		await Engine.get_main_loop().process_frame
		query_waited += 16

	var query_duration: int = Time.get_ticks_msec() - query_start

	firestore.query_completed.disconnect(query_handler)

	# Step 7: Evaluate result
	if not query_completed:
		return DebugActionResult.new_failure(
			"Query operation timed out",
			"FIRESTORE_TIMEOUT",
			DebugActionResult.ErrorCategory.TIMEOUT,
			null,
			query_duration,
			action_name,
			{"collection": collection_name}
		)

	if not query_success:
		return DebugActionResult.new_failure(
			"Query failed: " + query_error,
			"FIRESTORE_QUERY_FAILED",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			query_duration,
			action_name,
			{"error": query_error}
		)

	# Step 8: Verify query results
	if query_documents.size() == 0:
		return DebugActionResult.new_failure(
			"Query returned no documents",
			"FIRESTORE_QUERY_EMPTY",
			DebugActionResult.ErrorCategory.ASSERTION,
			null,
			query_duration,
			action_name,
			{"collection": collection_name}
		)

	# Check if returned documents match filter (score >= 150)
	var all_match: bool = true
	var invalid_docs: Array = []

	for doc in query_documents:
		if doc.has("data") and doc.data is Dictionary:
			var score: Variant = doc.data.get("score")
			if score == null or score < 150:
				all_match = false
				invalid_docs.append({"doc": doc, "score": score})

	if not all_match:
		return DebugActionResult.new_failure(
			"Query returned documents that don't match filter",
			"FIRESTORE_QUERY_FILTER_FAILED",
			DebugActionResult.ErrorCategory.ASSERTION,
			null,
			query_duration,
			action_name,
			{"invalid_docs": invalid_docs}
		)

	# Check limit was respected
	if query_documents.size() > 3:
		return DebugActionResult.new_failure(
			"Query returned more documents than limit",
			"FIRESTORE_QUERY_LIMIT_FAILED",
			DebugActionResult.ErrorCategory.ASSERTION,
			null,
			query_duration,
			action_name,
			{"returned": query_documents.size(), "limit": 3}
		)

	var total_duration: int = Time.get_ticks_msec() - start_time

	Log.info(
		"Firestore Collection Query Test PASSED",
		{
			"collection": collection_name,
			"results_count": query_documents.size(),
			"query_duration_ms": query_duration,
			"total_ms": total_duration
		},
		["debug", "firestore", "test"]
	)

	return DebugActionResult.new_success(
		"Collection query successful: " + str(query_documents.size()) + " documents",
		total_duration,
		action_name,
		{
			"collection": collection_name,
			"results": query_documents,
			"count": query_documents.size(),
			"duration_ms": query_duration
		}
	)
