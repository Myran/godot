// godot/modules/firebase/database.cpp
#include "database.h"
#include "convertor.h" // For Variant conversion
#include "firebase.h" // For Firebase::AppId()

// Godot Core Headers
#include "core/config/project_settings.h"
#include "core/error/error_macros.h" // For WARN_PRINT
#include "core/object/class_db.h"
#include "core/object/callable_mp.h"
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

// Platform-specific includes
#ifdef _WIN32
#include <windows.h>  // For Sleep() (Task-434 blocking test)
#endif

// --- Thread-Safe Singleton Member Initialization (Task-213 critical fix) ---
std::mutex FirebaseDatabase::initialization_mutex;
std::atomic<bool> FirebaseDatabase::inited(false);
std::atomic<bool> FirebaseDatabase::is_shutting_down(false);

// Static Firebase resources (properly managed)
firebase::database::Database* FirebaseDatabase::database_instance = nullptr;
FirebaseChildListener* FirebaseDatabase::child_listener_instance = nullptr;
ConnectionStateListener* FirebaseDatabase::connection_listener_instance = nullptr;

// --- FirebaseChildListener Implementation ---
FirebaseChildListener::FirebaseChildListener() {
	singleton = nullptr;
}

void FirebaseChildListener::OnCancelled(const firebase::database::Error &error_code, const char *error_message) {
	if (!singleton) {
		return;
	}
	PendingFirebaseResult pending;
	pending.error = static_cast<int>(error_code);
	pending.error_msg = error_message ? error_message : "Listener cancelled";
	pending.event_type = "child_listener_cancelled";
	singleton->_queue_listener_error(std::move(pending));
}

// Child listener callbacks fire on Firebase SDK worker threads.
// All Godot object creation (String, Variant via fromFirebaseVariant) MUST happen
// on the main thread to prevent null _p pointer corruption.
void FirebaseChildListener::OnChildAdded(const firebase::database::DataSnapshot &snapshot, const char *previous_sibling) {
	if (!snapshot.exists() || !singleton) {
		return;
	}
	PendingFirebaseResult pending;
	pending.fb_value = snapshot.value();
	pending.key = snapshot.key() ? snapshot.key() : "";
	pending.event_type = "child_added";
	pending.exists = true;
	singleton->_queue_child_event(std::move(pending));
}

void FirebaseChildListener::OnChildChanged(const firebase::database::DataSnapshot &snapshot, const char *previous_sibling) {
	if (!snapshot.exists() || !singleton) {
		return;
	}
	PendingFirebaseResult pending;
	pending.fb_value = snapshot.value();
	pending.key = snapshot.key() ? snapshot.key() : "";
	pending.event_type = "child_changed";
	pending.exists = true;
	singleton->_queue_child_event(std::move(pending));
}

void FirebaseChildListener::OnChildMoved(const firebase::database::DataSnapshot &snapshot, const char *previous_sibling) {
	if (!snapshot.exists() || !singleton) {
		return;
	}
	PendingFirebaseResult pending;
	pending.fb_value = snapshot.value();
	pending.key = snapshot.key() ? snapshot.key() : "";
	pending.event_type = "child_moved";
	pending.exists = true;
	singleton->_queue_child_event(std::move(pending));
}

void FirebaseChildListener::OnChildRemoved(const firebase::database::DataSnapshot &snapshot) {
	if (!snapshot.exists() || !singleton) {
		return;
	}
	PendingFirebaseResult pending;
	pending.fb_value = snapshot.value();
	pending.key = snapshot.key() ? snapshot.key() : "";
	pending.event_type = "child_removed";
	pending.exists = true;
	singleton->_queue_child_event(std::move(pending));
}

// --- ConnectionStateListener Implementation ---
ConnectionStateListener::ConnectionStateListener() {
	singleton = nullptr;
}

void ConnectionStateListener::OnValueChanged(const firebase::database::DataSnapshot &snapshot) {
	if (!singleton) {
		return;
	}
	PendingFirebaseResult pending;
	pending.event_type = "connection_state";
	if (snapshot.exists() && snapshot.value().is_bool()) {
		pending.is_connected = snapshot.value().bool_value();
		pending.exists = true;
	} else {
		pending.is_connected = false;
		pending.exists = false;
	}
	singleton->_queue_connection_state_event(std::move(pending));
}

