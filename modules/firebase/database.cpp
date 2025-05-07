#include "database.h"
#include "convertor.h"
#include "core/os/os.h"
#include "core/config/project_settings.h"
#include "core/string/print_string.h"
#include "core/variant/callable.h"
#include "core/object/class_db.h"

// Include Firebase SDK headers needed for implementation
#include "firebase/app.h"
#include "firebase/database.h"
#include "firebase/future.h"
#include "firebase/database/common.h"
#include "firebase/database/listener.h"
#include "firebase/database/data_snapshot.h"
#include "firebase/database/transaction.h"
#include "firebase/database/database_reference.h"
#include "firebase/database/query.h"

// REMOVED: Duplicate placeholder definition removed from here
// namespace firebase {
// namespace database {
// struct ServerTimestamp {};
// }
// }

// Static member initialization
bool FirebaseDatabase::is_initialized = false;
firebase::database::Database *FirebaseDatabase::database_instance = nullptr;
FirebaseChildListener *FirebaseDatabase::child_listener_instance = nullptr;
ConnectionStateListener *FirebaseDatabase::connection_listener_instance = nullptr;

// --- Listener Implementations ---
// (Implementations for FirebaseChildListener and ConnectionStateListener remain here, unchanged from previous version)
FirebaseChildListener::FirebaseChildListener(FirebaseDatabase* db) : database_instance_ptr(db) {}
void FirebaseChildListener::OnCancelled(const firebase::database::Error& error_code, const char* error_message) {
	print_error(String("[RTDB C++] Child listener cancelled: ") + (error_message ? error_message : "Unknown reason"));
	if (database_instance_ptr) {
		const char* msg = error_message ? error_message : "Listener cancelled";
		database_instance_ptr->call_deferred(SNAME("emit_signal"), SNAME("db_error"), String::num_int64(error_code), String(msg));
	}
}
void FirebaseChildListener::OnChildAdded(const firebase::database::DataSnapshot& snapshot, const char* previous_sibling) {
	if (!snapshot.exists() || !database_instance_ptr) return;
	Variant value = Convertor::fromFirebaseVariant(snapshot.value());
	String key = snapshot.key() ? String(snapshot.key()) : "";
	database_instance_ptr->call_deferred(SNAME("emit_signal"), SNAME("child_added"), key, value);
}
void FirebaseChildListener::OnChildChanged(const firebase::database::DataSnapshot& snapshot, const char* previous_sibling) {
	 if (!snapshot.exists() || !database_instance_ptr) return;
	Variant value = Convertor::fromFirebaseVariant(snapshot.value());
	String key = snapshot.key() ? String(snapshot.key()) : "";
	database_instance_ptr->call_deferred(SNAME("emit_signal"), SNAME("child_changed"), key, value);
}
void FirebaseChildListener::OnChildMoved(const firebase::database::DataSnapshot& snapshot, const char* previous_sibling) {
	 if (!snapshot.exists() || !database_instance_ptr) return;
	Variant value = Convertor::fromFirebaseVariant(snapshot.value());
	String key = snapshot.key() ? String(snapshot.key()) : "";
	database_instance_ptr->call_deferred(SNAME("emit_signal"), SNAME("child_moved"), key, value);
}
void FirebaseChildListener::OnChildRemoved(const firebase::database::DataSnapshot& snapshot) {
	 if (!snapshot.exists() || !database_instance_ptr) return;
	Variant value = Convertor::fromFirebaseVariant(snapshot.value());
	String key = snapshot.key() ? String(snapshot.key()) : "";
	database_instance_ptr->call_deferred(SNAME("emit_signal"), SNAME("child_removed"), key, value);
}

ConnectionStateListener::ConnectionStateListener(FirebaseDatabase* db) : database_instance_ptr(db) {}
void ConnectionStateListener::OnValueChanged(const firebase::database::DataSnapshot& snapshot) {
	if (database_instance_ptr) {
		database_instance_ptr->on_connection_state_changed(snapshot);
	}
}
void ConnectionStateListener::OnCancelled(const firebase::database::Error& error_code, const char* error_message) {
	 print_error(String("[RTDB C++] Connection monitoring cancelled: ") + (error_message ? error_message : "Unknown reason"));
	 if (database_instance_ptr) {
		const char* msg = error_message ? error_message : "Connection listener cancelled";
		database_instance_ptr->call_deferred(SNAME("emit_signal"), SNAME("db_error"), String::num_int64(error_code), String(msg));
	 }
}

// --- Transaction Callbacks ---
firebase::database::TransactionResult FirebaseDatabase::increment_transaction_function(
	firebase::database::MutableData* data, void* transaction_data) {
	TransactionData* tx_data = static_cast<TransactionData*>(transaction_data);
	if (!tx_data) { return firebase::database::kTransactionResultAbort; }
	firebase::Variant current_variant = data->value();
	int64_t current_value = 0;
	if (current_variant.is_int64()) { current_value = current_variant.int64_value(); }
	else if (current_variant.is_double()) { current_value = static_cast<int64_t>(current_variant.double_value()); }
	else if (!current_variant.is_null()) { print_line(String("[RTDB C++] Warning: Non-numeric type in transaction")); }
	int64_t new_value = current_value + tx_data->increment_by;
	data->set_value(firebase::Variant::FromInt64(new_value));
	return firebase::database::kTransactionResultSuccess;
}

