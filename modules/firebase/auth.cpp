// godot/modules/firebase/auth.cpp
#include "auth.h"
#include "firebase/auth.h"
#include "firebase/auth/user.h"
#include "core/object/object.h"
#include "core/object/callable_mp.h"
#include "core/object/class_db.h"
#include "core/object/message_queue.h" // For thread-safe callback marshalling
#include "core/string/print_string.h"
#include "core/variant/callable.h"


#if !defined(TRUE)
    #define TRUE	1
#endif

#if !defined(FALSE)
    #define FALSE	0
#endif


// --- AuthStateListener Implementation (Task-420) ---
// Listens for Firebase Auth state changes and marshals callbacks to main thread
class GodotAuthStateListener : public firebase::auth::AuthStateListener {
public:
	GodotAuthStateListener(FirebaseAuth* p_owner) : owner(p_owner) {}

	void OnAuthStateChanged(firebase::auth::Auth* auth) override {
		// WORKER THREAD - Called from Firebase SDK thread
		if (FirebaseAuth::is_app_shutting_down()) {
			print_line("[Auth] AuthStateListener: Ignoring callback during shutdown");
			return;
		}

		if (!auth) {
			print_line("[Auth] AuthStateListener: Auth is null");
			return;
		}

		firebase::auth::User user = auth->current_user();
		bool is_signed_in = user.is_valid();
		String uid_str = "";

		if (is_signed_in) {
			uid_str = String(user.uid().c_str());
			print_line(String("[Auth] AuthStateListener: User signed in. UID: ") + uid_str);
		} else {
			print_line("[Auth] AuthStateListener: User signed out");
		}

		// Marshal to main thread via MessageQueue
		MessageQueue::get_singleton()->push_callable(
			callable_mp(owner, &FirebaseAuth::_handle_auth_state_changed_on_main_thread)
				.bind(is_signed_in, uid_str)
		);
	}

private:
	FirebaseAuth* owner;
};


// --- Thread-Safe Singleton Member Initialization (matches database.cpp pattern) ---
std::mutex FirebaseAuth::initialization_mutex;
std::atomic<bool> FirebaseAuth::inited(false);
std::atomic<bool> FirebaseAuth::is_shutting_down(false);
Ref<FirebaseAuth> FirebaseAuth::singleton_instance;
std::mutex FirebaseAuth::instance_mutex;

// Static Firebase resources
firebase::auth::Auth* FirebaseAuth::auth = nullptr;

// AuthStateListener resources (Task-420)
GodotAuthStateListener* FirebaseAuth::auth_state_listener = nullptr;
std::atomic<bool> FirebaseAuth::auth_state_listener_active(false);


// --- Thread-Safe Singleton Access (matches database.cpp pattern) ---
FirebaseAuth& FirebaseAuth::get_instance() {
    std::lock_guard<std::mutex> lock(instance_mutex);
    if (singleton_instance.is_null()) {
        singleton_instance = memnew(FirebaseAuth);
    }
    return *singleton_instance.ptr();
}

void FirebaseAuth::cleanup() {
    std::lock_guard<std::mutex> lock(instance_mutex);
    if (singleton_instance.is_valid()) {
        singleton_instance.unref();
    }
}

void FirebaseAuth::begin_shutdown() {
    print_line("[Auth] begin_shutdown called - preventing new callbacks");
    is_shutting_down.store(true);
}

bool FirebaseAuth::is_app_shutting_down() {
    return is_shutting_down.load();
}


// --- Private Constructor (singleton pattern) ---
FirebaseAuth::FirebaseAuth() {
    print_line(String("[Auth] started"));

    // Thread-safe double-checked locking pattern
    if (!inited.load()) {
        std::lock_guard<std::mutex> init_lock(initialization_mutex);

        // Check again after acquiring lock (double-checked locking)
        if (!inited.load()) {
            print_line(String("[Auth] Creating firebase app"));
            firebase::App* app = Firebase::AppId();
            print_line(String("[Auth] firebase app created successfully"));
            if (app != nullptr) {
                print_line(String("[Auth] Creating singleton"));
                auth = firebase::auth::Auth::GetAuth(app);
                inited.store(true);
                print_line("[Auth] Firebase Auth Module initialized successfully (thread-safe).");
            } else {
                print_error("[Auth] Firebase App is not initialized!");
            }
        }
    }
}