void ConnectionStateListener::OnCancelled(const firebase::database::Error &error_code, const char *error_message) {
	if (!singleton) {
		return;
	}
	PendingFirebaseResult pending;
	pending.error = static_cast<int>(error_code);
	pending.error_msg = error_message ? error_message : "Connection listener cancelled";
	pending.event_type = "connection_listener_cancelled";
	singleton->_queue_listener_error(std::move(pending));
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

// macOS crash prevention - shutdown control methods
void FirebaseDatabase::begin_shutdown() {
	is_shutting_down.store(true);
	print_line("[RTDB C++] FirebaseDatabase shutdown initiated - blocking further callbacks");

	// Part 1 of crash fix: Nullify singleton pointers in listeners to block call_deferred callbacks
	// The listener callbacks check `if (singleton)` before calling call_deferred, so this blocks them at source
	if (child_listener_instance) {
		child_listener_instance->singleton = nullptr;
		print_line("[RTDB C++] Child listener singleton pointer nullified");
	}
	if (connection_listener_instance) {
		connection_listener_instance->singleton = nullptr;
		print_line("[RTDB C++] Connection listener singleton pointer nullified");
	}
}

bool FirebaseDatabase::is_app_shutting_down() {
	return is_shutting_down.load();
}

// Private constructor (Task-213 critical fix)
FirebaseDatabase::FirebaseDatabase() {
	print_line("[RTDB C++] FirebaseDatabase Singleton Constructor called.");
	_listener_path_ref_count = 0;

	// Thread-safe double-checked locking pattern
	if (!inited.load()) {
		std::lock_guard<std::mutex> init_lock(initialization_mutex);

		// Check again after acquiring lock (double-checked locking)
		if (!inited.load()) {
			print_line("[RTDB C++] Thread-safe initializing Firebase RTDB Module...");
			firebase::App *app = Firebase::AppId();
			if (app != nullptr) {
				firebase::InitResult init_result;
				database_instance = firebase::database::Database::GetInstance(app, &init_result);

				if (init_result == firebase::kInitResultSuccess && database_instance != nullptr) {
					print_line("[RTDB C++] Firebase Database instance obtained successfully.");

					// Create listeners and set singleton pointer
					// task-1124 invariant: this back-pointer must belong to the boot init-instance
					// (FirebaseService autoload, inits before any debug action) which outlives the
					// process; a boot-reorder that lets a transient instance init first breaks it.
					child_listener_instance = new FirebaseChildListener();
					child_listener_instance->singleton = this;

					connection_listener_instance = new ConnectionStateListener();
					connection_listener_instance->singleton = this;  // same boot-ordering invariant as above

					print_line("[RTDB C++] Listener instances created.");
					inited.store(true);
					print_line("[RTDB C++] Firebase RTDB Module initialized successfully (thread-safe).");
				} else {
					print_error(String("[RTDB C++] Failed to initialize Firebase Database. Init Result: ") + itos(init_result));
				}
			} else {
				print_error("[RTDB C++] Firebase App is not initialized!");
			}
		}
	}
}

FirebaseDatabase::~FirebaseDatabase() {
	print_line("[RTDB C++] FirebaseDatabase Destructor called.");

	// Clean up ONLY this instance's own resource: the child listener THIS instance
	// registered at a path (via add_listener_at_path). Skipped for a transient throwaway
	// instance, which never registered one (_listener_path_ref_count == 0).
	if (_listener_path_ref_count > 0 && _active_child_listener_ref.is_valid() && child_listener_instance) {
		WARN_PRINT("[RTDB C++] Destructor: Removing active child listener due to object destruction.");
		_active_child_listener_ref.RemoveChildListener(child_listener_instance);
		_listener_path_ref_count = 0;
	}

	// task-1124: DO NOT tear down the shared static singletons here. database_instance,
	// child_listener_instance, connection_listener_instance and `inited` are
	// process-lifetime state shared by all instances; teardown is via begin_shutdown()/
	// cleanup_firebase(), never a per-instance destructor. Deleting them on ANY instance
	// death (GDScript instantiates transient throwaway FirebaseDatabase objects) disabled
	// RTDB for the live service and — since connection_listener_instance stays registered
	// via AddValueListener with no RemoveValueListener — armed a use-after-free when
	// .info/connected next fired. The connection listener now lives for process lifetime
	// (never deleted); begin_shutdown() nulls its singleton back-pointer so it no-ops at exit.
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

		// FIX: Store CharString to extend lifetime (prevent dangling pointer, Task-432)
		CharString key_cs = key_str.utf8();
		current_ref = current_ref.Child(key_cs.get_data());
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
			// FIX: Store CharString to extend lifetime (prevent dangling pointer, Task-432)
			CharString child_key_cs = child_key.utf8();
			query = query.OrderByChild(child_key_cs.get_data());
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
	// Task-432: Enhanced validation with diagnostic logging
	print_line(String("[RTDB C++] get_value_async START - ReqID:") + itos(p_request_id));
	print_line(String("[RTDB C++] inited=") + (inited.load() ? "true" : "false") + " database_instance=" + (database_instance ? "valid" : "NULL"));

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

	// Task-434: Diagnostic logging to isolate Windows crash
	print_line(String("[RTDB C++] About to call ref.GetValue() - ref.is_valid()=") + (ref.is_valid() ? "true" : "false"));
	print_line(String("[RTDB C++] ref.key()=") + (ref.key() ? String(ref.key()) : "(null)"));

	// Task-434: Use ref directly - storing in member variable caused Windows crash
	firebase::Future<firebase::database::DataSnapshot> future = ref.GetValue();
	print_line(String("[RTDB C++] ref.GetValue() returned successfully - future.status()=") + itos(future.status()));

	// Convert path to std::string before lambda capture to avoid Godot String on worker thread
	std::string path_std = path_str_for_logging.utf8().get_data();

	// OnCompletion runs on Firebase worker thread.
	// CRITICAL: Only use C++ types here — NO Godot objects (String, Dictionary, Variant).
	// Godot objects created on worker threads can have corrupted internal pointers (null _p).
	// All data is stored in PendingFirebaseResult and converted to Godot types on main thread.
	future.OnCompletion([this, p_request_id, path_std](const firebase::Future<firebase::database::DataSnapshot> &result) {
		// task-1123: bail before locking _pending_results_mutex / pushing to MessageQueue if
		// shutting down. This worker lambda can fire during/after teardown; touching the
		// instance-member mutex or a torn-down MessageQueue -> 0xC0000005 (the task-1081/1084
		// class, completed here for RTDB). Mirrors remote_config.cpp's guard.
		if (is_shutting_down.load()) {
			return;
		}
		// WORKER THREAD — Only C++ types, no Godot objects
		PendingFirebaseResult pending;
		pending.error = result.error();
		pending.status = result.status();
		pending.error_msg = result.error_message() ? std::string(result.error_message()) : "";
		pending.path_str = path_std;

		if (pending.status == firebase::kFutureStatusComplete && pending.error == firebase::database::kErrorNone) {
			const firebase::database::DataSnapshot* snapshot = result.result();
			if (snapshot) {
				pending.snapshot_valid = true;
				pending.key = snapshot->key() ? std::string(snapshot->key()) : "";
				if (snapshot->exists()) {
					pending.fb_value = snapshot->value(); // firebase::Variant copy (C++ type, thread-safe)
					pending.exists = true;
				}
			}
		}

		// Store in thread-safe map — main thread will retrieve and convert to Godot types
		{
			std::lock_guard<std::mutex> lock(_pending_results_mutex);
			_pending_results[p_request_id] = std::move(pending);
		}

		// Marshal minimal notification to main thread (only int, no Godot objects)
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_get_value_on_main_thread)
				.bind(p_request_id)
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
		// task-1123: bail before touching _pending_results_mutex / MessageQueue if shutting
		// down (see get_value_async for the full rationale — worker-thread teardown race).
		if (is_shutting_down.load()) {
			return;
		}
		// WORKER THREAD — Only C++ types, no Godot objects
		PendingFirebaseResult pending;
		pending.success = (result.status() == firebase::kFutureStatusComplete &&
					   result.error() == firebase::database::kErrorNone);
		pending.error = result.error();
		pending.status = result.status();
		pending.error_msg = result.error_message() ? std::string(result.error_message()) : "";

		{
			std::lock_guard<std::mutex> lock(_pending_results_mutex);
			_pending_results[p_request_id] = std::move(pending);
		}

		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_set_value_on_main_thread)
				.bind(p_request_id)
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

	// CRITICAL FIX: Copy to std::string to ensure memory is owned BEFORE DatabaseReference is destroyed
	// This prevents use-after-free when new_child_ref goes out of scope (Task-207 SIGBUS fix)
	std::string push_key_std = push_key_cstr ? std::string(push_key_cstr) : "";

	if (push_key_std.empty()) {
		print_error("[RTDB C++] PushUpdate failed: Could not generate push key.");
		call_deferred(SNAME("emit_signal"), SNAME("push_and_update_completed"), p_request_id, "", false, "Failed to generate push key.");
		return;
	}

	firebase::Variant firebase_data = Convertor::toFirebaseVariant(data);
	if (!firebase_data.is_map()) {
		print_error("[RTDB C++] PushUpdate failed: Data must be a Dictionary (converts to map).");
		call_deferred(SNAME("emit_signal"), SNAME("push_and_update_completed"), p_request_id, String(push_key_std.c_str()), false, "Data must be a Dictionary.");
		return;
	}

	print_verbose(String("[RTDB C++] PushUpdate ReqID:") + itos(p_request_id) + " Path: " + String(Variant(keys)) + " PushKey: " + String(String(push_key_std.c_str())));
	firebase::Future<void> future = new_child_ref.UpdateChildren(firebase_data);
	future.OnCompletion([this, p_request_id, push_key_std](const firebase::Future<void> &result) {
		// task-1123: bail before touching _pending_results_mutex / MessageQueue if shutting
		// down (see get_value_async for the full rationale — worker-thread teardown race).
		if (is_shutting_down.load()) {
			return;
		}
		// WORKER THREAD — Only C++ types, no Godot objects
		PendingFirebaseResult pending;
		pending.success = (result.status() == firebase::kFutureStatusComplete &&
					   result.error() == firebase::database::kErrorNone);
		pending.error = result.error();
		pending.status = result.status();
		pending.error_msg = result.error_message() ? std::string(result.error_message()) : "";
		pending.push_key = push_key_std;

		{
			std::lock_guard<std::mutex> lock(_pending_results_mutex);
			_pending_results[p_request_id] = std::move(pending);
		}

		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_push_and_update_on_main_thread)
				.bind(p_request_id)
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
		// task-1123: bail before touching _pending_results_mutex / MessageQueue if shutting
		// down (see get_value_async for the full rationale — worker-thread teardown race).
		if (is_shutting_down.load()) {
			return;
		}
		// WORKER THREAD — Only C++ types, no Godot objects
		PendingFirebaseResult pending;
		pending.success = (result.status() == firebase::kFutureStatusComplete &&
					   result.error() == firebase::database::kErrorNone);
		pending.error = result.error();
		pending.status = result.status();
		pending.error_msg = result.error_message() ? std::string(result.error_message()) : "";

		{
			std::lock_guard<std::mutex> lock(_pending_results_mutex);
			_pending_results[p_request_id] = std::move(pending);
		}

		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_remove_value_on_main_thread)
				.bind(p_request_id)
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
	String path_str_for_logging = String(Variant(keys));
	print_verbose(String("[RTDB C++] Query ReqID:") + itos(p_request_id) + " Path: " + path_str_for_logging + " Params: " + String(Variant(query_params)));

	// Convert path to std::string before lambda capture to avoid Godot Array on worker thread
	std::string query_path_std = path_str_for_logging.utf8().get_data();

	firebase::Future<firebase::database::DataSnapshot> future = query.GetValue();
	future.OnCompletion([this, p_request_id, query_path_std](const firebase::Future<firebase::database::DataSnapshot> &result) {
		// task-1123: bail before touching _pending_results_mutex / MessageQueue if shutting
		// down (see get_value_async for the full rationale — worker-thread teardown race).
		if (is_shutting_down.load()) {
			return;
		}
		// WORKER THREAD — Only C++ types, no Godot objects
		PendingFirebaseResult pending;
		pending.error = result.error();
		pending.status = result.status();
		pending.error_msg = result.error_message() ? std::string(result.error_message()) : "";
		pending.path_str = query_path_std;

		if (pending.status == firebase::kFutureStatusComplete && pending.error == firebase::database::kErrorNone) {
			const firebase::database::DataSnapshot* snapshot = result.result();
			if (snapshot) {
				pending.snapshot_valid = true;
				pending.key = snapshot->key() ? std::string(snapshot->key()) : "";
				if (snapshot->exists()) {
					pending.fb_value = snapshot->value(); // firebase::Variant copy (C++ type, thread-safe)
					pending.exists = true;
				}
			}
		}

		{
			std::lock_guard<std::mutex> lock(_pending_results_mutex);
			_pending_results[p_request_id] = std::move(pending);
		}

		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_query_ordered_data_on_main_thread)
				.bind(p_request_id)
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
		// task-1123: bail before touching _pending_results_mutex / MessageQueue if shutting
		// down (worker-thread teardown race). Free the lambda-owned tx_data first so the early
		// return doesn't leak — mirrors remote_config set_defaults_async freeing defaults_data.
		// (delete nullptr is a safe no-op, so this is correct even if tx_data is null.)
		if (is_shutting_down.load()) {
			delete tx_data;
			return;
		}
		// WORKER THREAD — Only C++ types, no Godot objects
		if (!tx_data) {
			return;
		}

		int request_id = tx_data->request_id;

		PendingFirebaseResult pending;
		pending.error = result.error();
		pending.status = result.status();
		pending.error_msg = result.error_message() ? std::string(result.error_message()) : "";

		if (pending.status == firebase::kFutureStatusComplete && pending.error == firebase::database::kErrorNone) {
			const firebase::database::DataSnapshot* snapshot = result.result();
			if (snapshot) {
				pending.snapshot_valid = true;
				pending.key = snapshot->key() ? std::string(snapshot->key()) : "";
				if (snapshot->exists()) {
					pending.fb_value = snapshot->value(); // firebase::Variant copy (C++ type, thread-safe)
					pending.exists = true;
				}
			}
		}

		{
			std::lock_guard<std::mutex> lock(_pending_results_mutex);
			_pending_results[request_id] = std::move(pending);
		}

		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_transaction_on_main_thread)
				.bind(request_id)
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
		// task-1123: bail before touching _pending_results_mutex / MessageQueue if shutting
		// down (see get_value_async for the full rationale — worker-thread teardown race).
		if (is_shutting_down.load()) {
			return;
		}
		// WORKER THREAD — Only C++ types, no Godot objects
		PendingFirebaseResult pending;
		pending.success = (result.status() == firebase::kFutureStatusComplete &&
					   result.error() == firebase::database::kErrorNone);
		pending.error = result.error();
		pending.status = result.status();
		pending.error_msg = result.error_message() ? std::string(result.error_message()) : "";

		{
			std::lock_guard<std::mutex> lock(_pending_results_mutex);
			_pending_results[p_request_id] = std::move(pending);
		}

		// Reuse set_value handler — same signal signature
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseDatabase::_handle_set_value_on_main_thread)
				.bind(p_request_id)
		);
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

