// godot/modules/firebase/database.cpp
#include "database.h"
#include "convertor.h" // For Variant conversion
#include "firebase.h" // For Firebase::AppId()

// Godot Core Headers
#include "core/config/project_settings.h"
#include "core/error/error_macros.h" // For WARN_PRINT
#include "core/object/class_db.h"
#include "core/object/message_queue.h" // For thread-safe callback marshalling (Task-207)
#include "core/os/os.h"
#include "core/string/print_string.h"
#include "core/variant/callable.h"
#include "core/variant/variant.h"
#include "core/variant/variant_utility.h" // For VariantUtilityFunctions

// Firebase SDK Headers (Ensure SCons finds these via CPPPATH)
#include "firebase/app.h"
#include "firebase/database.h"
#include "firebase/database/common.h"
#include "firebase/database/data_snapshot.h"
#include "firebase/database/database_reference.h"
#include "firebase/database/listener.h"
#include "firebase/database/mutable_data.h"
#include "firebase/database/query.h"
#include "firebase/database/transaction.h"
#include "firebase/future.h"
#include "firebase/variant.h"
// #include "firebase/database/server_value.h" // Not used in v11.1.0

// --- Static Member Initialization ---
bool FirebaseDatabase::inited = false;
firebase::database::Database* FirebaseDatabase::database_instance = nullptr;
FirebaseChildListener* FirebaseDatabase::child_listener_instance = nullptr;
ConnectionStateListener* FirebaseDatabase::connection_listener_instance = nullptr;

// --- FirebaseChildListener Implementation ---
FirebaseChildListener::FirebaseChildListener() {
	singleton = nullptr;
}

void FirebaseChildListener::OnCancelled(const firebase::database::Error &error_code, const char *error_message) {
	print_error(String("[RTDB C++] Child listener cancelled. Error: ") + itos(error_code) + " Msg: " + (error_message ? error_message : "Unknown reason"));
	if (singleton) {
		const char *msg = error_message ? error_message : "Listener cancelled";
		singleton->call_deferred(SNAME("emit_signal"), SNAME("db_error"), String::num_int64(error_code), String(msg));
	}
}

void FirebaseChildListener::OnChildAdded(const firebase::database::DataSnapshot &snapshot, const char *previous_sibling) {
	if (!snapshot.exists()) {
		print_verbose("[RTDB C++] ChildAdded: Snapshot doesn't exist.");
		return;
	}
	if (!singleton) {
		print_verbose("[RTDB C++] ChildAdded: DB instance not set.");
		return;
	}
	Variant value = Convertor::fromFirebaseVariant(snapshot.value());
	String key = snapshot.key() ? String(snapshot.key()) : "";
	print_verbose(String("[RTDB C++] Child Added: Key='") + key + "'");
	singleton->call_deferred(SNAME("emit_signal"), SNAME("child_added"), key, value);
}

void FirebaseChildListener::OnChildChanged(const firebase::database::DataSnapshot &snapshot, const char *previous_sibling) {
	if (!snapshot.exists()) {
		print_verbose("[RTDB C++] ChildChanged: Snapshot doesn't exist.");
		return;
	}
	if (!singleton) {
		print_verbose("[RTDB C++] ChildChanged: DB instance not set.");
		return;
	}
	Variant value = Convertor::fromFirebaseVariant(snapshot.value());
	String key = snapshot.key() ? String(snapshot.key()) : "";
	print_verbose(String("[RTDB C++] Child Changed: Key='") + key + "'");
	singleton->call_deferred(SNAME("emit_signal"), SNAME("child_changed"), key, value);
}

void FirebaseChildListener::OnChildMoved(const firebase::database::DataSnapshot &snapshot, const char *previous_sibling) {
	if (!snapshot.exists()) {
		print_verbose("[RTDB C++] ChildMoved: Snapshot doesn't exist.");
		return;
	}
	if (!singleton) {
		print_verbose("[RTDB C++] ChildMoved: DB instance not set.");
		return;
	}
	Variant value = Convertor::fromFirebaseVariant(snapshot.value());
	String key = snapshot.key() ? String(snapshot.key()) : "";
	print_verbose(String("[RTDB C++] Child Moved: Key='") + key + "'");
	singleton->call_deferred(SNAME("emit_signal"), SNAME("child_moved"), key, value);
}

void FirebaseChildListener::OnChildRemoved(const firebase::database::DataSnapshot &snapshot) {
	if (!snapshot.exists()) {
		print_verbose("[RTDB C++] ChildRemoved: Snapshot doesn't exist.");
		return;
	}
	if (!singleton) {
		print_verbose("[RTDB C++] ChildRemoved: DB instance not set.");
		return;
	}
	Variant value = Convertor::fromFirebaseVariant(snapshot.value());
	String key = snapshot.key() ? String(snapshot.key()) : "";
	print_verbose(String("[RTDB C++] Child Removed: Key='") + key + "'");
	singleton->call_deferred(SNAME("emit_signal"), SNAME("child_removed"), key, value);
}

// --- ConnectionStateListener Implementation ---
ConnectionStateListener::ConnectionStateListener() {
	singleton = nullptr;
}

void ConnectionStateListener::OnValueChanged(const firebase::database::DataSnapshot &snapshot) {
	if (singleton) {
		singleton->on_connection_state_changed(snapshot);
	}
}

void ConnectionStateListener::OnCancelled(const firebase::database::Error &error_code, const char *error_message) {
	print_error(String("[RTDB C++] Connection monitoring listener cancelled. Error: ") + itos(error_code) + " Msg: " + (error_message ? error_message : "Unknown reason"));
	if (singleton) {
		const char *msg = error_message ? error_message : "Connection listener cancelled";
		singleton->call_deferred(SNAME("emit_signal"), SNAME("db_error"), String::num_int64(error_code), String(msg));
	}
}