FirebaseAuth::~FirebaseAuth() {
    print_line("[Auth] FirebaseAuth Destructor called.");

    std::lock_guard<std::mutex> cleanup_lock(instance_mutex);

    // Stop and clean up AuthStateListener (Task-420)
    if (auth_state_listener && auth) {
        print_line("[Auth] Removing AuthStateListener");
        auth->RemoveAuthStateListener(auth_state_listener);
        delete auth_state_listener;
        auth_state_listener = nullptr;
        auth_state_listener_active.store(false);
    }

    // Reset auth instance reference
    auth = nullptr;

    // Reset initialization flag
    inited.store(false);

    print_line("[Auth] FirebaseAuth complete cleanup completed.");
}


// --- Main Thread Callback Handlers (MessageQueue marshalling) ---

void FirebaseAuth::_handle_sign_in_on_main_thread(int req_id, bool success, String uid, int error, String error_msg) {
    if (is_shutting_down.load()) {
        print_line("[Auth] Ignoring sign_in callback during shutdown");
        return;
    }
    print_line(String("[Auth] Sign in completed on main thread. ReqID: ") + itos(req_id) + " Success: " + (success ? "true" : "false") + " Error code: " + itos(error));
    if (!success) {
        print_line(String("[Auth] Sign in error details - Code: ") + itos(error) + " Message: " + error_msg);
    }
    emit_signal("sign_in_completed", req_id, success, uid, error_msg);
}

void FirebaseAuth::_handle_link_on_main_thread(int req_id, bool success, int error, String error_msg) {
    if (is_shutting_down.load()) {
        print_line("[Auth] Ignoring link callback during shutdown");
        return;
    }
    print_line(String("[Auth] Link completed on main thread. ReqID: ") + itos(req_id) + " Success: " + (success ? "true" : "false"));
    emit_signal("link_completed", req_id, success, error_msg);
}

void FirebaseAuth::_handle_unlink_on_main_thread(int req_id, bool success, int error, String error_msg) {
    if (is_shutting_down.load()) {
        print_line("[Auth] Ignoring unlink callback during shutdown");
        return;
    }
    print_line(String("[Auth] Unlink completed on main thread. ReqID: ") + itos(req_id) + " Success: " + (success ? "true" : "false"));
    emit_signal("unlink_completed", req_id, success, error_msg);
}

void FirebaseAuth::_handle_custom_token_on_main_thread(int req_id, bool success, String uid, int error, String error_msg) {
    if (is_shutting_down.load()) {
        print_line("[Auth] Ignoring custom_token callback during shutdown");
        return;
    }
    print_line(String("[Auth] Custom token sign in completed on main thread. ReqID: ") + itos(req_id) + " Success: " + (success ? "true" : "false"));
    emit_signal("custom_token_sign_in_completed", req_id, success, uid, error_msg);
}

void FirebaseAuth::_handle_id_token_on_main_thread(int req_id, bool success, String token, String error_msg) {
    if (is_shutting_down.load()) {
        print_line("[Auth] Ignoring id_token callback during shutdown");
        return;
    }
    print_line(String("[Auth] ID token result on main thread. ReqID: ") + itos(req_id) + " Success: " + (success ? "true" : "false"));
    emit_signal("id_token_result", req_id, success, token, error_msg);
}

void FirebaseAuth::_handle_auth_state_changed_on_main_thread(bool is_signed_in, String uid) {
    if (is_shutting_down.load()) {
        print_line("[Auth] Ignoring auth_state_changed callback during shutdown");
        return;
    }
    print_line(String("[Auth] Auth state changed on main thread. SignedIn: ") + (is_signed_in ? "true" : "false") + " UID: " + uid);
    emit_signal("auth_state_changed", is_signed_in, uid);
}


// Legacy unmarshalled callbacks + entry points deleted in task-1002 (FB-01).
// They emitted signals from Firebase worker threads (no MessageQueue marshalling)
// and were fully superseded by the *_async methods below. Future Apple/Facebook/
// Steam login builds on the marshalled async API (doc-009, Gate 4/5).