void FirebaseDatabase::transaction_completion_callback(
	const firebase::Future<firebase::database::DataSnapshot>& result, void* transaction_data) {
	TransactionData* tx_data = static_cast<TransactionData*>(transaction_data);
	if (!tx_data || !tx_data->database_ptr) { print_error("[RTDB C++] Error: Invalid tx data/ptr in callback."); delete tx_data; return; }
	FirebaseDatabase* db_instance = tx_data->database_ptr;
	int request_id = tx_data->request_id;
	if (result.error() == firebase::database::kErrorNone && result.result() != nullptr) {
		const firebase::database::DataSnapshot* snapshot = result.result();
		Variant value = snapshot ? Convertor::fromFirebaseVariant(snapshot->value()) : Variant();
		String key = snapshot && snapshot->key() ? String(snapshot->key()) : "";
		db_instance->call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), request_id, key, value, true, "");
	} else {
		String error_code_str = String::num_int64(result.error()); const char* sdk_msg = result.error_message(); String error_message = sdk_msg ? String(sdk_msg) : "Unknown transaction error";
		print_error(String("[RTDB C++] Transaction failed. Error: ") + error_code_str + " - " + error_message);
		db_instance->call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), request_id, "", Variant(), false, error_message);
		db_instance->call_deferred(SNAME("emit_signal"), SNAME("db_error"), error_code_str, error_message);
	}
	delete tx_data;
}

// --- FirebaseDatabase Implementation ---
FirebaseDatabase::FirebaseDatabase() { /* ... unchanged ... */ }
FirebaseDatabase::~FirebaseDatabase() { /* ... unchanged ... */ }
firebase::database::DatabaseReference FirebaseDatabase::get_reference_to_path(const Array& keys) { /* ... unchanged ... */ }
firebase::database::Query FirebaseDatabase::get_query_from_reference(const firebase::database::DatabaseReference& ref, const Dictionary& query_params) { /* ... unchanged ... */ }

// --- Asynchronous Methods ---
void FirebaseDatabase::get_value_async(int p_request_id, const Array& keys) { /* ... unchanged ... */ }
void FirebaseDatabase::set_value_async(int p_request_id, const Array& keys, const Variant& value) { /* ... unchanged ... */ }
void FirebaseDatabase::push_and_update_async(int p_request_id, const Array& keys, const Dictionary& data) { /* ... unchanged ... */ }
void FirebaseDatabase::remove_value_async(int p_request_id, const Array& keys) { /* ... unchanged ... */ }
void FirebaseDatabase::query_ordered_data_async(int p_request_id, const Array& keys, const Dictionary& query_params) { /* ... unchanged ... */ }
void FirebaseDatabase::run_transaction_async(int p_request_id, const Array& keys, int increment_by) { /* ... unchanged ... */ }
void FirebaseDatabase::set_server_timestamp_async(int p_request_id, const Array& keys) { /* ... unchanged (uses placeholder struct) ... */ }

// --- Listener Management ---
void FirebaseDatabase::add_listener_at_path(const Array& keys) { /* ... unchanged ... */ }
void FirebaseDatabase::remove_listener_at_path(const Array& keys) { /* ... unchanged ... */ }

// --- Connection Monitoring ---
void FirebaseDatabase::monitor_connection_state() { /* ... unchanged ... */ }
void FirebaseDatabase::on_connection_state_changed(const firebase::database::DataSnapshot& snapshot) { /* ... unchanged ... */ }

// --- Bind Methods ---
// CORRECTED: Added FirebaseDatabase:: scope
void FirebaseDatabase::_bind_methods() {
	// --- Bind Asynchronous Methods ---
	ClassDB::bind_method(D_METHOD("get_value_async", "request_id", "keys"), &FirebaseDatabase::get_value_async);
	ClassDB::bind_method(D_METHOD("set_value_async", "request_id", "keys", "value"), &FirebaseDatabase::set_value_async);
	ClassDB::bind_method(D_METHOD("push_and_update_async", "request_id", "keys", "data"), &FirebaseDatabase::push_and_update_async);
	ClassDB::bind_method(D_METHOD("remove_value_async", "request_id", "keys"), &FirebaseDatabase::remove_value_async);
	ClassDB::bind_method(D_METHOD("query_ordered_data_async", "request_id", "keys", "query_params"), &FirebaseDatabase::query_ordered_data_async);
	ClassDB::bind_method(D_METHOD("run_transaction_async", "request_id", "keys", "increment_by"), &FirebaseDatabase::run_transaction_async);
	ClassDB::bind_method(D_METHOD("set_server_timestamp_async", "request_id", "keys"), &FirebaseDatabase::set_server_timestamp_async);

	// --- Bind Listener Management Methods ---
	ClassDB::bind_method(D_METHOD("add_listener_at_path", "keys"), &FirebaseDatabase::add_listener_at_path);
	ClassDB::bind_method(D_METHOD("remove_listener_at_path", "keys"), &FirebaseDatabase::remove_listener_at_path);

	// --- Bind Connection Monitoring ---
	ClassDB::bind_method(D_METHOD("monitor_connection_state"), &FirebaseDatabase::monitor_connection_state);

	// --- Bind Completion/Error Signals ---
	ADD_SIGNAL(MethodInfo("get_value_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT)));
	ADD_SIGNAL(MethodInfo("get_value_error", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::STRING, "error_code"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("set_value_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("push_and_update_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "push_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("remove_value_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("query_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT)));
	ADD_SIGNAL(MethodInfo("query_error", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::STRING, "error_code"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("transaction_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));

	// --- Bind Existing Signals ---
	ADD_SIGNAL(MethodInfo("child_added", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT)));
	ADD_SIGNAL(MethodInfo("child_changed", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT)));
	ADD_SIGNAL(MethodInfo("child_moved", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT)));
	ADD_SIGNAL(MethodInfo("child_removed", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT)));
	ADD_SIGNAL(MethodInfo("connection_state_changed", PropertyInfo(Variant::BOOL, "connected")));
	ADD_SIGNAL(MethodInfo("db_error", PropertyInfo(Variant::STRING, "code"), PropertyInfo(Variant::STRING, "message")));
}
