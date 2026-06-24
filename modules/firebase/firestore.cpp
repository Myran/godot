#include "firestore.h"
#include "firebase.h"
#include "convertor.h"
#include "core/object/message_queue.h"
#include "core/variant/variant.h"

// Static member initialization
std::mutex FirebaseFirestore::initialization_mutex;
std::atomic<bool> FirebaseFirestore::inited{false};
std::atomic<bool> FirebaseFirestore::is_shutting_down{false};
FirebaseFirestore* FirebaseFirestore::singleton_instance{nullptr};
std::mutex FirebaseFirestore::instance_mutex;
firebase::firestore::Firestore* FirebaseFirestore::firestore_instance{nullptr};

// --- Singleton Implementation ---

FirebaseFirestore::FirebaseFirestore() {
	print_line("[Firestore] Constructor called");
}

FirebaseFirestore::~FirebaseFirestore() {
	print_line("[Firestore] Destructor called");
}

FirebaseFirestore& FirebaseFirestore::get_instance() {
	std::lock_guard<std::mutex> lock(instance_mutex);
	if (!singleton_instance) {
		singleton_instance = memnew(FirebaseFirestore);
	}
	return *singleton_instance;
}

void FirebaseFirestore::cleanup() {
	std::lock_guard<std::mutex> lock(instance_mutex);
	if (singleton_instance) {
		memdelete(singleton_instance);
		singleton_instance = nullptr;
	}
	firestore_instance = nullptr;
	inited = false;
}

void FirebaseFirestore::begin_shutdown() {
	is_shutting_down = true;
	print_line("[Firestore] begin_shutdown() called - callbacks will be ignored");
}

bool FirebaseFirestore::is_app_shutting_down() {
	return is_shutting_down;
}

// --- Initialization ---

void FirebaseFirestore::initialize() {
	std::lock_guard<std::mutex> lock(initialization_mutex);

	if (inited) {
		print_line("[Firestore] Already initialized");
		return;
	}

	print_line("[Firestore] Initializing...");

	firebase::App* app = Firebase::AppId();
	if (!app) {
		print_error("[Firestore] Firebase App not initialized");
		return;
	}

	firebase::InitResult result;
	firestore_instance = firebase::firestore::Firestore::GetInstance(app, &result);

	if (result != firebase::kInitResultSuccess) {
		print_error("[Firestore] Failed to initialize Firestore, error: " + String::num_int64(result));
		return;
	}

	// Configure settings - persistence disabled.
	// task-1080: enabling persistence does NOT fix the macOS desktop set_document write-hang.
	// Tested 2026-06-23 (build-export-test-macos firebase-firestore-cpp with persistence ON):
	// set_document still hung to the 45s FIREBASE_TIMEOUT_SEC (44859ms) — the desktop Firestore
	// C++ SDK hard-gates writes on the server write-ACK with NO local-commit fastpath even when
	// persistence is enabled (reads resolve cache-or-server, which is why Get/query pass). So
	// the write-hang is an inherent desktop-SDK limitation, not a settings issue. It is bounded
	// by task-1083 (the cpp await times out cleanly → queue advances, no wedge). Persistence is
	// left OFF (the prior deliberate default); do not re-try enabling it as a fix for the hang.
	// configure_settings() can still override per-session if a future feature needs the cache.
	firebase::firestore::Settings settings;
	settings.set_persistence_enabled(false);
	firestore_instance->set_settings(settings);

	inited = true;
	print_line("[Firestore] Initialized successfully");
}

bool FirebaseFirestore::is_initialized() const {
	return inited;
}

// --- Settings ---

void FirebaseFirestore::configure_settings(const Dictionary& settings_dict) {
	if (!firestore_instance) {
		print_error("[Firestore] Cannot configure settings - Firestore not initialized");
		return;
	}

	firebase::firestore::Settings settings;

	if (settings_dict.has("persistence_enabled")) {
		settings.set_persistence_enabled(settings_dict["persistence_enabled"]);
	}

	if (settings_dict.has("cache_size_bytes")) {
		int64_t cache_size = settings_dict["cache_size_bytes"];
		settings.set_cache_size_bytes(cache_size);
	}

	firestore_instance->set_settings(settings);
	print_line("[Firestore] Settings configured");
}