// --- Existing Methods (preserved, with CharString fixes) ---

Array FirebaseAuth::providers()
{
    Array retArray;
    firebase::auth::User current_user = auth->current_user();
   for (std::size_t i = 0; i < current_user.provider_data().size(); ++i)
   {
       print_line(String("[Auth] provider: ") + current_user.provider_data()[i].provider_id().c_str());
        Dictionary tempDict;
        tempDict["name"] = current_user.provider_data()[i].provider_id().c_str();
        retArray.append(tempDict);
   }

    return retArray;
}


bool FirebaseAuth::is_logged_in()
{
    firebase::auth::User current_user = auth->current_user();
    return (current_user.is_valid());
}

String FirebaseAuth::user_name()
{
    firebase::auth::User current_user = auth->current_user();
    return String(current_user.display_name().c_str());
}

String FirebaseAuth::email()
{
    firebase::auth::User current_user = auth->current_user();
    return String(current_user.email().c_str());
}

String FirebaseAuth::uid()
{
    firebase::auth::User current_user = auth->current_user();
    return String(current_user.uid().c_str());
}

String FirebaseAuth::photo_url()
{
    firebase::auth::User current_user = auth->current_user();
    return String(current_user.photo_url().c_str());
}

void FirebaseAuth::sign_out()
{
    auth->SignOut();
}


// --- New Async Methods with Request IDs and MessageQueue Marshalling ---

void FirebaseAuth::sign_in_anonymously_async(int p_request_id)
{
    if (!inited.load() || !auth) {
        print_error("[Auth] sign_in_anonymously_async failed: Auth not initialized.");
        call_deferred(SNAME("emit_signal"), SNAME("sign_in_completed"), p_request_id, false, String(""), String("Auth not initialized"));
        return;
    }

    print_line(String("[Auth] Start async anonymous sign in. ReqID: ") + itos(p_request_id));
    firebase::Future<firebase::auth::AuthResult> result = auth->SignInAnonymously();

    result.OnCompletion([this, p_request_id](const firebase::Future<firebase::auth::AuthResult>& result) {
        // WORKER THREAD - Extract thread-safe data only
        if (is_shutting_down.load()) {
            print_line("[Auth] Ignoring anonymous sign in callback during shutdown");
            return;
        }

        int error = result.error();
        bool success = (error == firebase::auth::kAuthErrorNone);
        String uid_str = "";
        String error_msg = result.error_message() ? String(result.error_message()) : "";

        if (success) {
            const firebase::auth::AuthResult* auth_result = result.result();
            if (auth_result && auth_result->user.is_valid()) {
                uid_str = String(auth_result->user.uid().c_str());
            }
        }

        // Marshal to main thread via MessageQueue
        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseAuth::_handle_sign_in_on_main_thread)
                .bind(p_request_id, success, uid_str, error, error_msg)
        );
    });
}

void FirebaseAuth::sign_in_facebook_async(int p_request_id, String token)
{
    if (!inited.load() || !auth) {
        print_error("[Auth] sign_in_facebook_async failed: Auth not initialized.");
        call_deferred(SNAME("emit_signal"), SNAME("sign_in_completed"), p_request_id, false, String(""), String("Auth not initialized"));
        return;
    }

    print_line(String("[Auth] Start async Facebook sign in. ReqID: ") + itos(p_request_id));

    // CRITICAL: Store CharString to extend lifetime (Task-399)
    CharString token_cs = token.utf8();
    firebase::auth::Credential credential = firebase::auth::FacebookAuthProvider::GetCredential(token_cs.get_data());

    firebase::Future<firebase::auth::AuthResult> result = auth->SignInAndRetrieveDataWithCredential(credential);

    result.OnCompletion([this, p_request_id](const firebase::Future<firebase::auth::AuthResult>& result) {
        if (is_shutting_down.load()) return;

        int error = result.error();
        bool success = (error == firebase::auth::kAuthErrorNone);
        String uid_str = "";
        String error_msg = result.error_message() ? String(result.error_message()) : "";

        if (success) {
            const firebase::auth::AuthResult* auth_result = result.result();
            if (auth_result && auth_result->user.is_valid()) {
                uid_str = String(auth_result->user.uid().c_str());
            }
        }

        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseAuth::_handle_sign_in_on_main_thread)
                .bind(p_request_id, success, uid_str, error, error_msg)
        );
    });
}

