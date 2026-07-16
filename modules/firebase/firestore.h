#ifndef FirebaseFirestore_h
#define FirebaseFirestore_h

#include "core/object/ref_counted.h"
#include "core/os/os.h"
#include "core/string/ustring.h"
#include "core/variant/variant.h"
#include "core/os/mutex.h"
#include "core/os/memory.h"

// Forward declare Firebase SDK types
namespace firebase {
class App;
namespace firestore {
class Firestore;
class CollectionReference;
class DocumentReference;
class DocumentSnapshot;
class QuerySnapshot;
class Query;
class ListenerRegistration;
} // namespace firestore
} // namespace firebase

#include "firebase.h"
#include <map>
#include <memory>
#include <atomic>
#include <mutex>
#include <vector>
#include <string>
#include <utility>

// Include Firebase SDK headers for Firestore
// Note: firestore_errors.h is not available in from-source SDK builds
#include "firebase/firestore.h"
#include "firebase/firestore/collection_reference.h"
#include "firebase/firestore/document_reference.h"
#include "firebase/firestore/document_snapshot.h"
#include "firebase/firestore/field_value.h"
#include "firebase/firestore/map_field_value.h"
#include "firebase/firestore/query.h"
#include "firebase/firestore/query_snapshot.h"
#include "firebase/firestore/settings.h"
#include "firebase/future.h"

class FirebaseFirestore : public RefCounted {
	GDCLASS(FirebaseFirestore, RefCounted);

private:
	// Thread-safe initialization guard (following database.h pattern)
	static std::mutex initialization_mutex;
	static std::atomic<bool> inited;
	static std::atomic<bool> is_shutting_down;

	// Static Firebase resources
	static firebase::firestore::Firestore* firestore_instance;

	// Private constructor for singleton pattern
	FirebaseFirestore();

protected:
	static void _bind_methods();

	// Helper: Parse document path string to DocumentReference
	// Supports paths like "users/uid" or "users/uid/posts/postId"
	firebase::firestore::DocumentReference get_document_reference(const String& path);

	// Helper: Parse collection path string to CollectionReference
	firebase::firestore::CollectionReference get_collection_reference(const String& path);

	// Helper: Convert Godot Dictionary to Firestore MapFieldValue
	firebase::firestore::MapFieldValue dict_to_map_field_value(const Dictionary& dict);

	// Helper: Convert a raw Firestore MapFieldValue to a Godot Dictionary.
	// task-1066: MAIN-THREAD ONLY. The worker OnCompletion stores the raw MapFieldValue; the
	// Godot Dictionary is built here from the _handle_*_on_main_thread handlers, so no Godot
	// object is constructed on the Firebase worker thread (the b6e10f69c0 null-_p/SIGBUS class).
	Dictionary map_to_dict(const firebase::firestore::MapFieldValue& data);

	// Helper: Convert single Firestore FieldValue to Godot Variant (main-thread only, recursive)
	Variant field_value_to_variant(const firebase::firestore::FieldValue& value);

	// task-1066: worker→main relocation state (mirrors database.cpp PendingFirebaseResult).
	// The worker OnCompletion copies ONLY raw C++ — a copied MapFieldValue fully owns its
	// FieldValues independent of the Future — and hands an int req_id to the main thread.
	struct PendingFirestoreResult {
		bool success = false;
		bool exists = false;
		bool has_doc = false;
		int error_code = 0;
		std::string error_msg;
		firebase::firestore::MapFieldValue doc_data;                                        // get_document payload
		std::vector<std::pair<std::string, firebase::firestore::MapFieldValue>> query_docs; // query payload
	};
	std::mutex _pending_results_mutex;
	std::map<int, PendingFirestoreResult> _pending_results;

	// Main thread callback handlers (MessageQueue marshalling). get/query now take ONLY the
	// req_id and pull their raw payload from _pending_results to build the Godot container here.
	void _handle_document_get_on_main_thread(int req_id);
	void _handle_document_set_on_main_thread(int req_id, bool success, int error_code, String error_msg);
	void _handle_document_update_on_main_thread(int req_id, bool success, int error_code, String error_msg);
	void _handle_document_delete_on_main_thread(int req_id, bool success, int error_code, String error_msg);
	void _handle_collection_query_on_main_thread(int req_id);

public:
	// macOS crash prevention - shutdown control methods
	static void begin_shutdown();
	static bool is_app_shutting_down();

	// Delete copy constructor for singleton pattern
	FirebaseFirestore(const FirebaseFirestore&) = delete;
	~FirebaseFirestore();

	// --- Initialization ---
	void initialize();
	bool is_initialized() const;

	// --- Document CRUD Operations ---

	// Get a document by path (e.g., "users/user123" or "users/user123/posts/post456")
	void get_document_async(int p_request_id, const String& path);

	// Set a document (create or overwrite)
	void set_document_async(int p_request_id, const String& path, const Dictionary& data);

	// Update a document (merge with existing data)
	void update_document_async(int p_request_id, const String& path, const Dictionary& data);

	// Delete a document
	void delete_document_async(int p_request_id, const String& path);

	// --- Collection Query Operations ---

	// Query a collection with optional filters
	// query_params: {
	//   "where": [{"field": "score", "op": ">", "value": 100}],
	//   "order_by": "score",
	//   "order_direction": "desc",  // or "asc"
	//   "limit": 10
	// }
	void query_collection_async(int p_request_id, const String& collection_path, const Dictionary& query_params);

	// --- Settings ---

	// Configure Firestore settings (must be called before any other operations)
	// settings: {
	//   "persistence_enabled": false,  // Default: platform-dependent
	//   "cache_size_bytes": 10485760   // 10MB, only if persistence enabled
	// }
	void configure_settings(const Dictionary& settings);
};

#endif // FirebaseFirestore_h