// --- Helper Methods ---

firebase::firestore::DocumentReference FirebaseFirestore::get_document_reference(const String& path) {
	// Path format: "collection/document" or "collection/document/subcollection/subdocument"
	// Must have even number of segments (alternating collection/document)

	CharString path_cs = path.utf8();
	std::string path_str(path_cs.get_data());

	// Split path by '/'
	std::vector<std::string> segments;
	size_t start = 0;
	size_t end = path_str.find('/');
	while (end != std::string::npos) {
		segments.push_back(path_str.substr(start, end - start));
		start = end + 1;
		end = path_str.find('/', start);
	}
	segments.push_back(path_str.substr(start));

	if (segments.size() < 2 || segments.size() % 2 != 0) {
		print_error("[Firestore] Invalid document path: " + path + " (must have even number of segments)");
		// Return invalid reference - caller should check
		return firestore_instance->Collection("__invalid__").Document("__invalid__");
	}

	// Build the reference: Collection -> Document -> Collection -> Document ...
	firebase::firestore::CollectionReference collection = firestore_instance->Collection(segments[0]);
	firebase::firestore::DocumentReference doc = collection.Document(segments[1]);

	// Handle nested paths
	for (size_t i = 2; i < segments.size(); i += 2) {
		collection = doc.Collection(segments[i]);
		doc = collection.Document(segments[i + 1]);
	}

	return doc;
}

firebase::firestore::CollectionReference FirebaseFirestore::get_collection_reference(const String& path) {
	CharString path_cs = path.utf8();
	std::string path_str(path_cs.get_data());

	// Split path by '/'
	std::vector<std::string> segments;
	size_t start = 0;
	size_t end = path_str.find('/');
	while (end != std::string::npos) {
		segments.push_back(path_str.substr(start, end - start));
		start = end + 1;
		end = path_str.find('/', start);
	}
	segments.push_back(path_str.substr(start));

	if (segments.empty() || segments.size() % 2 == 0) {
		print_error("[Firestore] Invalid collection path: " + path + " (must have odd number of segments)");
		return firestore_instance->Collection("__invalid__");
	}

	// For simple collection path (e.g., "users")
	if (segments.size() == 1) {
		return firestore_instance->Collection(segments[0]);
	}

	// For nested collection path (e.g., "users/uid/posts")
	firebase::firestore::CollectionReference collection = firestore_instance->Collection(segments[0]);
	firebase::firestore::DocumentReference doc = collection.Document(segments[1]);

	for (size_t i = 2; i < segments.size() - 1; i += 2) {
		collection = doc.Collection(segments[i]);
		doc = collection.Document(segments[i + 1]);
	}

	return doc.Collection(segments.back());
}