void FirebaseAuth::sign_in_apple_async(int p_request_id, String token, String nonce)
{
    if (!inited.load() || !auth) {
        print_error("[Auth] sign_in_apple_async failed: Auth not initialized.");
        call_deferred(SNAME("emit_signal"), SNAME("sign_in_completed"), p_request_id, false, String(""), String("Auth not initialized"));
        return;
    }

    print_line(String("[Auth] Start async Apple sign in. ReqID: ") + itos(p_request_id));

    // CRITICAL: Store CharString to extend lifetime (Task-399)
    CharString token_cs = token.utf8();
    CharString nonce_cs = nonce.utf8();
    firebase::auth::Credential credential = firebase::auth::OAuthProvider::GetCredential(
        "apple.com", token_cs.get_data(), nonce_cs.get_data(), nullptr);

    firebase::Future<firebase::auth::AuthResult> result = auth->SignInAndRetrieveDataWithCredential(credential);

    result.OnCompletion([this, p_request_id](const firebase::Future<firebase::auth::AuthResult>& result) {
        if (is_shutting_down.load()) return;

        int error = result.error();
        bool success = (error == firebase::auth::kAuthErrorNone);
        String uid_str = "";
        String error_msg = result.error_message() ? String(result.error_message()) : "";

        if (success) {
            const firebase::auth::AuthResult* auth_result = result.result();
            if (auth_result && auth_result->user.is_valid()) {
                uid_str = String(auth_result->user.uid().c_str());
            }
        }

        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseAuth::_handle_sign_in_on_main_thread)
                .bind(p_request_id, success, uid_str, error, error_msg)
        );
    });
}

void FirebaseAuth::sign_in_with_custom_token_async(int p_request_id, String token)
{
    if (!inited.load() || !auth) {
        print_error("[Auth] sign_in_with_custom_token_async failed: Auth not initialized.");
        call_deferred(SNAME("emit_signal"), SNAME("custom_token_sign_in_completed"), p_request_id, false, String(""), String("Auth not initialized"));
        return;
    }

    print_line(String("[Auth] Start async custom token sign in. ReqID: ") + itos(p_request_id));

    // CRITICAL: Store CharString to extend lifetime (Task-399)
    CharString token_cs = token.utf8();

    firebase::Future<firebase::auth::AuthResult> result = auth->SignInWithCustomToken(token_cs.get_data());

    result.OnCompletion([this, p_request_id](const firebase::Future<firebase::auth::AuthResult>& result) {
        if (is_shutting_down.load()) return;

        int error = result.error();
        bool success = (error == firebase::auth::kAuthErrorNone);
        String uid_str = "";
        String error_msg = result.error_message() ? String(result.error_message()) : "";

        if (success) {
            const firebase::auth::AuthResult* auth_result = result.result();
            if (auth_result && auth_result->user.is_valid()) {
                uid_str = String(auth_result->user.uid().c_str());
            }
        }

        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseAuth::_handle_custom_token_on_main_thread)
                .bind(p_request_id, success, uid_str, error, error_msg)
        );
    });
}

void FirebaseAuth::sign_in_with_email_async(int p_request_id, String email, String password)
{
    if (!inited.load() || !auth) {
        print_error("[Auth] sign_in_with_email_async failed: Auth not initialized.");
        call_deferred(SNAME("emit_signal"), SNAME("sign_in_completed"), p_request_id, false, String(""), String("Auth not initialized"));
        return;
    }

    print_line(String("[Auth] Start async email sign in. ReqID: ") + itos(p_request_id));

    // CRITICAL: Store CharString to extend lifetime (Task-419)
    CharString email_cs = email.utf8();
    CharString password_cs = password.utf8();

    firebase::Future<firebase::auth::AuthResult> result = auth->SignInWithEmailAndPassword(email_cs.get_data(), password_cs.get_data());

    result.OnCompletion([this, p_request_id](const firebase::Future<firebase::auth::AuthResult>& result) {
        if (is_shutting_down.load()) {
            print_line("[Auth] Ignoring email sign in callback during shutdown");
            return;
        }

        int error = result.error();
        bool success = (error == firebase::auth::kAuthErrorNone);
        String uid_str = "";
        String error_msg = result.error_message() ? String(result.error_message()) : "";

        if (success) {
            const firebase::auth::AuthResult* auth_result = result.result();
            if (auth_result && auth_result->user.is_valid()) {
                uid_str = String(auth_result->user.uid().c_str());
            }
        }

        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseAuth::_handle_sign_in_on_main_thread)
                .bind(p_request_id, success, uid_str, error, error_msg)
        );
    });
}

