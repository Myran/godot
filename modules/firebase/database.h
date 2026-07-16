#ifndef FirebaseDatabase_h
#define FirebaseDatabase_h

#include "core/object/ref_counted.h"
#include "core/os/os.h"
#include "core/string/ustring.h"
#include "core/templates/vector.h"
#include "core/variant/variant.h"
#include "core/os/mutex.h"
#include "core/os/memory.h"

// Forward declare Firebase SDK types where possible
namespace firebase {
class App;
namespace database {
class Database;
class DatabaseReference;
class Query;
class ChildListener;
class ValueListener;
class DataSnapshot; // Correct: Use class
class MutableData;
// Removed enum forward decls
struct ServerTimestamp {}; // Keep placeholder struct
} //namespace database
template <typename ResultType>
class Future;
} //namespace firebase

#include "firebase.h"
#include <map>
#include <memory>
#include <atomic>
#include <mutex>

// Include REQUIRED Firebase SDK headers
#include "firebase/database.h"
#include "firebase/database/common.h" // Defines Error enum
#include "firebase/database/data_snapshot.h"
#include "firebase/database/database_reference.h"
#include "firebase/database/listener.h"
#include "firebase/database/query.h"
#include "firebase/database/transaction.h" // Defines TransactionResult, MutableData
#include "firebase/future.h"

class FirebaseDatabase;

// --- Listener Definitions ---
class FirebaseChildListener : public firebase::database::ChildListener {
	FirebaseDatabase* singleton;

public:
	FirebaseChildListener();
	virtual ~FirebaseChildListener() {}
	void OnCancelled(const firebase::database::Error &error_code, const char *error_message) override;
	void OnChildAdded(const firebase::database::DataSnapshot &snapshot, const char *previous_sibling) override;
	void OnChildChanged(const firebase::database::DataSnapshot &snapshot, const char *previous_sibling) override;
	void OnChildMoved(const firebase::database::DataSnapshot &snapshot, const char *previous_sibling) override;
	void OnChildRemoved(const firebase::database::DataSnapshot &snapshot) override;

	friend class FirebaseDatabase;
};

class ConnectionStateListener : public firebase::database::ValueListener {
	FirebaseDatabase* singleton;

public:
	ConnectionStateListener();
	virtual ~ConnectionStateListener() {}
	void OnValueChanged(const firebase::database::DataSnapshot &snapshot) override;
	void OnCancelled(const firebase::database::Error &error_code, const char *error_message) override;

	friend class FirebaseDatabase;
};

// --- Transaction Data ---
struct TransactionData {
	int request_id;
	int increment_by;
	FirebaseDatabase* database_ptr;
};

// --- Pending Firebase Result ---
// Thread-safe storage for Firebase worker thread data.
// Worker threads store raw C++ data here; main thread retrieves and converts to Godot types.
// This prevents creating Godot objects (Dictionary, Array, String) on worker threads,
// which causes null _p pointer corruption in Dictionary variants.
struct PendingFirebaseResult {
	firebase::Variant fb_value;     // Raw Firebase data — converted to Godot Variant on main thread
	std::string key;
	std::string error_msg;
	std::string path_str;
	std::string push_key;           // For push_and_update operations
	std::string event_type;         // For listener events: "child_added", "child_changed", etc.
	bool exists = false;
	bool snapshot_valid = false;
	bool success = false;           // For set/push/remove operations
	bool is_connected = false;      // For connection state events
	int status = 0;
	int error = 0;
};

// --- Main Database Class ---
class FirebaseDatabase : public RefCounted {
	GDCLASS(FirebaseDatabase, RefCounted);

private:
	// Thread-safe initialization guard (Task-213 critical fix)
	static std::mutex initialization_mutex;
	static std::atomic<bool> inited;

	// macOS crash prevention - shutdown flag to prevent callbacks during cleanup
	static std::atomic<bool> is_shutting_down;

	// Static Firebase resources (properly managed)
	static firebase::database::Database *database_instance;
	static FirebaseChildListener *child_listener_instance;
	static ConnectionStateListener *connection_listener_instance;

	// Private constructor for singleton pattern
	FirebaseDatabase();

	// Instance-specific members
	uint64_t _listener_path_ref_count;
	firebase::database::DatabaseReference _active_child_listener_ref;

	// Thread-safe storage for worker thread → main thread data transfer.
	// Worker threads store raw C++ data; main thread retrieves and creates Godot objects.
	std::mutex _pending_results_mutex;
	std::map<int, PendingFirebaseResult> _pending_results;

	// Atomic counter for listener event IDs (negative values to avoid collision
	// with positive GDScript request IDs used by async operations).
	std::atomic<int> _listener_event_counter{0};

protected:
	static void _bind_methods();

	// Helper methods
	firebase::database::DatabaseReference get_reference_to_path(const Array &keys);
	firebase::database::Query get_query_from_reference(const firebase::database::DatabaseReference &ref, const Dictionary &query_params);

	static firebase::database::TransactionResult increment_transaction_function(
			firebase::database::MutableData *data, void *transaction_data);
	static void transaction_completion_callback(
			const firebase::Future<firebase::database::DataSnapshot> &result, void *transaction_data);

	// Main thread callback handlers
	// These methods execute on Godot's main thread via MessageQueue marshalling.
	// They retrieve raw C++ data from _pending_results and create Godot objects (Dictionary,
	// Array, String) on the main thread — preventing worker-thread object corruption.
	void _handle_get_value_on_main_thread(int req_id);
	void _handle_set_value_on_main_thread(int req_id);
	void _handle_push_and_update_on_main_thread(int req_id);
	void _handle_remove_value_on_main_thread(int req_id);
	void _handle_query_ordered_data_on_main_thread(int req_id);
	void _handle_transaction_on_main_thread(int req_id);

	// Listener main thread handlers — same pattern as async handlers above.
	// Listener callbacks fire on Firebase worker threads; these handlers
	// safely create Godot objects on the main thread.
	void _handle_child_event_on_main_thread(int event_id);
	void _handle_connection_state_on_main_thread(int event_id);
	void _handle_listener_error_on_main_thread(int event_id);

public:
	// macOS crash prevention - shutdown control methods
	static void begin_shutdown();
	static bool is_app_shutting_down();

	// Queue listener events from worker threads → main thread handlers.
	// Called from listener callbacks; stores raw C++ data and schedules
	// the appropriate main thread handler via callable_mp.
	void _queue_child_event(PendingFirebaseResult &&result);
	void _queue_connection_state_event(PendingFirebaseResult &&result);
	void _queue_listener_error(PendingFirebaseResult &&result);

	// Delete copy constructor for singleton pattern (assignment operator handled by GDCLASS)
	FirebaseDatabase(const FirebaseDatabase&) = delete;

	~FirebaseDatabase();

	void get_value_async(int p_request_id, const Array &keys);
	void set_value_async(int p_request_id, const Array &keys, const Variant &value);
	void push_and_update_async(int p_request_id, const Array &keys, const Dictionary &data);
	void remove_value_async(int p_request_id, const Array &keys);
	void query_ordered_data_async(int p_request_id, const Array &keys, const Dictionary &query_params);
	void run_transaction_async(int p_request_id, const Array &keys, int increment_by);
	void set_server_timestamp_async(int p_request_id, const Array &keys);
	void add_listener_at_path(const Array &keys);
	void remove_listener_at_path(const Array &keys);
	void monitor_connection_state();
};

#endif // FirebaseDatabase_h
