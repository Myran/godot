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

class FirebaseAuth : public RefCounted {
	GDCLASS(FirebaseAuth, RefCounted);

private:
	// Thread-safe singleton implementation (matches database.h pattern)
	static std::mutex initialization_mutex;
	static std::atomic<bool> inited;
	static std::atomic<bool> is_shutting_down;
	static FirebaseAuth* singleton_instance;
	static std::mutex instance_mutex;

	// Static Firebase resources
	static firebase::auth::Auth *auth;
	static firebase::auth::User::UserProfile profile;

	// Private constructor for singleton pattern
	FirebaseAuth();

protected:
	static void _bind_methods();
	void link_to_provider(firebase::auth::Credential credential);
	void sign_in_provider(firebase::auth::Credential credential);

	// Main thread callback handlers (MessageQueue marshalling)
	void _handle_sign_in_on_main_thread(int req_id, bool success, String uid, int error, String error_msg);
	void _handle_link_on_main_thread(int req_id, bool success, int error, String error_msg);
	void _handle_unlink_on_main_thread(int req_id, bool success, int error, String error_msg);
	void _handle_custom_token_on_main_thread(int req_id, bool success, String uid, int error, String error_msg);
	void _handle_id_token_on_main_thread(int req_id, bool success, String token, String error_msg);

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

	// --- Existing Methods (preserved) ---
	void sign_in_anonymously();
	void sign_in_facebook(String token);
	void sign_in_apple(String token, String nonce);
	void link_to_facebook(String token);
	void link_to_apple(String token, String nonce);
	void unlink_provider(String provider_name);
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

	// --- Legacy Callbacks (for backward compatibility, to be deprecated) ---
	void OnCreateUserCallback(const firebase::Future<firebase::auth::AuthResult> &result, void *user_data);
	void OnLinkUserCallback(const firebase::Future<firebase::auth::AuthResult> &result, void *user_data);
	void OnUnLinkUserCallback(const firebase::Future<firebase::auth::AuthResult> &result, void *user_data);
};

#endif // FirebaseAuth_h
