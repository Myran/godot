// godot/modules/firebase/remote_config.cpp
#include "remote_config.h"
#include "convertor.h"
#include "firebase.h"

// Godot Core Headers
#include "core/io/json.h" // For JSON parsing in get_json()
#include "core/object/class_db.h"
#include "core/object/message_queue.h" // For thread-safe callback marshalling
#include "core/string/print_string.h"
#include "core/variant/callable.h"
#include "core/variant/variant.h"

// Firebase SDK Headers
#include "firebase/app.h"
#include "firebase/future.h"
#include "firebase/remote_config.h"

#include <vector>

// --- Thread-Safe Singleton Member Initialization ---
std::mutex FirebaseRemoteConfig::initialization_mutex;
std::atomic<bool> FirebaseRemoteConfig::inited(false);
std::atomic<bool> FirebaseRemoteConfig::is_shutting_down(false);
std::atomic<bool> FirebaseRemoteConfig::data_loaded(false);
FirebaseRemoteConfig* FirebaseRemoteConfig::singleton_instance = nullptr;
std::mutex FirebaseRemoteConfig::instance_mutex;
firebase::remote_config::RemoteConfig* FirebaseRemoteConfig::rc = nullptr;

// --- Thread-Safe Singleton Implementation ---

FirebaseRemoteConfig& FirebaseRemoteConfig::get_instance() {
	std::lock_guard<std::mutex> lock(instance_mutex);

	if (!singleton_instance) {
		singleton_instance = new FirebaseRemoteConfig();
	}
	return *singleton_instance;
}

void FirebaseRemoteConfig::cleanup() {
	std::lock_guard<std::mutex> lock(instance_mutex);

	if (singleton_instance) {
		delete singleton_instance;
		singleton_instance = nullptr;
	}
}

void FirebaseRemoteConfig::begin_shutdown() {
	is_shutting_down.store(true);
	print_line("[RemConf] FirebaseRemoteConfig shutdown initiated - blocking further callbacks");
}

bool FirebaseRemoteConfig::is_app_shutting_down() {
	return is_shutting_down.load();
}

// --- Private Constructor (Thread-Safe Init) ---

FirebaseRemoteConfig::FirebaseRemoteConfig() {
	print_line("[RemConf] FirebaseRemoteConfig Singleton Constructor called.");

	// Thread-safe double-checked locking pattern
	if (!inited.load()) {
		std::lock_guard<std::mutex> init_lock(initialization_mutex);

		// Check again after acquiring lock (double-checked locking)
		if (!inited.load()) {
			print_line("[RemConf] Thread-safe initializing Firebase Remote Config Module...");
			firebase::App* app = Firebase::AppId();
			if (app != nullptr) {
				rc = firebase::remote_config::RemoteConfig::GetInstance(app);

				if (rc != nullptr) {
					print_line("[RemConf] Remote Config instance obtained successfully.");

					// SDK-owned throttle (task-1009): release default 12h. Dev builds
					// drop to 0 via set_instant_fetching() from the GDScript service
					// (OS.is_debug_build). Canonical Firebase Strategy 3 — within the
					// interval the SDK serves cache as success; the GDScript throttle
					// reimplementation is deleted. Non-blocking OnCompletion (no busy
					// wait — a hung settings future must never freeze boot).
					firebase::remote_config::ConfigSettings settings;
					settings.minimum_fetch_interval_in_milliseconds = 43200000;  // 12h release default
					rc->SetConfigSettings(settings).OnCompletion(
						[](const firebase::Future<void>& settings_future) {
							if (settings_future.error() == 0) {
								print_line("[RemConf] Config settings applied: minimum_fetch_interval = 12h (SDK-owned)");
							} else {
								print_error(String("[RemConf] Failed to set config settings: ") +
									String::utf8(settings_future.error_message()));
							}
						});

					inited.store(true);
					print_line("[RemConf] Firebase Remote Config Module initialized successfully (thread-safe).");
				} else {
					print_error("[RemConf] Failed to get Remote Config instance (GetInstance returned null).");
				}
			} else {
				print_error("[RemConf] Firebase App not available for Remote Config.");
			}
		}
	}
}