// --- Transaction Callbacks ---
firebase::database::TransactionResult FirebaseDatabase::increment_transaction_function(
		firebase::database::MutableData *data, void *transaction_data) {
	TransactionData *tx_data = static_cast<TransactionData *>(transaction_data);
	if (!tx_data) {
		print_error("[RTDB C++] Transaction function error: Invalid transaction_data (null). Aborting.");
		return firebase::database::kTransactionResultAbort;
	}

	firebase::Variant current_variant = data->value();
	int64_t current_value = 0;

	if (current_variant.is_int64()) {
		current_value = current_variant.int64_value();
	} else if (current_variant.is_double()) {
		current_value = static_cast<int64_t>(current_variant.double_value());
		print_verbose(String("[RTDB C++] Transaction: Converting double value '") + String(Variant(current_variant.double_value())) + "' to int64 '" + itos(current_value) + "' for increment.");
	} else if (current_variant.is_string()) {
		String s_val = String::utf8(current_variant.string_value());
		if (s_val.is_valid_int()) {
			current_value = s_val.to_int();
			print_verbose(String("[RTDB C++] Transaction: Converting string value '") + s_val + "' to int64 '" + itos(current_value) + "' for increment.");
		} else {
			WARN_PRINT(String("[RTDB C++] Transaction: Current value is a non-numeric string ('") + s_val + "'). Treating as 0 for increment.");
		}
	} else if (!current_variant.is_null()) {
		// ***** CORRECTED GetTypeName to TypeName *****
		WARN_PRINT(String("[RTDB C++] Transaction: Current value is non-numeric (Type: ") + firebase::Variant::TypeName(current_variant.type()) + "). Treating as 0 for increment.");
	}

	int64_t new_value = current_value + tx_data->increment_by;
	print_verbose(String("[RTDB C++] Transaction: Incrementing ") + itos(current_value) + " by " + itos(tx_data->increment_by) + " -> " + itos(new_value));

	data->set_value(firebase::Variant::FromInt64(new_value));
	return firebase::database::kTransactionResultSuccess;
}

// --- FirebaseDatabase Implementation ---

// Simple constructor (like FirebaseMessaging pattern)
FirebaseDatabase::FirebaseDatabase() {
	print_line("[RTDB C++] FirebaseDatabase Constructor called.");
	_listener_path_ref_count = 0;

	if (!inited) {
		print_line("[RTDB C++] Initializing Firebase RTDB Module...");
		firebase::App *app = Firebase::AppId();
		if (app != nullptr) {
			firebase::InitResult init_result;
			database_instance = firebase::database::Database::GetInstance(app, &init_result);

			if (init_result == firebase::kInitResultSuccess && database_instance != nullptr) {
				print_line("[RTDB C++] Firebase Database instance obtained successfully.");

				// Create listeners and set singleton pointer
				child_listener_instance = new FirebaseChildListener();
				child_listener_instance->singleton = this;

				connection_listener_instance = new ConnectionStateListener();
				connection_listener_instance->singleton = this;

				print_line("[RTDB C++] Listener instances created.");
				inited = true;
				print_line("[RTDB C++] Firebase RTDB Module initialized successfully.");
			} else {
				print_error(String("[RTDB C++] Failed to initialize Firebase Database. Init Result: ") + itos(init_result));
			}
		} else {
			print_error("[RTDB C++] Firebase App is not initialized!");
		}
	}
}

FirebaseDatabase::~FirebaseDatabase() {
	print_line("[RTDB C++] FirebaseDatabase Destructor called.");

	// Only clean up instance-specific resources
	// Static resources are shared across instances - don't cleanup here
	if (_listener_path_ref_count > 0 && _active_child_listener_ref.is_valid() && child_listener_instance) {
		WARN_PRINT("[RTDB C++] Destructor: Removing active child listener due to object destruction.");
		_active_child_listener_ref.RemoveChildListener(child_listener_instance);
		_listener_path_ref_count = 0;
	}

	print_line("[RTDB C++] FirebaseDatabase cleanup completed.");
}

firebase::database::DatabaseReference FirebaseDatabase::get_reference_to_path(const Array &keys) {
	if (!database_instance) {
		print_error("[RTDB C++] Cannot get reference: Database not initialized.");
		return firebase::database::DatabaseReference();
	}

	firebase::database::DatabaseReference current_ref = database_instance->GetReference();

	for (int i = 0; i < keys.size(); ++i) {
		Variant key_part = keys[i];
		String key_str;

		if (key_part.get_type() == Variant::INT) {
			key_str = String::num_int64(key_part.operator int64_t());
		} else if (key_part.get_type() == Variant::FLOAT) {
			key_str = String::num(key_part.operator double());
			WARN_PRINT("[RTDB C++] Using float in path: " + key_str);
		} else if (key_part.get_type() == Variant::STRING) {
			key_str = key_part.operator String();
		} else {
			print_error(String("[RTDB C++] Invalid path segment type: ") + Variant::get_type_name(key_part.get_type()) + ". Path: " + String(Variant(keys)));
			return firebase::database::DatabaseReference();
		}

		if (key_str.is_empty()) {
			print_error(String("[RTDB C++] Empty path segment encountered. Path: ") + String(Variant(keys)));
			return firebase::database::DatabaseReference();
		}

		current_ref = current_ref.Child(key_str.utf8().get_data());
	}
	return current_ref;
}