firebase::firestore::MapFieldValue FirebaseFirestore::dict_to_map_field_value(const Dictionary& dict) {
	firebase::firestore::MapFieldValue result;

	Array keys = dict.keys();
	for (int i = 0; i < keys.size(); i++) {
		String key = keys[i];
		Variant value = dict[key];

		CharString key_cs = key.utf8();

		switch (value.get_type()) {
			case Variant::NIL:
				result[key_cs.get_data()] = firebase::firestore::FieldValue::Null();
				break;
			case Variant::BOOL:
				result[key_cs.get_data()] = firebase::firestore::FieldValue::Boolean(value);
				break;
			case Variant::INT:
				result[key_cs.get_data()] = firebase::firestore::FieldValue::Integer(static_cast<int64_t>(value));
				break;
			case Variant::FLOAT:
				result[key_cs.get_data()] = firebase::firestore::FieldValue::Double(static_cast<double>(value));
				break;
			case Variant::STRING: {
				String str_val = value;
				CharString str_cs = str_val.utf8();
				result[key_cs.get_data()] = firebase::firestore::FieldValue::String(str_cs.get_data());
				break;
			}
			case Variant::DICTIONARY: {
				Dictionary nested_dict = value;
				result[key_cs.get_data()] = firebase::firestore::FieldValue::Map(dict_to_map_field_value(nested_dict));
				break;
			}
			case Variant::ARRAY: {
				Array arr = value;
				std::vector<firebase::firestore::FieldValue> arr_values;
				for (int j = 0; j < arr.size(); j++) {
					Variant arr_item = arr[j];
					// Recursively handle array items (simplified - full implementation would need all types)
					if (arr_item.get_type() == Variant::STRING) {
						String arr_str = arr_item;
						CharString arr_cs = arr_str.utf8();
						arr_values.push_back(firebase::firestore::FieldValue::String(arr_cs.get_data()));
					} else if (arr_item.get_type() == Variant::INT) {
						arr_values.push_back(firebase::firestore::FieldValue::Integer(static_cast<int64_t>(arr_item)));
					} else if (arr_item.get_type() == Variant::FLOAT) {
						arr_values.push_back(firebase::firestore::FieldValue::Double(static_cast<double>(arr_item)));
					} else if (arr_item.get_type() == Variant::BOOL) {
						arr_values.push_back(firebase::firestore::FieldValue::Boolean(arr_item));
					} else if (arr_item.get_type() == Variant::DICTIONARY) {
						Dictionary nested = arr_item;
						arr_values.push_back(firebase::firestore::FieldValue::Map(dict_to_map_field_value(nested)));
					}
				}
				result[key_cs.get_data()] = firebase::firestore::FieldValue::Array(arr_values);
				break;
			}
			default:
				print_line("[Firestore] Unsupported type for key: " + key);
				break;
		}
	}

	return result;
}

Variant FirebaseFirestore::field_value_to_variant(const firebase::firestore::FieldValue& value) {
	switch (value.type()) {
		case firebase::firestore::FieldValue::Type::kNull:
			return Variant();
		case firebase::firestore::FieldValue::Type::kBoolean:
			return value.boolean_value();
		case firebase::firestore::FieldValue::Type::kInteger:
			return static_cast<int64_t>(value.integer_value());
		case firebase::firestore::FieldValue::Type::kDouble:
			return value.double_value();
		case firebase::firestore::FieldValue::Type::kString:
			return String(value.string_value().c_str());
		case firebase::firestore::FieldValue::Type::kMap: {
			Dictionary result;
			for (const auto& pair : value.map_value()) {
				result[String(pair.first.c_str())] = field_value_to_variant(pair.second);
			}
			return result;
		}
		case firebase::firestore::FieldValue::Type::kArray: {
			Array result;
			for (const auto& item : value.array_value()) {
				result.append(field_value_to_variant(item));
			}
			return result;
		}
		case firebase::firestore::FieldValue::Type::kTimestamp: {
			// Return as Dictionary with seconds and nanoseconds
			Dictionary ts;
			ts["seconds"] = value.timestamp_value().seconds();
			ts["nanoseconds"] = value.timestamp_value().nanoseconds();
			return ts;
		}
		case firebase::firestore::FieldValue::Type::kGeoPoint: {
			// Return as Dictionary with latitude and longitude
			Dictionary geo;
			geo["latitude"] = value.geo_point_value().latitude();
			geo["longitude"] = value.geo_point_value().longitude();
			return geo;
		}
		default:
			return Variant();
	}
}

Dictionary FirebaseFirestore::map_to_dict(const firebase::firestore::MapFieldValue& data) {
	// task-1066: MAIN-THREAD ONLY — builds Godot objects. Called from the _handle_*_on_main_thread
	// handlers over a raw MapFieldValue the worker copied; never call this on a Firebase worker thread.
	Dictionary result;
	for (const auto& pair : data) {
		result[String(pair.first.c_str())] = field_value_to_variant(pair.second);
	}
	return result;
}

// --- Document CRUD Operations ---

