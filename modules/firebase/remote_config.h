#ifndef FirebaseRemoteConfig_h
#define FirebaseRemoteConfig_h

#include "core/object/ref_counted.h"
#include "core/variant/variant.h"
#include "firebase/remote_config.h"
#include "firebase.h"
#include <atomic>
#include <mutex>

class FirebaseRemoteConfig : public RefCounted {
	GDCLASS(FirebaseRemoteConfig, RefCounted);

private:
	// Thread-safe initialization guard (matching database.h pattern)
	static std::mutex initialization_mutex;
	static std::atomic<bool> inited;

	// Shutdown safety - prevents callbacks during cleanup
	static std::atomic<bool> is_shutting_down;

	// Static Firebase resources
	static firebase::remote_config::RemoteConfig* rc;
	static std::atomic<bool> data_loaded;

	// Private constructor for singleton pattern
	FirebaseRemoteConfig();

protected:
	static void _bind_methods();

	// Main thread callback handlers (MessageQueue marshalling)
	void _handle_fetch_and_activate_on_main_thread(int req_id, bool success, bool activated, int error, String error_msg);
	void _handle_fetch_on_main_thread(int req_id, bool success, int error, String error_msg);
	void _handle_activate_on_main_thread(int req_id, bool success, bool activated, int error, String error_msg);
	void _handle_set_defaults_on_main_thread(int req_id, bool success, int error, String error_msg);

public:
	// Shutdown control methods
	static void begin_shutdown();
	static bool is_app_shutting_down();

	// Delete copy constructor for singleton pattern
	FirebaseRemoteConfig(const FirebaseRemoteConfig&) = delete;

	~FirebaseRemoteConfig();

	// === Existing Methods (PRESERVED) ===
	void set_defaults(const Dictionary& params);
	bool get_boolean(const String& param);
	double get_double(const String& param);
	int64_t get_int(const String& param);
	String get_string(const String& param);
	bool loaded();
	void set_instant_fetching();

	// === NEW: Async Methods with Request ID ===
	void set_defaults_async(int p_request_id, const Dictionary& params);
	void fetch_and_activate_async(int p_request_id);
	void fetch_async(int p_request_id);
	void activate_async(int p_request_id);

	// === NEW: Key Enumeration ===
	Array get_keys();
	Array get_keys_by_prefix(const String& prefix);

	// === NEW: Fetch Info ===
	Dictionary get_fetch_info();

	// === NEW: JSON Value Support ===
	Dictionary get_json(const String& param);

	// === NEW: Debug/Diagnostic Methods ===
	Dictionary get_value_info(const String& param);
	Dictionary dump_all_config();
};

#endif // FirebaseRemoteConfig_h