firebase::database::Query FirebaseDatabase::get_query_from_reference(const firebase::database::DatabaseReference &ref, const Dictionary &query_params) {
	firebase::database::Query query = ref;
	if (query_params.is_empty()) {
		return query;
	}

	print_verbose("[RTDB C++] Applying query parameters: " + String(Variant(query_params)));

	if (query_params.has("orderByChild")) {
		String child_key = query_params["orderByChild"];
		if (child_key.is_empty()) {
			print_error("[RTDB C++] Query Error: orderByChild key cannot be empty.");
		} else {
			query = query.OrderByChild(child_key.utf8().get_data());
			print_verbose("[RTDB C++] Query: OrderByChild('" + child_key + "')");
		}
	} else if (query_params.has("orderByKey")) {
		query = query.OrderByKey();
		print_verbose("[RTDB C++] Query: OrderByKey()");
	} else if (query_params.has("orderByValue")) {
		query = query.OrderByValue();
		print_verbose("[RTDB C++] Query: OrderByValue()");
	}
	if (query_params.has("limitToFirst")) {
		Variant limit_val = query_params["limitToFirst"];
		if (limit_val.get_type() == Variant::INT) {
			int limit = limit_val;
			if (limit > 0) {
				query = query.LimitToFirst(limit);
				print_verbose("[RTDB C++] Query: LimitToFirst(" + itos(limit) + ")");
			} else {
				print_error("[RTDB C++] Query Error: limitToFirst must be positive.");
			}
		} else {
			print_error("[RTDB C++] Query Error: limitToFirst value must be an Integer.");
		}
	} else if (query_params.has("limitToLast")) {
		Variant limit_val = query_params["limitToLast"];
		if (limit_val.get_type() == Variant::INT) {
			int limit = limit_val;
			if (limit > 0) {
				query = query.LimitToLast(limit);
				print_verbose("[RTDB C++] Query: LimitToLast(" + itos(limit) + ")");
			} else {
				print_error("[RTDB C++] Query Error: limitToLast must be positive.");
			}
		} else {
			print_error("[RTDB C++] Query Error: limitToLast value must be an Integer.");
		}
	}
	if (query_params.has("startAt")) {
		firebase::Variant start_val = Convertor::toFirebaseVariant(query_params["startAt"]);
		if (!start_val.is_null()) {
			query = query.StartAt(start_val);
		} else {
			print_error("[RTDB C++] Query Error: Could not convert startAt value.");
		}
		print_verbose("[RTDB C++] Query: StartAt(...)");
	}
	if (query_params.has("endAt")) {
		firebase::Variant end_val = Convertor::toFirebaseVariant(query_params["endAt"]);
		if (!end_val.is_null()) {
			query = query.EndAt(end_val);
		} else {
			print_error("[RTDB C++] Query Error: Could not convert endAt value.");
		}
		print_verbose("[RTDB C++] Query: EndAt(...)");
	}
	if (query_params.has("equalTo")) {
		firebase::Variant equal_val = Convertor::toFirebaseVariant(query_params["equalTo"]);
		if (!equal_val.is_null()) {
			query = query.EqualTo(equal_val);
		} else {
			print_error("[RTDB C++] Query Error: Could not convert equalTo value.");
		}
		print_verbose("[RTDB C++] Query: EqualTo(...)");
	}

	return query;
}

// --- Asynchronous Methods ---

void FirebaseDatabase::get_value_async(int p_request_id, const Array &keys) {
	if (!inited || !database_instance) {
		print_error("[RTDB C++] GetValue failed: RTDB not initialized.");
		call_deferred(SNAME("emit_signal"), SNAME("get_value_error"), p_request_id, String(Variant(keys)), "DB_NOT_INITIALIZED", "Database not initialized.");
		return;
	}
	firebase::database::DatabaseReference ref = get_reference_to_path(keys);
	if (!ref.is_valid()) {
		print_error("[RTDB C++] GetValue failed: Could not get valid reference for path: " + String(Variant(keys)));
		call_deferred(SNAME("emit_signal"), SNAME("get_value_error"), p_request_id, String(Variant(keys)), "INVALID_PATH", "Invalid database path provided.");
		return;
	}

	String path_str_for_logging = String(Variant(keys));
	print_line(String("[RTDB C++] GetValue ReqID:") + itos(p_request_id) + " Path (GDScript Array): " + path_str_for_logging + " -> URL: " + String(ref.url().c_str()));

	firebase::Future<firebase::database::DataSnapshot> future = ref.GetValue();
	future.OnCompletion([this, p_request_id, path_str_for_logging](const firebase::Future<firebase::database::DataSnapshot> &result) {
		// WORKER THREAD - Extract thread-safe data only (Task-207 SIGBUS fix)
		int error = result.error();
		int status = result.status();
		String error_msg = result.error_message() ? String(result.error_message()) : "";

		String key = "";
		firebase::Variant fb_value; // Default null
		bool exists = false;
		bool snapshot_valid = false;

		if (status == firebase::kFutureStatusComplete && error == firebase::database::kErrorNone) {
			const firebase::database::DataSnapshot* snapshot = result.result();
			if (snapshot) {
				snapshot_valid = true;
				key = snapshot->key() ? String(snapshot->key()) : "";
				if (snapshot->exists()) {
					fb_value = snapshot->value(); // Thread-safe copy
					exists = true;
				}
			}
		}

		// Convert firebase::Variant to Godot Variant on worker thread (SAFE - doesn't touch Godot internals)
		Variant godot_value = Convertor::fromFirebaseVariant(fb_value);

		// Marshal to main thread (NO Godot operations on worker thread!)
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_get_value_on_main_thread)
				.bind(p_request_id, path_str_for_logging, key, godot_value, exists, snapshot_valid, status, error, error_msg)
		);
	});
}