void FirebaseFirestore::get_document_async(int p_request_id, const String& path) {
	if (!inited || !firestore_instance) {
		print_error("[Firestore] Not initialized");
		{
			PendingFirestoreResult pending;
			pending.error_code = -1;
			pending.error_msg = "Firestore not initialized";
			std::lock_guard<std::mutex> lock(_pending_results_mutex);
			_pending_results[p_request_id] = std::move(pending);
		}
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseFirestore::_handle_document_get_on_main_thread).bind(p_request_id)
		);
		return;
	}

	if (is_shutting_down) {
		print_line("[Firestore] Ignoring get_document_async - app shutting down");
		return;
	}

	print_line("[Firestore] get_document_async: " + path);

	firebase::firestore::DocumentReference doc_ref = get_document_reference(path);

	// Capture request_id and this pointer for callback
	int req_id = p_request_id;
	FirebaseFirestore* self = this;

	firebase::Future<firebase::firestore::DocumentSnapshot> future = doc_ref.Get();
	future.OnCompletion([req_id, self](const firebase::Future<firebase::firestore::DocumentSnapshot>& result) {
		// WORKER THREAD — task-1066: copy ONLY raw C++; build the Godot Dictionary on the main
		// thread in _handle_document_get_on_main_thread. snapshot.GetData() returns a MapFieldValue
		// BY VALUE whose FieldValues own their data, so the copy outlives the Future safely.
		if (is_shutting_down) {
			print_line("[Firestore] Ignoring get callback - app shutting down");
			return;
		}

		PendingFirestoreResult pending;
		pending.success = (result.error() == firebase::firestore::kErrorOk);
		pending.error_code = result.error();
		if (pending.success) {
			const firebase::firestore::DocumentSnapshot& snapshot = *result.result();
			pending.exists = snapshot.exists();
			if (pending.exists) {
				pending.doc_data = snapshot.GetData();
				pending.has_doc = true;
			}
		} else {
			const char* em = result.error_message();
			pending.error_msg = em ? em : "";
		}

		{
			std::lock_guard<std::mutex> lock(self->_pending_results_mutex);
			self->_pending_results[req_id] = std::move(pending);
		}
		MessageQueue::get_singleton()->push_callable(
			callable_mp(self, &FirebaseFirestore::_handle_document_get_on_main_thread).bind(req_id)
		);
	});
}

void FirebaseFirestore::set_document_async(int p_request_id, const String& path, const Dictionary& data) {
	if (!inited || !firestore_instance) {
		print_error("[Firestore] Not initialized");
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseFirestore::_handle_document_set_on_main_thread)
				.bind(p_request_id, false, -1, String("Firestore not initialized"))
		);
		return;
	}

	if (is_shutting_down) {
		print_line("[Firestore] Ignoring set_document_async - app shutting down");
		return;
	}

	print_line("[Firestore] set_document_async: " + path);

	firebase::firestore::DocumentReference doc_ref = get_document_reference(path);
	firebase::firestore::MapFieldValue field_value = dict_to_map_field_value(data);

	int req_id = p_request_id;
	FirebaseFirestore* self = this;

	firebase::Future<void> future = doc_ref.Set(field_value);
	future.OnCompletion([req_id, self](const firebase::Future<void>& result) {
		if (is_shutting_down) {
			print_line("[Firestore] Ignoring set callback - app shutting down");
			return;
		}

		bool success = (result.error() == firebase::firestore::kErrorOk);
		String error_msg = success ? String() : String(result.error_message());

		MessageQueue::get_singleton()->push_callable(
			callable_mp(self, &FirebaseFirestore::_handle_document_set_on_main_thread)
				.bind(req_id, success, result.error(), error_msg)
		);
	});
}

void FirebaseFirestore::update_document_async(int p_request_id, const String& path, const Dictionary& data) {
	if (!inited || !firestore_instance) {
		print_error("[Firestore] Not initialized");
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseFirestore::_handle_document_update_on_main_thread)
				.bind(p_request_id, false, -1, String("Firestore not initialized"))
		);
		return;
	}

	if (is_shutting_down) {
		print_line("[Firestore] Ignoring update_document_async - app shutting down");
		return;
	}

	print_line("[Firestore] update_document_async: " + path);

	firebase::firestore::DocumentReference doc_ref = get_document_reference(path);
	firebase::firestore::MapFieldValue field_value = dict_to_map_field_value(data);

	int req_id = p_request_id;
	FirebaseFirestore* self = this;

	firebase::Future<void> future = doc_ref.Update(field_value);
	future.OnCompletion([req_id, self](const firebase::Future<void>& result) {
		if (is_shutting_down) {
			print_line("[Firestore] Ignoring update callback - app shutting down");
			return;
		}

		bool success = (result.error() == firebase::firestore::kErrorOk);
		String error_msg = success ? String() : String(result.error_message());

		MessageQueue::get_singleton()->push_callable(
			callable_mp(self, &FirebaseFirestore::_handle_document_update_on_main_thread)
				.bind(req_id, success, result.error(), error_msg)
		);
	});
}