FirebaseRemoteConfig::~FirebaseRemoteConfig() {
	print_line("[RemConf] FirebaseRemoteConfig Destructor called.");

	std::lock_guard<std::mutex> cleanup_lock(instance_mutex);

	// Reset Remote Config instance reference
	rc = nullptr;

	// Reset state flags
	data_loaded.store(false);
	inited.store(false);

	print_line("[RemConf] FirebaseRemoteConfig cleanup completed.");
}

// --- Existing Methods (PRESERVED with improvements) ---

void FirebaseRemoteConfig::set_instant_fetching() {
	if (!rc) {
		print_error("[RemConf] Remote Config not initialized.");
		return;
	}
	print_line("[RemConf] Setting fetch interval to 0 (developer mode)");
	firebase::remote_config::ConfigSettings settings;
	settings.minimum_fetch_interval_in_milliseconds = 0;
	rc->SetConfigSettings(settings);
}

void FirebaseRemoteConfig::set_defaults(const Dictionary& params) {
	if (!rc) {
		print_error("[RemConf] Remote Config not initialized.");
		return;
	}
	print_line("[RemConf] set_defaults Started");

	std::vector<firebase::remote_config::ConfigKeyValueVariant> defaults_vector;
	defaults_vector.reserve(params.size());

	Array keys = params.keys();
	for (int i = 0; i < keys.size(); ++i) {
		Variant key = keys[i];
		Variant val = params[key];
		if (key.get_type() != Variant::STRING) {
			continue;
		}
		firebase::remote_config::ConfigKeyValueVariant ckv;
		// CRITICAL: Store CharString to extend lifetime (UTF-8 safety pattern)
		CharString key_cs = ((String)key).utf8();
		ckv.key = key_cs.get_data();
		ckv.value = Convertor::toFirebaseVariant(val);
		if (!ckv.value.is_null()) {
			defaults_vector.push_back(ckv);
		}
	}

	if (!defaults_vector.empty()) {
		rc->SetDefaults(defaults_vector.data(), defaults_vector.size()).OnCompletion(
			[](const firebase::Future<void>& future) {
				if (future.status() == firebase::kFutureStatusComplete && future.error() == 0) {
					print_line("[RemConf] set_defaults completed successfully.");
				} else {
					const char* msg = future.error_message() ? future.error_message() : "Unknown error";
					print_error(String("[RemConf] set_defaults failed. Error: ") + String::num_int64(future.error()) + " - " + msg);
				}
			});
	} else {
		print_line("[RemConf] No valid defaults provided to set_defaults.");
	}
}

// --- NEW: Async set_defaults with completion signal ---