// --- Queue Methods for Listener Events ---
// Called from worker threads. Store raw C++ data and schedule main thread handler.

void FirebaseDatabase::_queue_child_event(PendingFirebaseResult &&result) {
	int event_id = --_listener_event_counter;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		_pending_results[event_id] = std::move(result);
	}
	callable_mp(this, &FirebaseDatabase::_handle_child_event_on_main_thread).call_deferred(event_id);
}

void FirebaseDatabase::_queue_connection_state_event(PendingFirebaseResult &&result) {
	int event_id = --_listener_event_counter;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		_pending_results[event_id] = std::move(result);
	}
	callable_mp(this, &FirebaseDatabase::_handle_connection_state_on_main_thread).call_deferred(event_id);
}

void FirebaseDatabase::_queue_listener_error(PendingFirebaseResult &&result) {
	int event_id = --_listener_event_counter;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		_pending_results[event_id] = std::move(result);
	}
	callable_mp(this, &FirebaseDatabase::_handle_listener_error_on_main_thread).call_deferred(event_id);
}

// --- Main Thread Callback Handlers (Task-207 SIGBUS Fix) ---
// These methods execute on Godot's main thread via MessageQueue marshalling
// ensuring all Godot operations (Variant conversion, signal emission) are thread-safe

void FirebaseDatabase::_handle_get_value_on_main_thread(int req_id) {
	// NOW ON MAIN THREAD - Safe for all Godot operations

	// Part 2 of crash fix: Skip callback if app is shutting down (Task-331)
	if (is_app_shutting_down()) {
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		_pending_results.erase(req_id);
		print_line("[RTDB C++] _handle_get_value_on_main_thread skipped - app shutting down");
		return;
	}

	// Retrieve raw C++ data stored by worker thread
	PendingFirebaseResult pending;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		auto it = _pending_results.find(req_id);
		if (it == _pending_results.end()) {
			print_error(String("[RTDB C++] GetValue ReqID:") + itos(req_id) + " Main thread handler - CRITICAL: No pending result found");
			return;
		}
		pending = std::move(it->second);
		_pending_results.erase(it);
	}

	// Convert C++ strings to Godot Strings ON MAIN THREAD (safe)
	String path_str = String(pending.path_str.c_str());
	String error_msg = String(pending.error_msg.c_str());

	if (pending.status == firebase::kFutureStatusComplete && pending.error == firebase::database::kErrorNone) {
		// Task-516: Windows Firebase SDK bug workaround
		if (!error_msg.is_empty()) {
			print_error(String("[RTDB C++] GetValue ReqID:") + itos(req_id) + " Main thread handler - Error (SDK returned code 0 with message): " + error_msg);
			call_deferred(SNAME("emit_signal"), SNAME("get_value_error"), req_id, path_str, "SDK_ERROR_MSG", error_msg);
		} else if (pending.snapshot_valid && pending.exists) {
			// Convert firebase::Variant to Godot Variant ON MAIN THREAD
			// This is the critical fix: creating Dictionary/Array objects on the main thread
			// prevents null _p pointer corruption that occurred when created on worker threads.
			Variant godot_value = Convertor::fromFirebaseVariant(pending.fb_value);
			// task-1065 KEEP: main-thread fromFirebaseVariant + deepCopyVariant is the ARM64 guard; GDScript backstop deleted (see convertor.cpp). Do not remove.
			Variant safe_value = Convertor::deepCopyVariant(godot_value);

			String signal_key = !pending.key.empty() ? String(pending.key.c_str()) : "";
			print_verbose(String("[RTDB C++] GetValue ReqID:") + itos(req_id) + " Main thread handler - Success. Key='" + signal_key + "'");
			call_deferred(SNAME("emit_signal"), SNAME("get_value_completed"), req_id, signal_key, safe_value);
		} else if (pending.snapshot_valid) {
			print_verbose(String("[RTDB C++] GetValue ReqID:") + itos(req_id) + " Main thread handler - Data doesn't exist at path: " + path_str);
			call_deferred(SNAME("emit_signal"), SNAME("get_value_completed"), req_id, path_str, Variant());
		} else {
			print_error(String("[RTDB C++] GetValue ReqID:") + itos(req_id) + " Main thread handler - CRITICAL: Snapshot pointer null");
			call_deferred(SNAME("emit_signal"), SNAME("get_value_error"), req_id, path_str, "SNAPSHOT_PTR_NULL", "Snapshot pointer was null");
		}
	} else if (pending.status == firebase::kFutureStatusComplete) {
		String error_code_str = String::num_int64(pending.error);
		print_error(String("[RTDB C++] GetValue ReqID:") + itos(req_id) + " Main thread handler - Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("get_value_error"), req_id, path_str, error_code_str, error_msg);
	} else {
		print_error(String("[RTDB C++] GetValue ReqID:") + itos(req_id) + " Main thread handler - Future did not complete. Status: " + itos(pending.status));
		call_deferred(SNAME("emit_signal"), SNAME("get_value_error"), req_id, path_str, "FUTURE_INVALID_STATUS", "Firebase Future did not complete.");
	}
}