void FirebaseFirestore::delete_document_async(int p_request_id, const String& path) {
	if (!inited || !firestore_instance) {
		print_error("[Firestore] Not initialized");
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseFirestore::_handle_document_delete_on_main_thread)
				.bind(p_request_id, false, -1, String("Firestore not initialized"))
		);
		return;
	}

	if (is_shutting_down) {
		print_line("[Firestore] Ignoring delete_document_async - app shutting down");
		return;
	}

	print_line("[Firestore] delete_document_async: " + path);

	firebase::firestore::DocumentReference doc_ref = get_document_reference(path);

	int req_id = p_request_id;
	FirebaseFirestore* self = this;

	firebase::Future<void> future = doc_ref.Delete();
	future.OnCompletion([req_id, self](const firebase::Future<void>& result) {
		if (is_shutting_down) {
			print_line("[Firestore] Ignoring delete callback - app shutting down");
			return;
		}

		bool success = (result.error() == firebase::firestore::kErrorOk);
		String error_msg = success ? String() : String(result.error_message());

		MessageQueue::get_singleton()->push_callable(
			callable_mp(self, &FirebaseFirestore::_handle_document_delete_on_main_thread)
				.bind(req_id, success, result.error(), error_msg)
		);
	});
}

// --- Collection Query Operations ---