void FirebaseRemoteConfig::set_defaults_async(int p_request_id, const Dictionary& params) {
	if (!inited.load() || !rc) {
		print_error("[RemConf] SetDefaults failed: Remote Config not initialized.");
		call_deferred(SNAME("emit_signal"), SNAME("set_defaults_completed"), p_request_id, false, -1, "Remote Config not initialized.");
		return;
	}

	print_line(String("[RemConf] SetDefaults ReqID:") + itos(p_request_id) + " started.");

	// CRITICAL FIX: Store both CharStrings and ConfigKeyValueVariant to extend lifetime
	// The CharStrings must live until SetDefaults completes, otherwise ckv.key becomes dangling
	struct DefaultsData {
		std::vector<firebase::remote_config::ConfigKeyValueVariant>* variants;
		std::vector<CharString>* key_strings;  // Keep CharStrings alive
	};

	DefaultsData* defaults_data = new DefaultsData();
	defaults_data->variants = new std::vector<firebase::remote_config::ConfigKeyValueVariant>();
	defaults_data->key_strings = new std::vector<CharString>();
	defaults_data->variants->reserve(params.size());
	defaults_data->key_strings->reserve(params.size());

	Array keys = params.keys();
	for (int i = 0; i < keys.size(); ++i) {
		Variant key = keys[i];
		Variant val = params[key];
		if (key.get_type() != Variant::STRING) {
			continue;
		}
		firebase::remote_config::ConfigKeyValueVariant ckv;
		// CRITICAL: Store CharString in vector to extend lifetime until callback completes
		defaults_data->key_strings->push_back(((String)key).utf8());
		ckv.key = defaults_data->key_strings->back().get_data();
		ckv.value = Convertor::toFirebaseVariant(val);
		if (!ckv.value.is_null()) {
			defaults_data->variants->push_back(ckv);
		}
	}

	if (defaults_data->variants->empty()) {
		print_line("[RemConf] No valid defaults provided to set_defaults_async.");
		call_deferred(SNAME("emit_signal"), SNAME("set_defaults_completed"), p_request_id, false, -1, "No valid defaults provided.");
		delete defaults_data->variants;
		delete defaults_data->key_strings;
		delete defaults_data;
		return;
	}

	// Pass the vector to the Future and capture it for cleanup in the callback
	rc->SetDefaults(defaults_data->variants->data(), defaults_data->variants->size()).OnCompletion(
		[this, p_request_id, defaults_data](const firebase::Future<void>& future) {
			// WORKER THREAD - Extract thread-safe data only
			int error = future.error();
			int status = future.status();
			String error_msg = future.error_message() ? String(future.error_message()) : "";
			bool success = (status == firebase::kFutureStatusComplete && error == 0);

			// Clean up the defaults data (both variants and key strings)
			delete defaults_data->variants;
			delete defaults_data->key_strings;
			delete defaults_data;

			// Marshal to main thread (NO Godot operations on worker thread!)
			MessageQueue::get_singleton()->push_callable(
				callable_mp(this, &FirebaseRemoteConfig::_handle_set_defaults_on_main_thread)
					.bind(p_request_id, success, error, error_msg)
			);
		});
}

// Main thread handler for set_defaults completion
void FirebaseRemoteConfig::_handle_set_defaults_on_main_thread(int req_id, bool success, int error, String error_msg) {
	if (is_shutting_down.load()) {
		print_line(String("[RemConf] SetDefaults ReqID:") + itos(req_id) + " skipped (shutting down).");
		return;
	}

	if (success) {
		print_line(String("[RemConf] SetDefaults ReqID:") + itos(req_id) + " Success.");
		data_loaded.store(true);  // Mark config as loaded so get_* functions return actual values
	} else {
		print_error(String("[RemConf] SetDefaults ReqID:") + itos(req_id) + " failed. Error: " + itos(error) + " - " + error_msg);
	}

	emit_signal("set_defaults_completed", req_id, success, error, error_msg);
}

// Helper function to convert ValueSource enum to readable string
static String value_source_to_string(firebase::remote_config::ValueSource source) {
	switch (source) {
		case firebase::remote_config::kValueSourceStaticValue:
			return "STATIC";
		case firebase::remote_config::kValueSourceRemoteValue:
			return "REMOTE";
		case firebase::remote_config::kValueSourceDefaultValue:
			return "DEFAULT";
		default:
			return "UNKNOWN";
	}
}

bool FirebaseRemoteConfig::get_boolean(const String& param) {
	if (!rc) return false;
	CharString cs = param.utf8();
	firebase::remote_config::ValueInfo info;
	bool value = rc->GetBoolean(cs.get_data(), &info);
	print_verbose(String("[RemConf] get_boolean('") + param + "') = " + (value ? "true" : "false") +
		" [source: " + value_source_to_string(info.source) + "]");
	return value;
}