void FirebaseDatabase::set_value_async(int p_request_id, const Array &keys, const Variant &value) {
	if (!inited || !database_instance) {
		print_error("[RTDB C++] SetValue failed: RTDB not initialized.");
		call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), p_request_id, false, "Database not initialized.");
		return;
	}
	firebase::database::DatabaseReference ref = get_reference_to_path(keys);
	if (!ref.is_valid()) {
		print_error("[RTDB C++] SetValue failed: Could not get valid reference for path: " + String(Variant(keys)));
		call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), p_request_id, false, "Invalid database path provided.");
		return;
	}
	firebase::Variant firebase_value = Convertor::toFirebaseVariant(value);
	print_verbose(String("[RTDB C++] SetValue ReqID:") + itos(p_request_id) + " Path: " + String(Variant(keys)));
	firebase::Future<void> future = ref.SetValue(firebase_value);
	future.OnCompletion([this, p_request_id](const firebase::Future<void> &result) {
		// WORKER THREAD - Extract thread-safe data only (Task-207 SIGBUS fix)
		bool success = (result.status() == firebase::kFutureStatusComplete &&
					   result.error() == firebase::database::kErrorNone);
		int error = result.error();
		int status = result.status();
		String error_msg = result.error_message() ? String(result.error_message()) : "";

		// Marshal to main thread (NO Godot operations on worker thread!)
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_set_value_on_main_thread)
				.bind(p_request_id, success, status, error, error_msg)
		);
	});
}

void FirebaseDatabase::push_and_update_async(int p_request_id, const Array &keys, const Dictionary &data) {
	if (!inited || !database_instance) {
		print_error("[RTDB C++] PushUpdate failed: RTDB not initialized.");
		call_deferred(SNAME("emit_signal"), SNAME("push_and_update_completed"), p_request_id, "", false, "Database not initialized.");
		return;
	}
	firebase::database::DatabaseReference ref = get_reference_to_path(keys);
	if (!ref.is_valid()) {
		print_error("[RTDB C++] PushUpdate failed: Could not get valid reference for path: " + String(Variant(keys)));
		call_deferred(SNAME("emit_signal"), SNAME("push_and_update_completed"), p_request_id, "", false, "Invalid database path provided.");
		return;
	}
	firebase::database::DatabaseReference new_child_ref = ref.PushChild();
	const char *push_key_cstr = new_child_ref.key();
	String push_key_str = push_key_cstr ? String(push_key_cstr) : "";
	if (push_key_str.is_empty()) {
		print_error("[RTDB C++] PushUpdate failed: Could not generate push key.");
		call_deferred(SNAME("emit_signal"), SNAME("push_and_update_completed"), p_request_id, "", false, "Failed to generate push key.");
		return;
	}
	firebase::Variant firebase_data = Convertor::toFirebaseVariant(data);
	if (!firebase_data.is_map()) {
		print_error("[RTDB C++] PushUpdate failed: Data must be a Dictionary (converts to map).");
		call_deferred(SNAME("emit_signal"), SNAME("push_and_update_completed"), p_request_id, push_key_str, false, "Data must be a Dictionary.");
		return;
	}
	print_verbose(String("[RTDB C++] PushUpdate ReqID:") + itos(p_request_id) + " Path: " + String(Variant(keys)) + " PushKey: " + push_key_str);
	firebase::Future<void> future = new_child_ref.UpdateChildren(firebase_data.map());
	future.OnCompletion([this, p_request_id, push_key_str](const firebase::Future<void> &result) {
		// WORKER THREAD - Extract thread-safe data only (Task-207 SIGBUS fix)
		bool success = (result.status() == firebase::kFutureStatusComplete &&
					   result.error() == firebase::database::kErrorNone);
		int error = result.error();
		int status = result.status();
		String error_msg = result.error_message() ? String(result.error_message()) : "";

		// Marshal to main thread (NO Godot operations on worker thread!)
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_push_and_update_on_main_thread)
				.bind(p_request_id, push_key_str, success, status, error, error_msg)
		);
	});
}

void FirebaseDatabase::remove_value_async(int p_request_id, const Array &keys) {
	if (!inited || !database_instance) {
		print_error("[RTDB C++] RemoveValue failed: RTDB not initialized.");
		call_deferred(SNAME("emit_signal"), SNAME("remove_value_completed"), p_request_id, false, "Database not initialized.");
		return;
	}
	firebase::database::DatabaseReference ref = get_reference_to_path(keys);
	if (!ref.is_valid()) {
		print_error("[RTDB C++] RemoveValue failed: Could not get valid reference for path: " + String(Variant(keys)));
		call_deferred(SNAME("emit_signal"), SNAME("remove_value_completed"), p_request_id, false, "Invalid database path provided.");
		return;
	}
	print_verbose(String("[RTDB C++] RemoveValue ReqID:") + itos(p_request_id) + " Path: " + String(Variant(keys)));
	firebase::Future<void> future = ref.RemoveValue();
	future.OnCompletion([this, p_request_id](const firebase::Future<void> &result) {
		// WORKER THREAD - Extract thread-safe data only (Task-207 SIGBUS fix)
		bool success = (result.status() == firebase::kFutureStatusComplete &&
					   result.error() == firebase::database::kErrorNone);
		int error = result.error();
		int status = result.status();
		String error_msg = result.error_message() ? String(result.error_message()) : "";

		// Marshal to main thread (NO Godot operations on worker thread!)
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_remove_value_on_main_thread)
				.bind(p_request_id, success, status, error, error_msg)
		);
	});
}

