#ifndef FirebaseAuth_h
#define FirebaseAuth_h

#include "core/object/ref_counted.h"
#include "core/os/os.h"
#include "core/string/ustring.h"
#include "core/variant/variant.h"
#include "core/os/mutex.h"
#include "core/os/memory.h"
#include "firebase.h"
#include "firebase/auth.h"
#include "firebase/auth/user.h"
#include "scene/main/node.h"

#include <atomic>
#include <mutex>

// Forward declaration for AuthStateListener
class GodotAuthStateListener;

class FirebaseAuth : public RefCounted {
	GDCLASS(FirebaseAuth, RefCounted);

	// Allow listener class to access private members
	friend class GodotAuthStateListener;

private:
	// Thread-safe singleton implementation (matches database.h pattern)
	static std::mutex initialization_mutex;
	static std::atomic<bool> inited;
	static std::atomic<bool> is_shutting_down;
	static FirebaseAuth* singleton_instance;
	static std::mutex instance_mutex;

	// Static Firebase resources
	static firebase::auth::Auth *auth;

	// AuthStateListener (Task-420)
	static GodotAuthStateListener* auth_state_listener;
	static std::atomic<bool> auth_state_listener_active;

	// Private constructor for singleton pattern
	FirebaseAuth();

protected:
	static void _bind_methods();

	// Main thread callback handlers (MessageQueue marshalling)
	void _handle_sign_in_on_main_thread(int req_id, bool success, String uid, int error, String error_msg);
	void _handle_link_on_main_thread(int req_id, bool success, int error, String error_msg);
	void _handle_unlink_on_main_thread(int req_id, bool success, int error, String error_msg);
	void _handle_custom_token_on_main_thread(int req_id, bool success, String uid, int error, String error_msg);
	void _handle_id_token_on_main_thread(int req_id, bool success, String token, String error_msg);

	// AuthStateListener callback handler (Task-420)
	void _handle_auth_state_changed_on_main_thread(bool is_signed_in, String uid);

public:
	// Thread-safe singleton access methods
	static FirebaseAuth& get_instance();
	static void cleanup();

	// macOS crash prevention - shutdown control methods
	static void begin_shutdown();
	static bool is_app_shutting_down();

	// Delete copy constructor for singleton pattern
	FirebaseAuth(const FirebaseAuth&) = delete;
	~FirebaseAuth();

	// --- Sync state getters ---
	Array providers();
	bool is_logged_in();
	String user_name();
	String email();
	String uid();
	String photo_url();
	void sign_out();

	// --- New Async Methods with Request IDs ---
	void sign_in_anonymously_async(int p_request_id);
	void sign_in_facebook_async(int p_request_id, String token);
	void sign_in_apple_async(int p_request_id, String token, String nonce);
	void sign_in_with_custom_token_async(int p_request_id, String token);
	void sign_in_with_email_async(int p_request_id, String email, String password);
	void get_id_token_async(int p_request_id, bool force_refresh);
	void link_facebook_async(int p_request_id, String token);
	void link_apple_async(int p_request_id, String token, String nonce);
	void unlink_provider_async(int p_request_id, String provider_name);

	// --- AuthStateListener Methods (Task-420) ---
	void start_auth_state_listener();
	void stop_auth_state_listener();
	bool is_auth_state_listener_active();
};

#endif // FirebaseAuth_h