double FirebaseRemoteConfig::get_double(const String& param) {
	if (!rc) return 0.0;
	CharString cs = param.utf8();
	firebase::remote_config::ValueInfo info;
	double value = rc->GetDouble(cs.get_data(), &info);
	print_verbose(String("[RemConf] get_double('") + param + "') = " + String::num(value) +
		" [source: " + value_source_to_string(info.source) + "]");
	return value;
}

int64_t FirebaseRemoteConfig::get_int(const String& param) {
	if (!rc) return 0;
	CharString cs = param.utf8();
	firebase::remote_config::ValueInfo info;
	int64_t value = rc->GetLong(cs.get_data(), &info);
	print_verbose(String("[RemConf] get_int('") + param + "') = " + String::num_int64(value) +
		" [source: " + value_source_to_string(info.source) + "]");
	return value;
}

String FirebaseRemoteConfig::get_string(const String& param) {
	if (!rc) return "";
	CharString cs = param.utf8();
	firebase::remote_config::ValueInfo info;
	std::string value = rc->GetString(cs.get_data(), &info);
	print_verbose(String("[RemConf] get_string('") + param + "') = '" + String::utf8(value.c_str()) + "'" +
		" [source: " + value_source_to_string(info.source) + "]");
	return String::utf8(value.c_str());
}

bool FirebaseRemoteConfig::loaded() {
	return data_loaded.load();
}

// --- NEW: Async Methods with Request ID ---

void FirebaseRemoteConfig::fetch_and_activate_async(int p_request_id) {
	if (!inited.load() || !rc) {
		print_error("[RemConf] FetchAndActivate failed: Remote Config not initialized.");
		call_deferred(SNAME("emit_signal"), SNAME("fetch_and_activate_completed"), p_request_id, false, false, "Remote Config not initialized.");
		return;
	}

	// Log current config settings
	firebase::remote_config::ConfigSettings current_settings = rc->GetConfigSettings();
	print_line(String("[RemConf] FetchAndActivate ReqID:") + itos(p_request_id) + " started.");
	print_line(String("[RemConf] Current minimum_fetch_interval: ") +
		String::num_int64(current_settings.minimum_fetch_interval_in_milliseconds) + "ms");

	firebase::Future<bool> future = rc->FetchAndActivate();
	future.OnCompletion([this, p_request_id](const firebase::Future<bool>& result) {
		// WORKER THREAD - Extract thread-safe data only
		int error = result.error();
		int status = result.status();
		String error_msg = result.error_message() ? String(result.error_message()) : "";
		bool success = (status == firebase::kFutureStatusComplete && error == 0);
		bool activated = success && result.result() != nullptr && *result.result();

		if (success) {
			data_loaded.store(true);
		}

		// Marshal to main thread (NO Godot operations on worker thread!)
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseRemoteConfig::_handle_fetch_and_activate_on_main_thread)
				.bind(p_request_id, success, activated, error, error_msg)
		);
	});
}

void FirebaseRemoteConfig::fetch_async(int p_request_id) {
	if (!inited.load() || !rc) {
		print_error("[RemConf] Fetch failed: Remote Config not initialized.");
		call_deferred(SNAME("emit_signal"), SNAME("fetch_completed"), p_request_id, false, "Remote Config not initialized.");
		return;
	}

	print_line(String("[RemConf] Fetch ReqID:") + itos(p_request_id) + " started (SDK-owned interval; cache served as success within window).");

	// Respect the configured minimum_fetch_interval (task-1009). Within the
	// window the SDK serves cache as success — no force-fresh, no GDScript
	// throttle. Dev builds set the interval to 0 via set_instant_fetching().
	firebase::Future<void> future = rc->Fetch();
	future.OnCompletion([this, p_request_id](const firebase::Future<void>& result) {
		// WORKER THREAD - Extract thread-safe data only
		int error = result.error();
		int status = result.status();
		String error_msg = result.error_message() ? String(result.error_message()) : "";
		bool success = (status == firebase::kFutureStatusComplete && error == 0);

		// Marshal to main thread
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseRemoteConfig::_handle_fetch_on_main_thread)
				.bind(p_request_id, success, error, error_msg)
		);
	});
}

