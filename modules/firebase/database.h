#ifndef FirebaseDatabase_h
#define FirebaseDatabase_h

#include "core/object/ref_counted.h"
#include "core/os/os.h"
#include "core/string/ustring.h"
#include "core/templates/vector.h"
#include "core/variant/variant.h"

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
	FirebaseDatabase *database_instance_ptr;

public:
	FirebaseChildListener(FirebaseDatabase *db);
	virtual ~FirebaseChildListener() {}
	void OnCancelled(const firebase::database::Error &error_code, const char *error_message) override;
	void OnChildAdded(const firebase::database::DataSnapshot &snapshot, const char *previous_sibling) override;
	void OnChildChanged(const firebase::database::DataSnapshot &snapshot, const char *previous_sibling) override;
	void OnChildMoved(const firebase::database::DataSnapshot &snapshot, const char *previous_sibling) override;
	void OnChildRemoved(const firebase::database::DataSnapshot &snapshot) override;
};

class ConnectionStateListener : public firebase::database::ValueListener {
public: // Made public
	FirebaseDatabase *database_instance_ptr;

public:
	ConnectionStateListener(FirebaseDatabase *db);
	virtual ~ConnectionStateListener() {}
	void OnValueChanged(const firebase::database::DataSnapshot &snapshot) override;
	void OnCancelled(const firebase::database::Error &error_code, const char *error_message) override;
};

// --- Transaction Data ---
struct TransactionData {
	int request_id;
	int increment_by;
	FirebaseDatabase *database_ptr;
};

// --- Main Database Class ---
class FirebaseDatabase : public RefCounted {
	GDCLASS(FirebaseDatabase, RefCounted);

protected:
	static bool is_initialized;
	static firebase::database::Database *database_instance;
	static FirebaseChildListener *child_listener_instance;
	static ConnectionStateListener *connection_listener_instance; // Static pointer declaration
	static void _bind_methods();
	static uint64_t _listener_path_ref_count;
	static firebase::database::DatabaseReference _active_child_listener_ref;

	firebase::database::DatabaseReference get_reference_to_path(const Array &keys);
	firebase::database::Query get_query_from_reference(const firebase::database::DatabaseReference &ref, const Dictionary &query_params);

	static firebase::database::TransactionResult increment_transaction_function(
			firebase::database::MutableData *data, void *transaction_data);
	static void transaction_completion_callback(
			const firebase::Future<firebase::database::DataSnapshot> &result, void *transaction_data);

public:
	FirebaseDatabase();
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
	void on_connection_state_changed(const firebase::database::DataSnapshot &snapshot);
};

#endif // FirebaseDatabase_h