void FirebaseDatabase::_handle_set_value_on_main_thread(int req_id) {
	// NOW ON MAIN THREAD

	if (is_app_shutting_down()) {
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		_pending_results.erase(req_id);
		print_line("[RTDB C++] _handle_set_value_on_main_thread skipped - app shutting down");
		return;
	}

	PendingFirebaseResult pending;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		auto it = _pending_results.find(req_id);
		if (it == _pending_results.end()) {
			print_error(String("[RTDB C++] SetValue ReqID:") + itos(req_id) + " Main thread handler - CRITICAL: No pending result found");
			return;
		}
		pending = std::move(it->second);
		_pending_results.erase(it);
	}

	String error_msg = String(pending.error_msg.c_str());

	if (pending.success) {
		print_verbose(String("[RTDB C++] SetValue ReqID:") + itos(req_id) + " Main thread handler - Success.");
		call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), req_id, true, "");
	} else if (pending.status == firebase::kFutureStatusComplete) {
		String error_code_str = String::num_int64(pending.error);
		print_error(String("[RTDB C++] SetValue ReqID:") + itos(req_id) + " Main thread handler - Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), req_id, false, error_msg);
	} else {
		print_error(String("[RTDB C++] SetValue ReqID:") + itos(req_id) + " Main thread handler - Future did not complete. Status: " + itos(pending.status));
		call_deferred(SNAME("emit_signal"), SNAME("set_value_completed"), req_id, false, "Firebase Future did not complete.");
	}
}