void FirebaseRemoteConfig::activate_async(int p_request_id) {
	if (!inited.load() || !rc) {
		print_error("[RemConf] Activate failed: Remote Config not initialized.");
		call_deferred(SNAME("emit_signal"), SNAME("activate_completed"), p_request_id, false, false, "Remote Config not initialized.");
		return;
	}

	print_line(String("[RemConf] Activate ReqID:") + itos(p_request_id) + " started.");

	firebase::Future<bool> future = rc->Activate();
	future.OnCompletion([this, p_request_id](const firebase::Future<bool>& result) {
		// WORKER THREAD - Extract thread-safe data only
		int error = result.error();
		int status = result.status();
		String error_msg = result.error_message() ? String(result.error_message()) : "";
		bool success = (status == firebase::kFutureStatusComplete && error == 0);
		bool activated = success && result.result() != nullptr && *result.result();

		if (success) {
			data_loaded.store(true);
		}

		// Marshal to main thread
		MessageQueue::get_singleton()->push_callable(
			callable_mp(this, &FirebaseRemoteConfig::_handle_activate_on_main_thread)
				.bind(p_request_id, success, activated, error, error_msg)
		);
	});
}

// --- NEW: Key Enumeration ---

Array FirebaseRemoteConfig::get_keys() {
	Array result;
	if (!rc) {
		print_error("[RemConf] get_keys failed: Remote Config not initialized.");
		return result;
	}

	std::vector<std::string> keys = rc->GetKeys();
	for (const auto& key : keys) {
		result.append(String::utf8(key.c_str()));
	}

	print_verbose(String("[RemConf] get_keys returned ") + itos(result.size()) + " keys.");
	return result;
}

Array FirebaseRemoteConfig::get_keys_by_prefix(const String& prefix) {
	Array result;
	if (!rc) {
		print_error("[RemConf] get_keys_by_prefix failed: Remote Config not initialized.");
		return result;
	}

	CharString prefix_cs = prefix.utf8();
	std::vector<std::string> keys = rc->GetKeysByPrefix(prefix_cs.get_data());
	for (const auto& key : keys) {
		result.append(String::utf8(key.c_str()));
	}

	print_verbose(String("[RemConf] get_keys_by_prefix('") + prefix + "') returned " + itos(result.size()) + " keys.");
	return result;
}

// --- NEW: Fetch Info ---

Dictionary FirebaseRemoteConfig::get_fetch_info() {
	Dictionary info;
	if (!rc) {
		print_error("[RemConf] get_fetch_info failed: Remote Config not initialized.");
		info["error"] = "Remote Config not initialized";
		return info;
	}

	const firebase::remote_config::ConfigInfo& rc_info = rc->GetInfo();

	info["fetch_time"] = static_cast<int64_t>(rc_info.fetch_time);
	info["throttled_end_time"] = static_cast<int64_t>(rc_info.throttled_end_time);

	// Convert LastFetchStatus enum to string
	String status_str;
	switch (rc_info.last_fetch_status) {
		case firebase::remote_config::kLastFetchStatusSuccess:
			status_str = "success";
			break;
		case firebase::remote_config::kLastFetchStatusFailure:
			status_str = "failure";
			break;
		case firebase::remote_config::kLastFetchStatusPending:
			status_str = "pending";
			break;
		default:
			status_str = "unknown";
			break;
	}
	info["last_fetch_status"] = status_str;

	// Convert FetchFailureReason enum to string
	String failure_reason_str;
	switch (rc_info.last_fetch_failure_reason) {
		case firebase::remote_config::kFetchFailureReasonInvalid:
			failure_reason_str = "invalid";
			break;
		case firebase::remote_config::kFetchFailureReasonThrottled:
			failure_reason_str = "throttled";
			break;
		case firebase::remote_config::kFetchFailureReasonError:
			failure_reason_str = "error";
			break;
		default:
			failure_reason_str = "none";
			break;
	}
	info["last_fetch_failure_reason"] = failure_reason_str;

	return info;
}