void FirebaseFirestore::query_collection_async(int p_request_id, const String& collection_path, const Dictionary& query_params) {
	if (!inited || !firestore_instance) {
		print_error("[Firestore] Not initialized");
		{
			PendingFirestoreResult pending;
			pending.error_code = -1;
			pending.error_msg = "Firestore not initialized";
			std::lock_guard<std::mutex> lock(_pending_results_mutex);
			_pending_results[p_request_id] = std::move(pending);
		}
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseFirestore::_handle_collection_query_on_main_thread).bind(p_request_id)
		);
		return;
	}

	if (is_shutting_down) {
		print_line("[Firestore] Ignoring query_collection_async - app shutting down");
		return;
	}

	print_line("[Firestore] query_collection_async: " + collection_path);

	firebase::firestore::CollectionReference collection = get_collection_reference(collection_path);
	firebase::firestore::Query query = collection;

	// Apply where clauses
	if (query_params.has("where")) {
		Array where_clauses = query_params["where"];
		for (int i = 0; i < where_clauses.size(); i++) {
			Dictionary clause = where_clauses[i];
			if (!clause.has("field") || !clause.has("op") || !clause.has("value")) {
				continue;
			}

			String field = clause["field"];
			String op = clause["op"];
			Variant value = clause["value"];

			CharString field_cs = field.utf8();

			// Convert value to FieldValue
			firebase::firestore::FieldValue fv;
			if (value.get_type() == Variant::STRING) {
				String str_val = value;
				CharString str_cs = str_val.utf8();
				fv = firebase::firestore::FieldValue::String(str_cs.get_data());
			} else if (value.get_type() == Variant::INT) {
				fv = firebase::firestore::FieldValue::Integer(static_cast<int64_t>(value));
			} else if (value.get_type() == Variant::FLOAT) {
				fv = firebase::firestore::FieldValue::Double(static_cast<double>(value));
			} else if (value.get_type() == Variant::BOOL) {
				fv = firebase::firestore::FieldValue::Boolean(value);
			}

			// Apply operator
			if (op == "==") {
				query = query.WhereEqualTo(field_cs.get_data(), fv);
			} else if (op == "!=") {
				query = query.WhereNotEqualTo(field_cs.get_data(), fv);
			} else if (op == "<") {
				query = query.WhereLessThan(field_cs.get_data(), fv);
			} else if (op == "<=") {
				query = query.WhereLessThanOrEqualTo(field_cs.get_data(), fv);
			} else if (op == ">") {
				query = query.WhereGreaterThan(field_cs.get_data(), fv);
			} else if (op == ">=") {
				query = query.WhereGreaterThanOrEqualTo(field_cs.get_data(), fv);
			}
		}
	}

	// Apply order by
	if (query_params.has("order_by")) {
		String order_by = query_params["order_by"];
		CharString order_cs = order_by.utf8();

		firebase::firestore::Query::Direction direction = firebase::firestore::Query::Direction::kAscending;
		if (query_params.has("order_direction")) {
			String dir = query_params["order_direction"];
			if (dir == "desc") {
				direction = firebase::firestore::Query::Direction::kDescending;
			}
		}

		query = query.OrderBy(order_cs.get_data(), direction);
	}

	// Apply limit
	if (query_params.has("limit")) {
		int limit = query_params["limit"];
		query = query.Limit(limit);
	}

	int req_id = p_request_id;
	FirebaseFirestore* self = this;

	firebase::Future<firebase::firestore::QuerySnapshot> future = query.Get();
	future.OnCompletion([req_id, self](const firebase::Future<firebase::firestore::QuerySnapshot>& result) {
		// WORKER THREAD — task-1066: copy ONLY raw C++ (per-doc id std::string + MapFieldValue);
		// build the Godot Array/Dictionary on the main thread in _handle_collection_query_on_main_thread.
		if (is_shutting_down) {
			print_line("[Firestore] Ignoring query callback - app shutting down");
			return;
		}

		PendingFirestoreResult pending;
		pending.success = (result.error() == firebase::firestore::kErrorOk);
		pending.error_code = result.error();
		if (pending.success) {
			const firebase::firestore::QuerySnapshot& snapshot = *result.result();
			for (const auto& doc : snapshot.documents()) {
				pending.query_docs.emplace_back(doc.id(), doc.GetData());
			}
		} else {
			const char* em = result.error_message();
			pending.error_msg = em ? em : "";
		}

		{
			std::lock_guard<std::mutex> lock(self->_pending_results_mutex);
			self->_pending_results[req_id] = std::move(pending);
		}
		MessageQueue::get_singleton()->push_callable(
			callable_mp(self, &FirebaseFirestore::_handle_collection_query_on_main_thread).bind(req_id)
		);
	});
}

// --- Main Thread Callback Handlers ---

void FirebaseFirestore::_handle_document_get_on_main_thread(int req_id) {
	// NOW ON MAIN THREAD — safe to build Godot objects from the raw payload the worker stored.
	PendingFirestoreResult pending;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		auto it = _pending_results.find(req_id);
		if (it == _pending_results.end()) {
			return;
		}
		pending = std::move(it->second);
		_pending_results.erase(it);
	}
	if (is_app_shutting_down()) {
		return;
	}
	Variant data = Dictionary();
	if (pending.success && pending.exists && pending.has_doc) {
		// Build on the main thread, then deepCopyVariant for ARM64 alignment/caller-isolation
		// (task-1066 AC: the C++ guard Firestore previously lacked, matching database.cpp).
		data = Convertor::deepCopyVariant(map_to_dict(pending.doc_data));
	}
	emit_signal("get_document_completed", req_id, pending.success, pending.exists, data, pending.error_code, String(pending.error_msg.c_str()));
}

void FirebaseFirestore::_handle_document_set_on_main_thread(int req_id, bool success, int error_code, String error_msg) {
	emit_signal("set_document_completed", req_id, success, error_code, error_msg);
}

void FirebaseFirestore::_handle_document_update_on_main_thread(int req_id, bool success, int error_code, String error_msg) {
	emit_signal("update_document_completed", req_id, success, error_code, error_msg);
}

void FirebaseFirestore::_handle_document_delete_on_main_thread(int req_id, bool success, int error_code, String error_msg) {
	emit_signal("delete_document_completed", req_id, success, error_code, error_msg);
}