void FirebaseDatabase::_handle_push_and_update_on_main_thread(int req_id) {
	// NOW ON MAIN THREAD

	if (is_app_shutting_down()) {
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		_pending_results.erase(req_id);
		print_line("[RTDB C++] _handle_push_and_update_on_main_thread skipped - app shutting down");
		return;
	}

	PendingFirebaseResult pending;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		auto it = _pending_results.find(req_id);
		if (it == _pending_results.end()) {
			print_error(String("[RTDB C++] PushUpdate ReqID:") + itos(req_id) + " Main thread handler - CRITICAL: No pending result found");
			return;
		}
		pending = std::move(it->second);
		_pending_results.erase(it);
	}

	// Convert C++ strings to Godot Strings on main thread
	String push_key = String(pending.push_key.c_str());
	String error_msg = String(pending.error_msg.c_str());

	if (pending.success) {
		print_verbose(String("[RTDB C++] PushUpdate ReqID:") + itos(req_id) + " Main thread handler - Success. PushKey: " + push_key);
		call_deferred(SNAME("emit_signal"), SNAME("push_and_update_completed"), req_id, push_key, true, "");
	} else if (pending.status == firebase::kFutureStatusComplete) {
		String error_code_str = String::num_int64(pending.error);
		print_error(String("[RTDB C++] PushUpdate ReqID:") + itos(req_id) + " Main thread handler - Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("push_and_update_completed"), req_id, push_key, false, error_msg);
	} else {
		print_error(String("[RTDB C++] PushUpdate ReqID:") + itos(req_id) + " Main thread handler - Future did not complete. Status: " + itos(pending.status));
		call_deferred(SNAME("emit_signal"), SNAME("push_and_update_completed"), req_id, push_key, false, "Firebase Future did not complete.");
	}
}