// --- NEW: Value Info for debugging platform differences ---

Dictionary FirebaseRemoteConfig::get_value_info(const String& param) {
	Dictionary result;
	if (!rc) {
		print_error("[RemConf] get_value_info failed: Remote Config not initialized.");
		result["error"] = "Remote Config not initialized";
		return result;
	}

	CharString cs = param.utf8();
	firebase::remote_config::ValueInfo info;
	std::string value = rc->GetString(cs.get_data(), &info);

	result["key"] = param;
	result["value"] = String::utf8(value.c_str());

	// Convert source to readable string
	String source_str;
	switch (info.source) {
		case firebase::remote_config::kValueSourceStaticValue:
			source_str = "static";
			break;
		case firebase::remote_config::kValueSourceRemoteValue:
			source_str = "remote";
			break;
		case firebase::remote_config::kValueSourceDefaultValue:
			source_str = "default";
			break;
		default:
			source_str = "unknown";
			break;
	}
	result["source"] = source_str;

	return result;
}

// --- NEW: Dump all config for debugging ---

Dictionary FirebaseRemoteConfig::dump_all_config() {
	Dictionary result;
	if (!rc) {
		print_error("[RemConf] dump_all_config failed: Remote Config not initialized.");
		result["error"] = "Remote Config not initialized";
		return result;
	}

	// Get App info
	firebase::App* app = Firebase::AppId();
	if (app) {
		const firebase::AppOptions& options = app->options();
		Dictionary app_info;
		app_info["name"] = String::utf8(app->name());
		app_info["project_id"] = String::utf8(options.project_id());
		app_info["app_id"] = String::utf8(options.app_id());
		app_info["api_key"] = String::utf8(options.api_key());
		result["app"] = app_info;
	}

	// Get fetch info
	const firebase::remote_config::ConfigInfo& config_info = rc->GetInfo();
	Dictionary fetch_info;
	fetch_info["fetch_time"] = static_cast<int64_t>(config_info.fetch_time);
	fetch_info["throttled_end_time"] = static_cast<int64_t>(config_info.throttled_end_time);
	fetch_info["last_fetch_status"] = static_cast<int64_t>(config_info.last_fetch_status);
	fetch_info["last_fetch_failure_reason"] = static_cast<int64_t>(config_info.last_fetch_failure_reason);
	result["fetch_info"] = fetch_info;

	// Get all keys with their values and sources
	Dictionary values;
	std::vector<std::string> keys = rc->GetKeys();
	result["key_count"] = static_cast<int64_t>(keys.size());

	for (const auto& key : keys) {
		firebase::remote_config::ValueInfo info;
		std::string value = rc->GetString(key.c_str(), &info);

		Dictionary key_info;
		key_info["value"] = String::utf8(value.c_str());

		String source_str;
		switch (info.source) {
			case firebase::remote_config::kValueSourceStaticValue:
				source_str = "static";
				break;
			case firebase::remote_config::kValueSourceRemoteValue:
				source_str = "remote";
				break;
			case firebase::remote_config::kValueSourceDefaultValue:
				source_str = "default";
				break;
			default:
				source_str = "unknown";
				break;
		}
		key_info["source"] = source_str;

		values[String::utf8(key.c_str())] = key_info;
	}
	result["values"] = values;

	return result;
}

// --- NEW: JSON Value Support ---