void FirebaseAuth::get_id_token_async(int p_request_id, bool force_refresh)
{
    if (!inited.load() || !auth) {
        print_error("[Auth] get_id_token_async failed: Auth not initialized.");
        call_deferred(SNAME("emit_signal"), SNAME("id_token_result"), p_request_id, false, String(""), String("Auth not initialized"));
        return;
    }

    firebase::auth::User current_user = auth->current_user();
    if (!current_user.is_valid()) {
        print_error("[Auth] get_id_token_async failed: No user logged in.");
        call_deferred(SNAME("emit_signal"), SNAME("id_token_result"), p_request_id, false, String(""), String("No user logged in"));
        return;
    }

    print_line(String("[Auth] Start async get ID token. ReqID: ") + itos(p_request_id) + " ForceRefresh: " + (force_refresh ? "true" : "false"));

    firebase::Future<std::string> result = current_user.GetToken(force_refresh);

    result.OnCompletion([this, p_request_id](const firebase::Future<std::string>& result) {
        if (is_shutting_down.load()) return;

        int error = result.error();
        bool success = (error == firebase::auth::kAuthErrorNone);
        String token_str = "";
        String error_msg = result.error_message() ? String(result.error_message()) : "";

        if (success && result.result()) {
            token_str = String(result.result()->c_str());
        }

        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseAuth::_handle_id_token_on_main_thread)
                .bind(p_request_id, success, token_str, error_msg)
        );
    });
}

void FirebaseAuth::link_facebook_async(int p_request_id, String token)
{
    if (!inited.load() || !auth) {
        print_error("[Auth] link_facebook_async failed: Auth not initialized.");
        call_deferred(SNAME("emit_signal"), SNAME("link_completed"), p_request_id, false, String("Auth not initialized"));
        return;
    }

    firebase::auth::User current_user = auth->current_user();
    if (!current_user.is_valid()) {
        print_error("[Auth] link_facebook_async failed: No user logged in.");
        call_deferred(SNAME("emit_signal"), SNAME("link_completed"), p_request_id, false, String("No user logged in"));
        return;
    }

    print_line(String("[Auth] Start async Facebook link. ReqID: ") + itos(p_request_id));

    // CRITICAL: Store CharString to extend lifetime (Task-399)
    CharString token_cs = token.utf8();
    firebase::auth::Credential credential = firebase::auth::FacebookAuthProvider::GetCredential(token_cs.get_data());

    firebase::Future<firebase::auth::AuthResult> result = current_user.LinkWithCredential(credential);

    result.OnCompletion([this, p_request_id](const firebase::Future<firebase::auth::AuthResult>& result) {
        if (is_shutting_down.load()) return;

        int error = result.error();
        bool success = (error == firebase::auth::kAuthErrorNone);
        String error_msg = result.error_message() ? String(result.error_message()) : "";

        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseAuth::_handle_link_on_main_thread)
                .bind(p_request_id, success, error, error_msg)
        );
    });
}

