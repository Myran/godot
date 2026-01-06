class_name FirestoreService
extends RefCounted

# Firebase Firestore Service - Handles Cloud Firestore document operations
# Uses FirebaseRequest pattern for async operations
# Supports document CRUD and collection queries

signal document_saved(path: String)
signal document_deleted(path: String)
signal firestore_error(error_code: int, error_message: String)

var _cpp_firestore: Object  # FirebaseFirestore C++ instance
var _is_initialized: bool = false
var _next_request_id: int = 1
var _pending_requests: Dictionary = {}


func _init(cpp_firestore: Object) -> void:
	if not is_instance_valid(cpp_firestore):
		Log.error(
			"FirestoreService: Invalid C++ instance provided", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	_cpp_firestore = cpp_firestore
	_connect_signals()
	_is_initialized = true

	Log.info(
		"FirestoreService initialized",
		{"instance_id": _cpp_firestore.get_instance_id()},
		[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)


func is_available() -> bool:
	return _is_initialized and is_instance_valid(_cpp_firestore)


# === Document CRUD Operations ===


func get_document(path: String) -> Variant:
	"""Get a document by path (e.g., 'users/user123' or 'users/uid/posts/postId')."""
	if not is_available():
		Log.error(
			"FirestoreService: Not available for get_document",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {
			"status": "error", "code": "SERVICE_UNAVAILABLE", "message": "Firestore not available"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.debug(
		"FirestoreService: Starting get_document",
		{"request_id": request_id, "path": path},
		[Log.TAG_FIREBASE]
	)

	_cpp_firestore.get_document_async(request_id, path)

	var result: Variant = await request.await_completion()

	if result.get("status") == "ok":
		Log.info(
			"FirestoreService: get_document completed successfully",
			{
				"request_id": request_id,
				"path": path,
				"exists": result.get("payload", {}).get("exists", false)
			},
			[Log.TAG_FIREBASE]
		)
	else:
		Log.error(
			"FirestoreService: get_document failed",
			{"request_id": request_id, "path": path, "error": result},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)

	return result


func set_document(path: String, data: Dictionary) -> Variant:
	"""Set (create or overwrite) a document at the given path."""
	if not is_available():
		Log.error(
			"FirestoreService: Not available for set_document",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {
			"status": "error", "code": "SERVICE_UNAVAILABLE", "message": "Firestore not available"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.debug(
		"FirestoreService: Starting set_document",
		{"request_id": request_id, "path": path, "data_keys": data.keys()},
		[Log.TAG_FIREBASE]
	)

	_cpp_firestore.set_document_async(request_id, path, data)

	var result: Variant = await request.await_completion()

	if result.get("status") == "ok":
		Log.info(
			"FirestoreService: set_document completed successfully",
			{"request_id": request_id, "path": path},
			[Log.TAG_FIREBASE]
		)
		document_saved.emit(path)
	else:
		Log.error(
			"FirestoreService: set_document failed",
			{"request_id": request_id, "path": path, "error": result},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)

	return result


func update_document(path: String, data: Dictionary) -> Variant:
	"""Update a document (merge with existing data). Document must exist."""
	if not is_available():
		Log.error(
			"FirestoreService: Not available for update_document",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {
			"status": "error", "code": "SERVICE_UNAVAILABLE", "message": "Firestore not available"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.debug(
		"FirestoreService: Starting update_document",
		{"request_id": request_id, "path": path, "data_keys": data.keys()},
		[Log.TAG_FIREBASE]
	)

	_cpp_firestore.update_document_async(request_id, path, data)

	var result: Variant = await request.await_completion()

	if result.get("status") == "ok":
		Log.info(
			"FirestoreService: update_document completed successfully",
			{"request_id": request_id, "path": path},
			[Log.TAG_FIREBASE]
		)
		document_saved.emit(path)
	else:
		Log.error(
			"FirestoreService: update_document failed",
			{"request_id": request_id, "path": path, "error": result},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)

	return result


func delete_document(path: String) -> Variant:
	"""Delete a document at the given path."""
	if not is_available():
		Log.error(
			"FirestoreService: Not available for delete_document",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {
			"status": "error", "code": "SERVICE_UNAVAILABLE", "message": "Firestore not available"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.debug(
		"FirestoreService: Starting delete_document",
		{"request_id": request_id, "path": path},
		[Log.TAG_FIREBASE]
	)

	_cpp_firestore.delete_document_async(request_id, path)

	var result: Variant = await request.await_completion()

	if result.get("status") == "ok":
		Log.info(
			"FirestoreService: delete_document completed successfully",
			{"request_id": request_id, "path": path},
			[Log.TAG_FIREBASE]
		)
		document_deleted.emit(path)
	else:
		Log.error(
			"FirestoreService: delete_document failed",
			{"request_id": request_id, "path": path, "error": result},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)

	return result


# === Collection Query Operations ===


func query_collection(collection_path: String, query_params: Dictionary = {}) -> Variant:
	"""
	Query a collection with optional filters.

	query_params format:
	{
		"where": [{"field": "status", "op": "==", "value": "active"}],
		"order_by": "created_at",
		"order_direction": "desc",  # or "asc"
		"limit": 10
	}

	Supported operators: ==, !=, <, <=, >, >=
	"""
	if not is_available():
		Log.error(
			"FirestoreService: Not available for query_collection",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {
			"status": "error", "code": "SERVICE_UNAVAILABLE", "message": "Firestore not available"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.debug(
		"FirestoreService: Starting query_collection",
		{"request_id": request_id, "collection": collection_path, "params": query_params},
		[Log.TAG_FIREBASE]
	)

	_cpp_firestore.query_collection_async(request_id, collection_path, query_params)

	var result: Variant = await request.await_completion()

	if result.get("status") == "ok":
		var doc_count: int = result.get("payload", {}).get("documents", []).size()
		Log.info(
			"FirestoreService: query_collection completed successfully",
			{"request_id": request_id, "collection": collection_path, "document_count": doc_count},
			[Log.TAG_FIREBASE]
		)
	else:
		Log.error(
			"FirestoreService: query_collection failed",
			{"request_id": request_id, "collection": collection_path, "error": result},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)

	return result


# === Configuration ===


func configure_settings(settings: Dictionary) -> void:
	"""
	Configure Firestore settings. Must be called before any other operations.

	settings format:
	{
		"persistence_enabled": false,  # Default: false (simpler, no cache issues)
		"cache_size_bytes": 10485760   # 10MB, only if persistence enabled
	}
	"""
	if not is_available():
		Log.error(
			"FirestoreService: Not available for configure_settings",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	Log.debug("FirestoreService: Configuring settings", {"settings": settings}, [Log.TAG_FIREBASE])
	_cpp_firestore.configure_settings(settings)


# === Internal Helpers ===


func _get_next_request_id() -> int:
	var id: int = _next_request_id
	_next_request_id += 1
	return id


func _connect_signals() -> void:
	if not is_instance_valid(_cpp_firestore):
		return

	# Connect C++ signals to complete pending requests
	var err: Error

	err = _cpp_firestore.document_get_completed.connect(_on_document_get_completed)
	if err != OK:
		Log.error(
			"FirestoreService: Failed to connect document_get_completed",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE]
		)

	err = _cpp_firestore.document_set_completed.connect(_on_document_set_completed)
	if err != OK:
		Log.error(
			"FirestoreService: Failed to connect document_set_completed",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE]
		)

	err = _cpp_firestore.document_update_completed.connect(_on_document_update_completed)
	if err != OK:
		Log.error(
			"FirestoreService: Failed to connect document_update_completed",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE]
		)

	err = _cpp_firestore.document_delete_completed.connect(_on_document_delete_completed)
	if err != OK:
		Log.error(
			"FirestoreService: Failed to connect document_delete_completed",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE]
		)

	err = _cpp_firestore.collection_query_completed.connect(_on_collection_query_completed)
	if err != OK:
		Log.error(
			"FirestoreService: Failed to connect collection_query_completed",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE]
		)

	Log.debug("FirestoreService: Signals connected", {}, [Log.TAG_FIREBASE, Log.TAG_INITIALIZATION])


# === Signal Handlers ===


func _on_document_get_completed(
	request_id: int,
	success: bool,
	exists: bool,
	data: Dictionary,
	error_code: int,
	error_message: String
) -> void:
	Log.debug(
		"FirestoreService: document_get_completed received",
		{"request_id": request_id, "success": success, "exists": exists},
		[Log.TAG_FIREBASE]
	)

	if not _pending_requests.has(request_id):
		Log.warning(
			"FirestoreService: No pending request for ID",
			{"request_id": request_id},
			[Log.TAG_FIREBASE]
		)
		return

	var request: FirebaseRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)

	if success:
		request.complete_with_success({"exists": exists, "data": data})
	else:
		request.complete_with_error("DOCUMENT_GET_FAILED", error_message)
		firestore_error.emit(error_code, error_message)


func _on_document_set_completed(
	request_id: int, success: bool, error_code: int, error_message: String
) -> void:
	Log.debug(
		"FirestoreService: document_set_completed received",
		{"request_id": request_id, "success": success},
		[Log.TAG_FIREBASE]
	)

	if not _pending_requests.has(request_id):
		Log.warning(
			"FirestoreService: No pending request for ID",
			{"request_id": request_id},
			[Log.TAG_FIREBASE]
		)
		return

	var request: FirebaseRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)

	if success:
		request.complete_with_success({})
	else:
		request.complete_with_error("DOCUMENT_SET_FAILED", error_message)
		firestore_error.emit(error_code, error_message)


func _on_document_update_completed(
	request_id: int, success: bool, error_code: int, error_message: String
) -> void:
	Log.debug(
		"FirestoreService: document_update_completed received",
		{"request_id": request_id, "success": success},
		[Log.TAG_FIREBASE]
	)

	if not _pending_requests.has(request_id):
		Log.warning(
			"FirestoreService: No pending request for ID",
			{"request_id": request_id},
			[Log.TAG_FIREBASE]
		)
		return

	var request: FirebaseRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)

	if success:
		request.complete_with_success({})
	else:
		request.complete_with_error("DOCUMENT_UPDATE_FAILED", error_message)
		firestore_error.emit(error_code, error_message)


func _on_document_delete_completed(
	request_id: int, success: bool, error_code: int, error_message: String
) -> void:
	Log.debug(
		"FirestoreService: document_delete_completed received",
		{"request_id": request_id, "success": success},
		[Log.TAG_FIREBASE]
	)

	if not _pending_requests.has(request_id):
		Log.warning(
			"FirestoreService: No pending request for ID",
			{"request_id": request_id},
			[Log.TAG_FIREBASE]
		)
		return

	var request: FirebaseRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)

	if success:
		request.complete_with_success({})
	else:
		request.complete_with_error("DOCUMENT_DELETE_FAILED", error_message)
		firestore_error.emit(error_code, error_message)


func _on_collection_query_completed(
	request_id: int, success: bool, documents: Array, error_code: int, error_message: String
) -> void:
	Log.debug(
		"FirestoreService: collection_query_completed received",
		{"request_id": request_id, "success": success, "document_count": documents.size()},
		[Log.TAG_FIREBASE]
	)

	if not _pending_requests.has(request_id):
		Log.warning(
			"FirestoreService: No pending request for ID",
			{"request_id": request_id},
			[Log.TAG_FIREBASE]
		)
		return

	var request: FirebaseRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)

	if success:
		request.complete_with_success({"documents": documents})
	else:
		request.complete_with_error("COLLECTION_QUERY_FAILED", error_message)
		firestore_error.emit(error_code, error_message)