void FirebaseDatabase::query_ordered_data_async(int p_request_id, const Array &keys, const Dictionary &query_params) {
	if (!inited || !database_instance) {
		print_error("[RTDB C++] Query failed: RTDB not initialized.");
		call_deferred(SNAME("emit_signal"), SNAME("query_error"), p_request_id, String(Variant(keys)), "DB_NOT_INITIALIZED", "Database not initialized.");
		return;
	}
	firebase::database::DatabaseReference ref = get_reference_to_path(keys);
	if (!ref.is_valid()) {
		print_error("[RTDB C++] Query failed: Could not get valid reference for path: " + String(Variant(keys)));
		call_deferred(SNAME("emit_signal"), SNAME("query_error"), p_request_id, String(Variant(keys)), "INVALID_PATH", "Invalid database path provided.");
		return;
	}
	firebase::database::Query query = get_query_from_reference(ref, query_params);
	print_verbose(String("[RTDB C++] Query ReqID:") + itos(p_request_id) + " Path: " + String(Variant(keys)) + " Params: " + String(Variant(query_params)));
	firebase::Future<firebase::database::DataSnapshot> future = query.GetValue();
	future.OnCompletion([this, p_request_id, keys](const firebase::Future<firebase::database::DataSnapshot> &result) {
		// WORKER THREAD - Extract thread-safe data only (Task-207 SIGBUS fix)
		int error = result.error();
		int status = result.status();
		String error_msg = result.error_message() ? String(result.error_message()) : "";
		String path_str = String(Variant(keys));

		String key = "";
		firebase::Variant fb_value; // Default null
		bool exists = false;
		bool snapshot_valid = false;

		if (status == firebase::kFutureStatusComplete && error == firebase::database::kErrorNone) {
			const firebase::database::DataSnapshot* snapshot = result.result();
			if (snapshot) {
				snapshot_valid = true;
				key = snapshot->key() ? String(snapshot->key()) : "";
				if (snapshot->exists()) {
					fb_value = snapshot->value(); // Thread-safe copy
					exists = true;
				}
			}
		}

		// Convert firebase::Variant to Godot Variant on worker thread (SAFE - doesn't touch Godot internals)
		Variant godot_value = Convertor::fromFirebaseVariant(fb_value);

		// Marshal to main thread (NO Godot operations on worker thread!)
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_query_ordered_data_on_main_thread)
				.bind(p_request_id, path_str, key, godot_value, exists, snapshot_valid, status, error, error_msg)
		);
	});
}

void FirebaseDatabase::run_transaction_async(int p_request_id, const Array &keys, int increment_by) {
	if (!inited || !database_instance) {
		print_error("[RTDB C++] Transaction failed: RTDB not initialized.");
		call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), p_request_id, "", Variant(), false, "Database not initialized.");
		return;
	}
	firebase::database::DatabaseReference ref = get_reference_to_path(keys);
	if (!ref.is_valid()) {
		print_error("[RTDB C++] Transaction failed: Could not get valid reference for path: " + String(Variant(keys)));
		call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), p_request_id, "", Variant(), false, "Invalid database path provided.");
		return;
	}
	TransactionData *tx_data = new TransactionData();
	tx_data->request_id = p_request_id;
	tx_data->increment_by = increment_by;
	tx_data->database_ptr = this;
	print_verbose(String("[RTDB C++] Transaction ReqID:") + itos(p_request_id) + " Path: " + String(Variant(keys)) + " Increment: " + itos(increment_by));
	firebase::Future<firebase::database::DataSnapshot> future = ref.RunTransaction(increment_transaction_function, tx_data);
	future.OnCompletion([this, tx_data](const firebase::Future<firebase::database::DataSnapshot> &result) {
		// WORKER THREAD - Extract thread-safe data only (Task-207 SIGBUS fix)
		if (!tx_data) {
			return;
		}

		int request_id = tx_data->request_id;
		int error = result.error();
		int status = result.status();
		String error_msg = result.error_message() ? String(result.error_message()) : "";

		String key = "";
		firebase::Variant fb_value; // Default null
		bool exists = false;
		bool snapshot_valid = false;

		if (status == firebase::kFutureStatusComplete && error == firebase::database::kErrorNone) {
			const firebase::database::DataSnapshot* snapshot = result.result();
			if (snapshot) {
				snapshot_valid = true;
				key = snapshot->key() ? String(snapshot->key()) : "";
				if (snapshot->exists()) {
					fb_value = snapshot->value(); // Thread-safe copy
					exists = true;
				}
			}
		}

			// Convert firebase::Variant to Godot Variant on worker thread (SAFE - doesn't touch Godot internals)
		Variant godot_value = Convertor::fromFirebaseVariant(fb_value);

		// Marshal to main thread (NO Godot operations on worker thread!)
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_transaction_on_main_thread)
				.bind(request_id, key, godot_value, exists, snapshot_valid, status, error, error_msg)
		);

		delete tx_data;
	});
}