void FirebaseDatabase::_handle_remove_value_on_main_thread(int req_id) {
	// NOW ON MAIN THREAD

	if (is_app_shutting_down()) {
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		_pending_results.erase(req_id);
		print_line("[RTDB C++] _handle_remove_value_on_main_thread skipped - app shutting down");
		return;
	}

	PendingFirebaseResult pending;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		auto it = _pending_results.find(req_id);
		if (it == _pending_results.end()) {
			print_error(String("[RTDB C++] RemoveValue ReqID:") + itos(req_id) + " Main thread handler - CRITICAL: No pending result found");
			return;
		}
		pending = std::move(it->second);
		_pending_results.erase(it);
	}

	String error_msg = String(pending.error_msg.c_str());

	if (pending.success) {
		print_verbose(String("[RTDB C++] RemoveValue ReqID:") + itos(req_id) + " Main thread handler - Success.");
		call_deferred(SNAME("emit_signal"), SNAME("remove_value_completed"), req_id, true, "");
	} else if (pending.status == firebase::kFutureStatusComplete) {
		String error_code_str = String::num_int64(pending.error);
		print_error(String("[RTDB C++] RemoveValue ReqID:") + itos(req_id) + " Main thread handler - Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("remove_value_completed"), req_id, false, error_msg);
	} else {
		print_error(String("[RTDB C++] RemoveValue ReqID:") + itos(req_id) + " Main thread handler - Future did not complete. Status: " + itos(pending.status));
		call_deferred(SNAME("emit_signal"), SNAME("remove_value_completed"), req_id, false, "Firebase Future did not complete.");
	}
}