Dictionary FirebaseRemoteConfig::get_json(const String& param) {
	Dictionary result;
	if (!rc) {
		print_error("[RemConf] get_json failed: Remote Config not initialized.");
		return result;
	}

	CharString cs = param.utf8();
	std::string json_str = rc->GetString(cs.get_data());

	if (json_str.empty()) {
		print_verbose(String("[RemConf] get_json('") + param + "') returned empty string.");
		return result;
	}

	// Parse JSON string to Variant using Godot's JSON class
	String godot_str = String::utf8(json_str.c_str());

	// Use Godot's JSON parsing
	Ref<JSON> json;
	json.instantiate();
	Error parse_error = json->parse(godot_str);

	if (parse_error != OK) {
		print_error(String("[RemConf] get_json('") + param + "') failed to parse JSON: " + json->get_error_message());
		return result;
	}

	Variant parsed = json->get_data();
	if (parsed.get_type() == Variant::DICTIONARY) {
		result = parsed;
	} else if (parsed.get_type() == Variant::ARRAY) {
		// Wrap array in dictionary for consistency
		result["data"] = parsed;
	} else {
		// Wrap primitive in dictionary
		result["value"] = parsed;
	}

	return result;
}

// --- Main Thread Callback Handlers ---

void FirebaseRemoteConfig::_handle_fetch_and_activate_on_main_thread(
		int req_id,
		bool success,
		bool activated,
		int error,
		String error_msg) {
	// NOW ON MAIN THREAD - Safe for all Godot operations

	if (is_app_shutting_down()) {
		print_line("[RemConf] _handle_fetch_and_activate_on_main_thread skipped - app shutting down");
		return;
	}

	if (success) {
		print_line(String("[RemConf] FetchAndActivate ReqID:") + itos(req_id) + " Success. Activated: " + (activated ? "true" : "false"));
		// Emit legacy "loaded" signal for backward compatibility
		call_deferred(SNAME("emit_signal"), SNAME("loaded"));
		call_deferred(SNAME("emit_signal"), SNAME("fetch_and_activate_completed"), req_id, true, activated, "");
	} else {
		String error_code_str = String::num_int64(error);
		print_error(String("[RemConf] FetchAndActivate ReqID:") + itos(req_id) + " Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("fetch_and_activate_completed"), req_id, false, false, error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("config_error"), error_code_str, error_msg);
	}
}

void FirebaseRemoteConfig::_handle_fetch_on_main_thread(
		int req_id,
		bool success,
		int error,
		String error_msg) {
	// NOW ON MAIN THREAD

	if (is_app_shutting_down()) {
		print_line("[RemConf] _handle_fetch_on_main_thread skipped - app shutting down");
		return;
	}

	if (success) {
		print_line(String("[RemConf] Fetch ReqID:") + itos(req_id) + " Success.");
		call_deferred(SNAME("emit_signal"), SNAME("fetch_completed"), req_id, true, "");
	} else {
		String error_code_str = String::num_int64(error);
		print_error(String("[RemConf] Fetch ReqID:") + itos(req_id) + " Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("fetch_completed"), req_id, false, error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("config_error"), error_code_str, error_msg);
	}
}

void FirebaseRemoteConfig::_handle_activate_on_main_thread(
		int req_id,
		bool success,
		bool activated,
		int error,
		String error_msg) {
	// NOW ON MAIN THREAD

	if (is_app_shutting_down()) {
		print_line("[RemConf] _handle_activate_on_main_thread skipped - app shutting down");
		return;
	}

	if (success) {
		print_line(String("[RemConf] Activate ReqID:") + itos(req_id) + " Success. Activated: " + (activated ? "true" : "false"));
		call_deferred(SNAME("emit_signal"), SNAME("activate_completed"), req_id, true, activated, "");
	} else {
		String error_code_str = String::num_int64(error);
		print_error(String("[RemConf] Activate ReqID:") + itos(req_id) + " Error: " + error_code_str + " Msg: " + error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("activate_completed"), req_id, false, false, error_msg);
		call_deferred(SNAME("emit_signal"), SNAME("config_error"), error_code_str, error_msg);
	}
}

// --- Bind Methods ---

void FirebaseRemoteConfig::_bind_methods() {
	// === Existing Methods (PRESERVED) ===
	ClassDB::bind_method(D_METHOD("set_instant_fetching"), &FirebaseRemoteConfig::set_instant_fetching);
	ClassDB::bind_method(D_METHOD("set_defaults", "params"), &FirebaseRemoteConfig::set_defaults);
	ClassDB::bind_method(D_METHOD("get_boolean", "param"), &FirebaseRemoteConfig::get_boolean);
	ClassDB::bind_method(D_METHOD("get_double", "param"), &FirebaseRemoteConfig::get_double);
	ClassDB::bind_method(D_METHOD("get_int", "param"), &FirebaseRemoteConfig::get_int);
	ClassDB::bind_method(D_METHOD("get_string", "param"), &FirebaseRemoteConfig::get_string);
	ClassDB::bind_method(D_METHOD("loaded"), &FirebaseRemoteConfig::loaded);

	// === NEW: Async Methods ===
	ClassDB::bind_method(D_METHOD("set_defaults_async", "request_id", "params"), &FirebaseRemoteConfig::set_defaults_async);
	ClassDB::bind_method(D_METHOD("fetch_and_activate_async", "request_id"), &FirebaseRemoteConfig::fetch_and_activate_async);
	ClassDB::bind_method(D_METHOD("fetch_async", "request_id"), &FirebaseRemoteConfig::fetch_async);
	ClassDB::bind_method(D_METHOD("activate_async", "request_id"), &FirebaseRemoteConfig::activate_async);

	// === NEW: Key Enumeration ===
	ClassDB::bind_method(D_METHOD("get_keys"), &FirebaseRemoteConfig::get_keys);
	ClassDB::bind_method(D_METHOD("get_keys_by_prefix", "prefix"), &FirebaseRemoteConfig::get_keys_by_prefix);

	// === NEW: Utilities ===
	ClassDB::bind_method(D_METHOD("get_fetch_info"), &FirebaseRemoteConfig::get_fetch_info);
	ClassDB::bind_method(D_METHOD("get_json", "param"), &FirebaseRemoteConfig::get_json);

	// === NEW: Debug/Diagnostic Methods ===
	ClassDB::bind_method(D_METHOD("get_value_info", "param"), &FirebaseRemoteConfig::get_value_info);
	ClassDB::bind_method(D_METHOD("dump_all_config"), &FirebaseRemoteConfig::dump_all_config);

	// === Signals ===
	// Legacy signal (backward compatibility)
	ADD_SIGNAL(MethodInfo("loaded"));

	// NEW: Async operation completion signals
	ADD_SIGNAL(MethodInfo("set_defaults_completed",
		PropertyInfo(Variant::INT, "request_id"),
		PropertyInfo(Variant::BOOL, "success"),
		PropertyInfo(Variant::INT, "error_code"),
		PropertyInfo(Variant::STRING, "error_message")));

	ADD_SIGNAL(MethodInfo("fetch_and_activate_completed",
		PropertyInfo(Variant::INT, "request_id"),
		PropertyInfo(Variant::BOOL, "success"),
		PropertyInfo(Variant::BOOL, "activated"),
		PropertyInfo(Variant::STRING, "error_message")));

	ADD_SIGNAL(MethodInfo("fetch_completed",
		PropertyInfo(Variant::INT, "request_id"),
		PropertyInfo(Variant::BOOL, "success"),
		PropertyInfo(Variant::STRING, "error_message")));

	ADD_SIGNAL(MethodInfo("activate_completed",
		PropertyInfo(Variant::INT, "request_id"),
		PropertyInfo(Variant::BOOL, "success"),
		PropertyInfo(Variant::BOOL, "activated"),
		PropertyInfo(Variant::STRING, "error_message")));

	// NEW: Error signal
	ADD_SIGNAL(MethodInfo("config_error",
		PropertyInfo(Variant::STRING, "error_code"),
		PropertyInfo(Variant::STRING, "error_message")));
}