void FirebaseDatabase::set_server_timestamp_async(int p_request_id, const Array &keys) {
	if (!inited || !database_instance) {
		print_error("[RTDB C++] SetServerTimestamp failed: RTDB not initialized.");
		call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), p_request_id, false, "Database not initialized.");
		return;
	}
	firebase::database::DatabaseReference ref = get_reference_to_path(keys);
	if (!ref.is_valid()) {
		print_error("[RTDB C++] SetServerTimestamp failed: Could not get valid reference for path: " + String(Variant(keys)));
		call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), p_request_id, false, "Invalid database path provided.");
		return;
	}
	print_verbose(String("[RTDB C++] SetServerTimestamp ReqID:") + itos(p_request_id) + " Path: " + String(Variant(keys)));

	std::map<firebase::Variant, firebase::Variant> timestamp_map;
	timestamp_map[firebase::Variant(".sv")] = firebase::Variant("timestamp");
	firebase::Variant timestamp_placeholder = firebase::Variant(timestamp_map);

	firebase::Future<void> future = ref.SetValue(timestamp_placeholder);

	future.OnCompletion([this, p_request_id](const firebase::Future<void> &result) {
		// Firebase SDK manages callback lifecycle
		if (false) { // Disabled - using this directly
			WARN_PRINT("[RTDB C++] Callback ignored: FirebaseDatabase instance destroyed.");
			return;
		}
		
		if (result.status() == firebase::kFutureStatusComplete) {
			if (result.error() == firebase::database::kErrorNone) {
				print_verbose(String("[RTDB C++] SetServerTimestamp ReqID:") + itos(p_request_id) + " Success.");
				this->call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), p_request_id, true, "");
			} else {
				String error_code_str = String::num_int64(result.error());
				const char *sdk_msg = result.error_message();
				String error_message = sdk_msg ? String(sdk_msg) : "Unknown Firebase error setting timestamp.";
				print_error(String("[RTDB C++] SetServerTimestamp ReqID:") + itos(p_request_id) + " Error: " + error_code_str + " Msg: " + error_message);
				this->call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), p_request_id, false, error_message);
			}
		} else {
			print_error(String("[RTDB C++] SetServerTimestamp ReqID:") + itos(p_request_id) + " Future did not complete. Status: " + itos(result.status()));
			this->call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), p_request_id, false, "Firebase Future did not complete.");
		}
	});
}

// --- Listener Management ---
void FirebaseDatabase::add_listener_at_path(const Array &keys) {
	if (!inited || !database_instance || !child_listener_instance) {
		print_error("[RTDB C++] AddListener failed: RTDB or listener not initialized.");
		return;
	}
	firebase::database::DatabaseReference ref = get_reference_to_path(keys);
	if (!ref.is_valid()) {
		print_error("[RTDB C++] AddListener failed: Could not get valid reference for path: " + String(Variant(keys)));
		return;
	}
	if (_listener_path_ref_count > 0) {
		if (_active_child_listener_ref == ref) {
			WARN_PRINT("[RTDB C++] AddListener: Listener already active at this exact path.");
			return;
		} else {
			WARN_PRINT("[RTDB C++] AddListener: Replacing existing listener at '" + String(_active_child_listener_ref.url().c_str()) + "' with new one at '" + String(ref.url().c_str()) + "'.");
			_active_child_listener_ref.RemoveChildListener(child_listener_instance);
			_listener_path_ref_count = 0;
		}
	}
	print_line("[RTDB C++] Adding child listener at path: " + String(Variant(keys)) + " URL: " + String(ref.url().c_str()));
	ref.AddChildListener(child_listener_instance);
	_active_child_listener_ref = ref;
	_listener_path_ref_count = 1;
}

void FirebaseDatabase::remove_listener_at_path(const Array &keys) {
	if (!inited || !database_instance) {
		print_error("[RTDB C++] RemoveListener failed: RTDB not initialized.");
		return;
	}

	if (!child_listener_instance) {
		print_error("[RTDB C++] RemoveListener failed: No listener has been created yet.");
		return;
	}
	firebase::database::DatabaseReference ref = get_reference_to_path(keys);
	if (!ref.is_valid()) {
		print_error("[RTDB C++] RemoveListener failed: Could not get valid reference for path: " + String(Variant(keys)));
		return;
	}
	if (_listener_path_ref_count > 0 && _active_child_listener_ref == ref) {
		print_line("[RTDB C++] Removing child listener from path: " + String(Variant(keys)) + " URL: " + String(ref.url().c_str()));
		_active_child_listener_ref.RemoveChildListener(child_listener_instance);
		_listener_path_ref_count = 0; // Reset ref count
		_active_child_listener_ref = firebase::database::DatabaseReference(); // Invalidate the stored ref
	} else {
		WARN_PRINT("[RTDB C++] RemoveListener: No active listener found at the specified path: " + String(Variant(keys)));
		if (_listener_path_ref_count > 0) {
			WARN_PRINT("[RTDB C++] RemoveListener: Active listener is at: " + String(_active_child_listener_ref.url().c_str()));
		}
	}
}

// --- Connection Monitoring ---
void FirebaseDatabase::monitor_connection_state() {
	if (!inited || !database_instance || !connection_listener_instance) {
		print_error("[RTDB C++] MonitorConnection failed: RTDB or listener not initialized.");
		return;
	}
	firebase::database::DatabaseReference connected_ref = database_instance->GetReference(".info/connected");
	print_line("[RTDB C++] Adding value listener to .info/connected");
	connected_ref.AddValueListener(connection_listener_instance);
}

void FirebaseDatabase::on_connection_state_changed(const firebase::database::DataSnapshot &snapshot) {
	if (snapshot.exists() && snapshot.value().is_bool()) {
		bool connected = snapshot.value().bool_value();
		print_verbose(String("[RTDB C++] Connection state changed: ") + (connected ? "Connected" : "Disconnected"));
		call_deferred(SNAME("emit_signal"), SNAME("connection_state_changed"), connected);
	} else {
		WARN_PRINT("[RTDB C++] Received unexpected value for .info/connected state.");
		call_deferred(SNAME("emit_signal"), SNAME("connection_state_changed"), false);
	}
}

// --- Main Thread Callback Handlers (Task-207 SIGBUS Fix) ---
// These methods execute on Godot's main thread via MessageQueue marshalling
// ensuring all Godot operations (Variant conversion, signal emission) are thread-safe