void FirebaseDatabase::_handle_query_ordered_data_on_main_thread(int req_id) {
	// NOW ON MAIN THREAD — all Godot object creation happens here

	if (is_app_shutting_down()) {
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		_pending_results.erase(req_id);
		print_line("[RTDB C++] _handle_query_ordered_data_on_main_thread skipped - app shutting down");
		return;
	}

	PendingFirebaseResult pending;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		auto it = _pending_results.find(req_id);
		if (it == _pending_results.end()) {
			print_error(String("[RTDB C++] Query ReqID:") + itos(req_id) + " Main thread handler - CRITICAL: No pending result found");
			return;
		}
		pending = std::move(it->second);
		_pending_results.erase(it);
	}

	// Convert C++ strings to Godot Strings ON MAIN THREAD
	String path_str = String(pending.path_str.c_str());
	String key = String(pending.key.c_str());
	String error_msg = String(pending.error_msg.c_str());

	if (pending.status == firebase::kFutureStatusComplete && pending.error == firebase::database::kErrorNone) {
		// Task-516: Windows Firebase SDK bug workaround
		if (!error_msg.is_empty()) {
			print_error(String("[RTDB C++] Query ReqID:") + itos(req_id) + " Main thread handler - Error (SDK returned code 0 with message): " + error_msg);
			call_deferred(SNAME("emit_signal"), SNAME("query_error"), req_id, path_str, "SDK_ERROR_MSG", error_msg);
		} else if (pending.snapshot_valid) {
			// Convert firebase::Variant → Godot Variant ON MAIN THREAD (root cause fix)
			Variant godot_value = pending.exists ? Convertor::fromFirebaseVariant(pending.fb_value) : Variant();
			String result_key = !key.is_empty() ? key : path_str;

			// Deep copy for ARM64 alignment safety
			// task-1065 KEEP: main-thread fromFirebaseVariant + deepCopyVariant is the ARM64 guard; GDScript backstop deleted (see convertor.cpp). Do not remove.
			Variant safe_value = Convertor::deepCopyVariant(godot_value);

			print_verbose(String("[RTDB C++] Query ReqID:") + itos(req_id) + " Main thread handler - Success.");
			call_deferred(SNAME("emit_signal"), SNAME("query_completed"), req_id, result_key, safe_value);
		} else {
			print_error(String("[RTDB C++] Query ReqID:") + itos(req_id) + " Main thread handler - Snapshot pointer null");
			call_deferred(SNAME("emit_signal"), SNAME("query_error"), req_id, path_str, "SNAPSHOT_PTR_NULL", "Snapshot pointer was null");
		}
	} else if (pending.status == firebase::kFutureStatusComplete) {
		String error_code_str = String::num_int64(pending.error);
		print_error(String("[RTDB C++] Query ReqID:") + itos(req_id) + " Main thread handler - Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("query_error"), req_id, path_str, error_code_str, error_msg);
	} else {
		print_error(String("[RTDB C++] Query ReqID:") + itos(req_id) + " Main thread handler - Future did not complete. Status: " + itos(pending.status));
		call_deferred(SNAME("emit_signal"), SNAME("query_error"), req_id, path_str, "FUTURE_INVALID_STATUS", "Firebase Future did not complete.");
	}
}

void FirebaseDatabase::_handle_transaction_on_main_thread(int req_id) {
	// NOW ON MAIN THREAD — all Godot object creation happens here

	if (is_app_shutting_down()) {
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		_pending_results.erase(req_id);
		print_line("[RTDB C++] _handle_transaction_on_main_thread skipped - app shutting down");
		return;
	}

	PendingFirebaseResult pending;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		auto it = _pending_results.find(req_id);
		if (it == _pending_results.end()) {
			print_error(String("[RTDB C++] Transaction ReqID:") + itos(req_id) + " Main thread handler - CRITICAL: No pending result found");
			return;
		}
		pending = std::move(it->second);
		_pending_results.erase(it);
	}

	// Convert C++ strings to Godot Strings ON MAIN THREAD
	String key = String(pending.key.c_str());
	String error_msg = String(pending.error_msg.c_str());

	if (pending.status == firebase::kFutureStatusComplete && pending.error == firebase::database::kErrorNone) {
		// Task-516: Windows Firebase SDK bug workaround
		if (!error_msg.is_empty()) {
			print_error(String("[RTDB C++] Transaction ReqID:") + itos(req_id) + " Main thread handler - Error (SDK returned code 0 with message): " + error_msg);
			call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), req_id, "", Variant(), false, error_msg);
			call_deferred(SNAME("emit_signal"), SNAME("db_error"), "SDK_ERROR_MSG", error_msg);
		} else if (pending.snapshot_valid && pending.exists) {
			// Convert firebase::Variant → Godot Variant ON MAIN THREAD (root cause fix)
			Variant godot_value = Convertor::fromFirebaseVariant(pending.fb_value);
			String result_key = !key.is_empty() ? key : "";

			// Deep copy for ARM64 alignment safety
			// task-1065 KEEP: main-thread fromFirebaseVariant + deepCopyVariant is the ARM64 guard; GDScript backstop deleted (see convertor.cpp). Do not remove.
			Variant safe_transaction_value = Convertor::deepCopyVariant(godot_value);

			print_verbose(String("[RTDB C++] Transaction ReqID:") + itos(req_id) + " Main thread handler - Success. Committed: Yes.");
			call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), req_id, result_key, safe_transaction_value, true, "");
		} else if (pending.snapshot_valid) {
			print_verbose(String("[RTDB C++] Transaction ReqID:") + itos(req_id) + " Main thread handler - Success (result null). Committed: Yes.");
			call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), req_id, "", Variant(), true, "");
		} else {
			print_error(String("[RTDB C++] Transaction ReqID:") + itos(req_id) + " Main thread handler - Snapshot pointer null");
			call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), req_id, "", Variant(), false, "Snapshot pointer was null");
		}
	} else if (pending.status == firebase::kFutureStatusComplete) {
		String error_code_str = String::num_int64(pending.error);
		print_error(String("[RTDB C++] Transaction ReqID:") + itos(req_id) + " Main thread handler - Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), req_id, "", Variant(), false, error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("db_error"), error_code_str, error_msg);
	} else {
		print_error(String("[RTDB C++] Transaction ReqID:") + itos(req_id) + " Main thread handler - Future did not complete. Status: " + itos(pending.status));
		call_deferred(SNAME("emit_signal"), SNAME("transaction_completed"), req_id, "", Variant(), false, "Firebase Future did not complete.");
		call_deferred(SNAME("emit_signal"), SNAME("db_error"), "FUTURE_INVALID_STATUS", "Transaction future failed to complete.");
	}
}