void FirebaseFirestore::_handle_collection_query_on_main_thread(int req_id) {
	// NOW ON MAIN THREAD — build the Godot Array/Dictionary from the raw per-doc payload.
	PendingFirestoreResult pending;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		auto it = _pending_results.find(req_id);
		if (it == _pending_results.end()) {
			return;
		}
		pending = std::move(it->second);
		_pending_results.erase(it);
	}
	if (is_app_shutting_down()) {
		return;
	}
	Array documents;
	if (pending.success) {
		for (const auto& entry : pending.query_docs) {
			Dictionary doc_data;
			doc_data["id"] = String(entry.first.c_str());
			doc_data["data"] = map_to_dict(entry.second);
			documents.append(doc_data);
		}
	}
	Variant docs = Convertor::deepCopyVariant(documents);
	emit_signal("query_collection_completed", req_id, pending.success, docs, pending.error_code, String(pending.error_msg.c_str()));
}

// --- GDScript Binding ---

void FirebaseFirestore::_bind_methods() {
	// NOTE: get_instance() is NOT exposed to GDScript to avoid PtrToArg<FirebaseFirestore> binding issues.
	// Instead, GDScript should create instances directly: var firestore = FirebaseFirestore.new()
	// The underlying firestore_instance is shared across all instances.

	// Initialization
	ClassDB::bind_method(D_METHOD("initialize"), &FirebaseFirestore::initialize);
	ClassDB::bind_method(D_METHOD("is_initialized"), &FirebaseFirestore::is_initialized);
	ClassDB::bind_method(D_METHOD("configure_settings", "settings"), &FirebaseFirestore::configure_settings);

	// Document CRUD
	ClassDB::bind_method(D_METHOD("get_document_async", "request_id", "path"), &FirebaseFirestore::get_document_async);
	ClassDB::bind_method(D_METHOD("set_document_async", "request_id", "path", "data"), &FirebaseFirestore::set_document_async);
	ClassDB::bind_method(D_METHOD("update_document_async", "request_id", "path", "data"), &FirebaseFirestore::update_document_async);
	ClassDB::bind_method(D_METHOD("delete_document_async", "request_id", "path"), &FirebaseFirestore::delete_document_async);

	// Collection Query
	ClassDB::bind_method(D_METHOD("query_collection_async", "request_id", "collection_path", "query_params"), &FirebaseFirestore::query_collection_async);

	// Signals
	ADD_SIGNAL(MethodInfo("get_document_completed",
		PropertyInfo(Variant::INT, "request_id"),
		PropertyInfo(Variant::BOOL, "success"),
		PropertyInfo(Variant::BOOL, "exists"),
		PropertyInfo(Variant::DICTIONARY, "data"),
		PropertyInfo(Variant::INT, "error_code"),
		PropertyInfo(Variant::STRING, "error_message")));

	ADD_SIGNAL(MethodInfo("set_document_completed",
		PropertyInfo(Variant::INT, "request_id"),
		PropertyInfo(Variant::BOOL, "success"),
		PropertyInfo(Variant::INT, "error_code"),
		PropertyInfo(Variant::STRING, "error_message")));

	ADD_SIGNAL(MethodInfo("update_document_completed",
		PropertyInfo(Variant::INT, "request_id"),
		PropertyInfo(Variant::BOOL, "success"),
		PropertyInfo(Variant::INT, "error_code"),
		PropertyInfo(Variant::STRING, "error_message")));

	ADD_SIGNAL(MethodInfo("delete_document_completed",
		PropertyInfo(Variant::INT, "request_id"),
		PropertyInfo(Variant::BOOL, "success"),
		PropertyInfo(Variant::INT, "error_code"),
		PropertyInfo(Variant::STRING, "error_message")));

	ADD_SIGNAL(MethodInfo("query_collection_completed",
		PropertyInfo(Variant::INT, "request_id"),
		PropertyInfo(Variant::BOOL, "success"),
		PropertyInfo(Variant::ARRAY, "documents"),
		PropertyInfo(Variant::INT, "error_code"),
		PropertyInfo(Variant::STRING, "error_message")));
}