void FirebaseAuth::link_apple_async(int p_request_id, String token, String nonce)
{
    if (!inited.load() || !auth) {
        print_error("[Auth] link_apple_async failed: Auth not initialized.");
        call_deferred(SNAME("emit_signal"), SNAME("link_completed"), p_request_id, false, String("Auth not initialized"));
        return;
    }

    firebase::auth::User current_user = auth->current_user();
    if (!current_user.is_valid()) {
        print_error("[Auth] link_apple_async failed: No user logged in.");
        call_deferred(SNAME("emit_signal"), SNAME("link_completed"), p_request_id, false, String("No user logged in"));
        return;
    }

    print_line(String("[Auth] Start async Apple link. ReqID: ") + itos(p_request_id));

    // CRITICAL: Store CharString to extend lifetime (Task-399)
    CharString token_cs = token.utf8();
    CharString nonce_cs = nonce.utf8();
    firebase::auth::Credential credential = firebase::auth::OAuthProvider::GetCredential(
        "apple.com", token_cs.get_data(), nonce_cs.get_data(), nullptr);

    firebase::Future<firebase::auth::AuthResult> result = current_user.LinkWithCredential(credential);

    result.OnCompletion([this, p_request_id](const firebase::Future<firebase::auth::AuthResult>& result) {
        if (is_shutting_down.load()) return;

        int error = result.error();
        bool success = (error == firebase::auth::kAuthErrorNone);
        String error_msg = result.error_message() ? String(result.error_message()) : "";

        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseAuth::_handle_link_on_main_thread)
                .bind(p_request_id, success, error, error_msg)
        );
    });
}

void FirebaseAuth::unlink_provider_async(int p_request_id, String provider_name)
{
    if (!inited.load() || !auth) {
        print_error("[Auth] unlink_provider_async failed: Auth not initialized.");
        call_deferred(SNAME("emit_signal"), SNAME("unlink_completed"), p_request_id, false, String("Auth not initialized"));
        return;
    }

    firebase::auth::User current_user = auth->current_user();
    if (!current_user.is_valid()) {
        print_error("[Auth] unlink_provider_async failed: No user logged in.");
        call_deferred(SNAME("emit_signal"), SNAME("unlink_completed"), p_request_id, false, String("No user logged in"));
        return;
    }

    print_line(String("[Auth] Start async unlink provider. ReqID: ") + itos(p_request_id) + " Provider: " + provider_name);

    // CRITICAL: Store CharString to extend lifetime (Task-399)
    CharString provider_cs = provider_name.utf8();

    firebase::Future<firebase::auth::AuthResult> result = current_user.Unlink(provider_cs.get_data());

    result.OnCompletion([this, p_request_id](const firebase::Future<firebase::auth::AuthResult>& result) {
        if (is_shutting_down.load()) return;

        int error = result.error();
        bool success = (error == firebase::auth::kAuthErrorNone);
        String error_msg = result.error_message() ? String(result.error_message()) : "";

        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseAuth::_handle_unlink_on_main_thread)
                .bind(p_request_id, success, error, error_msg)
        );
    });
}


// --- AuthStateListener Methods (Task-420) ---

void FirebaseAuth::start_auth_state_listener() {
    if (!inited.load() || !auth) {
        print_error("[Auth] start_auth_state_listener failed: Auth not initialized.");
        return;
    }

    if (auth_state_listener_active.load()) {
        print_line("[Auth] AuthStateListener already active, ignoring start request.");
        return;
    }

    print_line("[Auth] Starting AuthStateListener");

    // Create and register the listener
    auth_state_listener = new GodotAuthStateListener(this);
    auth->AddAuthStateListener(auth_state_listener);
    auth_state_listener_active.store(true);

    print_line("[Auth] AuthStateListener registered successfully");
}

void FirebaseAuth::stop_auth_state_listener() {
    if (!auth_state_listener_active.load()) {
        print_line("[Auth] AuthStateListener not active, ignoring stop request.");
        return;
    }

    print_line("[Auth] Stopping AuthStateListener");

    if (auth_state_listener && auth) {
        auth->RemoveAuthStateListener(auth_state_listener);
        delete auth_state_listener;
        auth_state_listener = nullptr;
    }
    auth_state_listener_active.store(false);

    print_line("[Auth] AuthStateListener stopped successfully");
}

bool FirebaseAuth::is_auth_state_listener_active() {
    return auth_state_listener_active.load();
}


// --- Binding Methods ---