// --- Listener Main Thread Handlers ---
// These handlers execute on the main thread, safely creating Godot objects
// from raw C++ data stored by listener callbacks on worker threads.

void FirebaseDatabase::_handle_child_event_on_main_thread(int event_id) {
	if (is_app_shutting_down()) {
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		_pending_results.erase(event_id);
		return;
	}

	PendingFirebaseResult pending;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		auto it = _pending_results.find(event_id);
		if (it == _pending_results.end()) {
			return;
		}
		pending = std::move(it->second);
		_pending_results.erase(it);
	}

	// Create Godot objects ON MAIN THREAD (root cause fix for listener crashes)
	Variant godot_value = Convertor::fromFirebaseVariant(pending.fb_value);
	// task-1065 KEEP: main-thread fromFirebaseVariant + deepCopyVariant is the ARM64 guard; GDScript backstop deleted (see convertor.cpp). Do not remove.
	Variant safe_value = Convertor::deepCopyVariant(godot_value);
	String key = String(pending.key.c_str());

	// Determine signal name from event type
	if (pending.event_type == "child_added") {
		print_verbose(String("[RTDB C++] Child Added (main thread): Key='") + key + "'");
		call_deferred(SNAME("emit_signal"), SNAME("child_added"), key, safe_value);
	} else if (pending.event_type == "child_changed") {
		print_verbose(String("[RTDB C++] Child Changed (main thread): Key='") + key + "'");
		call_deferred(SNAME("emit_signal"), SNAME("child_changed"), key, safe_value);
	} else if (pending.event_type == "child_moved") {
		print_verbose(String("[RTDB C++] Child Moved (main thread): Key='") + key + "'");
		call_deferred(SNAME("emit_signal"), SNAME("child_moved"), key, safe_value);
	} else if (pending.event_type == "child_removed") {
		print_verbose(String("[RTDB C++] Child Removed (main thread): Key='") + key + "'");
		call_deferred(SNAME("emit_signal"), SNAME("child_removed"), key, safe_value);
	}
}

void FirebaseDatabase::_handle_connection_state_on_main_thread(int event_id) {
	if (is_app_shutting_down()) {
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		_pending_results.erase(event_id);
		return;
	}

	PendingFirebaseResult pending;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		auto it = _pending_results.find(event_id);
		if (it == _pending_results.end()) {
			return;
		}
		pending = std::move(it->second);
		_pending_results.erase(it);
	}

	if (pending.exists) {
		print_verbose(String("[RTDB C++] Connection state changed (main thread): ") + (pending.is_connected ? "Connected" : "Disconnected"));
	} else {
		WARN_PRINT("[RTDB C++] Received unexpected value for .info/connected state.");
	}
	call_deferred(SNAME("emit_signal"), SNAME("connection_state_changed"), pending.is_connected);
}

void FirebaseDatabase::_handle_listener_error_on_main_thread(int event_id) {
	if (is_app_shutting_down()) {
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		_pending_results.erase(event_id);
		return;
	}

	PendingFirebaseResult pending;
	{
		std::lock_guard<std::mutex> lock(_pending_results_mutex);
		auto it = _pending_results.find(event_id);
		if (it == _pending_results.end()) {
			return;
		}
		pending = std::move(it->second);
		_pending_results.erase(it);
	}

	// Create Godot Strings ON MAIN THREAD
	String error_code_str = String::num_int64(pending.error);
	String error_msg = String(pending.error_msg.c_str());
	print_error(String("[RTDB C++] ") + String(pending.event_type.c_str()) + " Error: " + error_code_str + " Msg: " + error_msg);
	call_deferred(SNAME("emit_signal"), SNAME("db_error"), error_code_str, error_msg);
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