void FirebaseDatabase::_handle_get_value_on_main_thread(
		int req_id,
		String path_str,
		String key,
		Variant godot_value,
		bool exists,
		bool snapshot_valid,
		int status,
		int error,
		String error_msg) {
	// NOW ON MAIN THREAD - Safe for all Godot operations

	if (status == firebase::kFutureStatusComplete && error == firebase::database::kErrorNone) {
		if (snapshot_valid && exists) {
			// Value already converted to Godot Variant on worker thread
			String signal_key = !key.is_empty() ? key : "";

			print_verbose(String("[RTDB C++] GetValue ReqID:") + itos(req_id) + " Main thread handler - Success. Key='" + signal_key + "'");
			call_deferred(SNAME("emit_signal"), SNAME("get_value_completed"), req_id, signal_key, godot_value);
		} else if (snapshot_valid) {
			// Snapshot valid but data doesn't exist
			print_verbose(String("[RTDB C++] GetValue ReqID:") + itos(req_id) + " Main thread handler - Data doesn't exist at path: " + path_str);
			call_deferred(SNAME("emit_signal"), SNAME("get_value_completed"), req_id, path_str, Variant());
		} else {
			// Snapshot pointer was null
			print_error(String("[RTDB C++] GetValue ReqID:") + itos(req_id) + " Main thread handler - CRITICAL: Snapshot pointer null");
			call_deferred(SNAME("emit_signal"), SNAME("get_value_error"), req_id, path_str, "SNAPSHOT_PTR_NULL", "Snapshot pointer was null");
		}
	} else if (status == firebase::kFutureStatusComplete) {
		// Error from Firebase
		String error_code_str = String::num_int64(error);
		print_error(String("[RTDB C++] GetValue ReqID:") + itos(req_id) + " Main thread handler - Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("get_value_error"), req_id, path_str, error_code_str, error_msg);
	} else {
		// Future did not complete
		print_error(String("[RTDB C++] GetValue ReqID:") + itos(req_id) + " Main thread handler - Future did not complete. Status: " + itos(status));
		call_deferred(SNAME("emit_signal"), SNAME("get_value_error"), req_id, path_str, "FUTURE_INVALID_STATUS", "Firebase Future did not complete.");
	}
}

void FirebaseDatabase::_handle_set_value_on_main_thread(
		int req_id,
		bool success,
		int status,
		int error,
		String error_msg) {
	// NOW ON MAIN THREAD

	if (success) {
		print_verbose(String("[RTDB C++] SetValue ReqID:") + itos(req_id) + " Main thread handler - Success.");
		call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), req_id, true, "");
	} else if (status == firebase::kFutureStatusComplete) {
		String error_code_str = String::num_int64(error);
		print_error(String("[RTDB C++] SetValue ReqID:") + itos(req_id) + " Main thread handler - Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), req_id, false, error_msg);
	} else {
		print_error(String("[RTDB C++] SetValue ReqID:") + itos(req_id) + " Main thread handler - Future did not complete. Status: " + itos(status));
		call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), req_id, false, "Firebase Future did not complete.");
	}
}