void FirebaseAuth::_bind_methods() {
    // Sync state getters
    ClassDB::bind_method(D_METHOD("is_logged_in"), &FirebaseAuth::is_logged_in);
    ClassDB::bind_method(D_METHOD("user_name"), &FirebaseAuth::user_name);
    ClassDB::bind_method(D_METHOD("email"), &FirebaseAuth::email);
    ClassDB::bind_method(D_METHOD("uid"), &FirebaseAuth::uid);
    ClassDB::bind_method(D_METHOD("photo_url"), &FirebaseAuth::photo_url);
    ClassDB::bind_method(D_METHOD("sign_out"), &FirebaseAuth::sign_out);
    ClassDB::bind_method(D_METHOD("providers"), &FirebaseAuth::providers);

    // Async methods with request IDs (the only sign-in/link surface since task-1002)
    ClassDB::bind_method(D_METHOD("sign_in_anonymously_async", "request_id"), &FirebaseAuth::sign_in_anonymously_async);
    ClassDB::bind_method(D_METHOD("sign_in_facebook_async", "request_id", "token"), &FirebaseAuth::sign_in_facebook_async);
    ClassDB::bind_method(D_METHOD("sign_in_apple_async", "request_id", "token", "nonce"), &FirebaseAuth::sign_in_apple_async);
    ClassDB::bind_method(D_METHOD("sign_in_with_custom_token_async", "request_id", "token"), &FirebaseAuth::sign_in_with_custom_token_async);
    ClassDB::bind_method(D_METHOD("sign_in_with_email_async", "request_id", "email", "password"), &FirebaseAuth::sign_in_with_email_async);
    ClassDB::bind_method(D_METHOD("get_id_token_async", "request_id", "force_refresh"), &FirebaseAuth::get_id_token_async);
    ClassDB::bind_method(D_METHOD("link_facebook_async", "request_id", "token"), &FirebaseAuth::link_facebook_async);
    ClassDB::bind_method(D_METHOD("link_apple_async", "request_id", "token", "nonce"), &FirebaseAuth::link_apple_async);
    ClassDB::bind_method(D_METHOD("unlink_provider_async", "request_id", "provider_name"), &FirebaseAuth::unlink_provider_async);

    // AuthStateListener methods (Task-420)
    ClassDB::bind_method(D_METHOD("start_auth_state_listener"), &FirebaseAuth::start_auth_state_listener);
    ClassDB::bind_method(D_METHOD("stop_auth_state_listener"), &FirebaseAuth::stop_auth_state_listener);
    ClassDB::bind_method(D_METHOD("is_auth_state_listener_active"), &FirebaseAuth::is_auth_state_listener_active);

    // Signals with request IDs (consistent format with database.h)
    ADD_SIGNAL(MethodInfo("sign_in_completed",
        PropertyInfo(Variant::INT, "request_id"),
        PropertyInfo(Variant::BOOL, "success"),
        PropertyInfo(Variant::STRING, "uid"),
        PropertyInfo(Variant::STRING, "error_message")));

    ADD_SIGNAL(MethodInfo("custom_token_sign_in_completed",
        PropertyInfo(Variant::INT, "request_id"),
        PropertyInfo(Variant::BOOL, "success"),
        PropertyInfo(Variant::STRING, "uid"),
        PropertyInfo(Variant::STRING, "error_message")));

    ADD_SIGNAL(MethodInfo("id_token_result",
        PropertyInfo(Variant::INT, "request_id"),
        PropertyInfo(Variant::BOOL, "success"),
        PropertyInfo(Variant::STRING, "token"),
        PropertyInfo(Variant::STRING, "error_message")));

    ADD_SIGNAL(MethodInfo("link_completed",
        PropertyInfo(Variant::INT, "request_id"),
        PropertyInfo(Variant::BOOL, "success"),
        PropertyInfo(Variant::STRING, "error_message")));

    ADD_SIGNAL(MethodInfo("unlink_completed",
        PropertyInfo(Variant::INT, "request_id"),
        PropertyInfo(Variant::BOOL, "success"),
        PropertyInfo(Variant::STRING, "error_message")));

    // AuthStateListener signal (Task-420)
    ADD_SIGNAL(MethodInfo("auth_state_changed",
        PropertyInfo(Variant::BOOL, "is_signed_in"),
        PropertyInfo(Variant::STRING, "uid")));
}