void FirebaseDatabase::_handle_push_and_update_on_main_thread(
		int req_id,
		String push_key,
		bool success,
		int status,
		int error,
		String error_msg) {
	// NOW ON MAIN THREAD

	if (success) {
		print_verbose(String("[RTDB C++] PushUpdate ReqID:") + itos(req_id) + " Main thread handler - Success. PushKey: " + push_key);
		call_deferred(SNAME("emit_signal"), SNAME("push_and_update_completed"), req_id, push_key, true, "");
	} else if (status == firebase::kFutureStatusComplete) {
		String error_code_str = String::num_int64(error);
		print_error(String("[RTDB C++] PushUpdate ReqID:") + itos(req_id) + " Main thread handler - Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("push_and_update_completed"), req_id, push_key, false, error_msg);
	} else {
		print_error(String("[RTDB C++] PushUpdate ReqID:") + itos(req_id) + " Main thread handler - Future did not complete. Status: " + itos(status));
		call_deferred(SNAME("emit_signal"), SNAME("push_and_update_completed"), req_id, push_key, false, "Firebase Future did not complete.");
	}
}

void FirebaseDatabase::_handle_remove_value_on_main_thread(
		int req_id,
		bool success,
		int status,
		int error,
		String error_msg) {
	// NOW ON MAIN THREAD

	if (success) {
		print_verbose(String("[RTDB C++] RemoveValue ReqID:") + itos(req_id) + " Main thread handler - Success.");
		call_deferred(SNAME("emit_signal"), SNAME("remove_value_completed"), req_id, true, "");
	} else if (status == firebase::kFutureStatusComplete) {
		String error_code_str = String::num_int64(error);
		print_error(String("[RTDB C++] RemoveValue ReqID:") + itos(req_id) + " Main thread handler - Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("remove_value_completed"), req_id, false, error_msg);
	} else {
		print_error(String("[RTDB C++] RemoveValue ReqID:") + itos(req_id) + " Main thread handler - Future did not complete. Status: " + itos(status));
		call_deferred(SNAME("emit_signal"), SNAME("remove_value_completed"), req_id, false, "Firebase Future did not complete.");
	}
}

void FirebaseDatabase::_handle_query_ordered_data_on_main_thread(
		int req_id,
		String path_str,
		String key,
		Variant godot_value,
		bool exists,
		bool snapshot_valid,
		int status,
		int error,
		String error_msg) {
	// NOW ON MAIN THREAD

	if (status == firebase::kFutureStatusComplete && error == firebase::database::kErrorNone) {
		if (snapshot_valid) {
			// Value already converted to Godot Variant on worker thread
			Variant value = exists ? godot_value : Variant();
			String result_key = !key.is_empty() ? key : path_str;

			print_verbose(String("[RTDB C++] Query ReqID:") + itos(req_id) + " Main thread handler - Success.");
			call_deferred(SNAME("emit_signal"), SNAME("query_completed"), req_id, result_key, value);
		} else {
			print_error(String("[RTDB C++] Query ReqID:") + itos(req_id) + " Main thread handler - Snapshot pointer null");
			call_deferred(SNAME("emit_signal"), SNAME("query_error"), req_id, path_str, "SNAPSHOT_PTR_NULL", "Snapshot pointer was null");
		}
	} else if (status == firebase::kFutureStatusComplete) {
		String error_code_str = String::num_int64(error);
		print_error(String("[RTDB C++] Query ReqID:") + itos(req_id) + " Main thread handler - Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("query_error"), req_id, path_str, error_code_str, error_msg);
	} else {
		print_error(String("[RTDB C++] Query ReqID:") + itos(req_id) + " Main thread handler - Future did not complete. Status: " + itos(status));
		call_deferred(SNAME("emit_signal"), SNAME("query_error"), req_id, path_str, "FUTURE_INVALID_STATUS", "Firebase Future did not complete.");
	}
}

void FirebaseDatabase::_handle_transaction_on_main_thread(
		int req_id,
		String key,
		Variant godot_value,
		bool exists,
		bool snapshot_valid,
		int status,
		int error,
		String error_msg) {
	// NOW ON MAIN THREAD

	if (status == firebase::kFutureStatusComplete && error == firebase::database::kErrorNone) {
		if (snapshot_valid && exists) {
			// Value already converted to Godot Variant on worker thread
			String result_key = !key.is_empty() ? key : "";

			print_verbose(String("[RTDB C++] Transaction ReqID:") + itos(req_id) + " Main thread handler - Success. Committed: Yes.");
			call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), req_id, result_key, godot_value, true, "");
		} else if (snapshot_valid) {
			// Success but result is null/doesn't exist
			print_verbose(String("[RTDB C++] Transaction ReqID:") + itos(req_id) + " Main thread handler - Success (result null). Committed: Yes.");
			call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), req_id, "", Variant(), true, "");
		} else {
			print_error(String("[RTDB C++] Transaction ReqID:") + itos(req_id) + " Main thread handler - Snapshot pointer null");
			call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), req_id, "", Variant(), false, "Snapshot pointer was null");
		}
	} else if (status == firebase::kFutureStatusComplete) {
		String error_code_str = String::num_int64(error);
		print_error(String("[RTDB C++] Transaction ReqID:") + itos(req_id) + " Main thread handler - Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), req_id, "", Variant(), false, error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("db_error"), error_code_str, error_msg);
	} else {
		print_error(String("[RTDB C++] Transaction ReqID:") + itos(req_id) + " Main thread handler - Future did not complete. Status: " + itos(status));
		call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), req_id, "", Variant(), false, "Firebase Future did not complete.");
		call_deferred(SNAME("emit_signal"), SNAME("db_error"), "FUTURE_INVALID_STATUS", "Transaction future failed to complete.");
	}
}

// --- Bind Methods ---
void FirebaseDatabase::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_value_async", "request_id", "keys"), &FirebaseDatabase::get_value_async);
	ClassDB::bind_method(D_METHOD("set_value_async", "request_id", "keys", "value"), &FirebaseDatabase::set_value_async);
	ClassDB::bind_method(D_METHOD("push_and_update_async", "request_id", "keys", "data"), &FirebaseDatabase::push_and_update_async);
	ClassDB::bind_method(D_METHOD("remove_value_async", "request_id", "keys"), &FirebaseDatabase::remove_value_async);
	ClassDB::bind_method(D_METHOD("query_ordered_data_async", "request_id", "keys", "query_params"), &FirebaseDatabase::query_ordered_data_async);
	ClassDB::bind_method(D_METHOD("run_transaction_async", "request_id", "keys", "increment_by"), &FirebaseDatabase::run_transaction_async);
	ClassDB::bind_method(D_METHOD("set_server_timestamp_async", "request_id", "keys"), &FirebaseDatabase::set_server_timestamp_async);
	ClassDB::bind_method(D_METHOD("add_listener_at_path", "keys"), &FirebaseDatabase::add_listener_at_path);
	ClassDB::bind_method(D_METHOD("remove_listener_at_path", "keys"), &FirebaseDatabase::remove_listener_at_path);
	ClassDB::bind_method(D_METHOD("monitor_connection_state"), &FirebaseDatabase::monitor_connection_state);

	ADD_SIGNAL(MethodInfo("get_value_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT)));
	ADD_SIGNAL(MethodInfo("get_value_error", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::STRING, "error_code"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("set_value_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("push_and_update_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "push_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("remove_value_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("query_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT)));
	ADD_SIGNAL(MethodInfo("query_error", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::STRING, "error_code"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("transaction_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("child_added", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT)));
	ADD_SIGNAL(MethodInfo("child_changed", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT)));
	ADD_SIGNAL(MethodInfo("child_moved", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT)));
	ADD_SIGNAL(MethodInfo("child_removed", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NIL_IS_VARIANT)));
	ADD_SIGNAL(MethodInfo("connection_state_changed", PropertyInfo(Variant::BOOL, "connected")));
	ADD_SIGNAL(MethodInfo("db_error", PropertyInfo(Variant::STRING, "code"), PropertyInfo(Variant::STRING, "message")));
}
