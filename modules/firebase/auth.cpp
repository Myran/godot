// godot/modules/firebase/auth.cpp
#include "auth.h"
#include "firebase/auth.h"
#include "firebase/auth/user.h"
#include "core/object/object.h"
#include "core/object/message_queue.h" // For thread-safe callback marshalling
#include "core/string/print_string.h"
#include "core/variant/callable.h"


#if !defined(TRUE)
    #define TRUE	1
#endif

#if !defined(FALSE)
    #define FALSE	0
#endif


// --- Thread-Safe Singleton Member Initialization (matches database.cpp pattern) ---
std::mutex FirebaseAuth::initialization_mutex;
std::atomic<bool> FirebaseAuth::inited(false);
std::atomic<bool> FirebaseAuth::is_shutting_down(false);
FirebaseAuth* FirebaseAuth::singleton_instance = nullptr;
std::mutex FirebaseAuth::instance_mutex;

// Static Firebase resources
firebase::auth::Auth* FirebaseAuth::auth = nullptr;
firebase::auth::User::UserProfile FirebaseAuth::profile;


// --- Thread-Safe Singleton Access (matches database.cpp pattern) ---
FirebaseAuth& FirebaseAuth::get_instance() {
    std::lock_guard<std::mutex> lock(instance_mutex);
    if (!singleton_instance) {
        singleton_instance = memnew(FirebaseAuth);
    }
    return *singleton_instance;
}

void FirebaseAuth::cleanup() {
    std::lock_guard<std::mutex> lock(instance_mutex);
    if (singleton_instance) {
        memdelete(singleton_instance);
        singleton_instance = nullptr;
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
    print_line(String("[Auth] Sign in completed on main thread. ReqID: ") + itos(req_id) + " Success: " + (success ? "true" : "false"));
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


// --- Legacy Callbacks (preserved for backward compatibility) ---

void FirebaseAuth::OnCreateUserCallback(const firebase::Future<firebase::auth::AuthResult>& result, void* user_data) {
    if (is_shutting_down.load()) {
        print_line("[Auth] Ignoring OnCreateUserCallback during shutdown");
        return;
    }
    if (result.error() == firebase::auth::kAuthErrorNone) {
        const firebase::auth::AuthResult* auth_result = result.result();
        if (auth_result) {
          firebase::auth::User* user = const_cast<firebase::auth::User*>(&(auth_result->user));
            if (user != nullptr) {
                print_line(String("[Auth] Create/ Sign in user succeeded with name ") + user->display_name().c_str());
                user->UpdateUserProfile(profile);
            } else {
                print_line(String("[Auth] User is null after successful creation"));
            }
        } else {
            print_line(String("[Auth] AuthResult is null after successful creation"));
        }
    } else {
        print_line(String("[Auth] Created user failed with error ") + result.error_message());
    }
    emit_signal("logged_in", result.error());
}

void FirebaseAuth::OnLinkUserCallback(const firebase::Future<firebase::auth::AuthResult>& result, void* user_data) {
    if (is_shutting_down.load()) {
        print_line("[Auth] Ignoring OnLinkUserCallback during shutdown");
        return;
    }
    if (result.error() == firebase::auth::kAuthErrorNone) {
        firebase::auth::User user = result.result()->user;
        print_line(String("[Auth] Link user succeeded"));
        user.UpdateUserProfile(profile);
        emit_signal("account_linked",result.error());
    } else {

        print_line(String("[Auth] Link user failed with error message: ") + result.error_message());
    }
    emit_signal("account_linked",result.error());
}

void FirebaseAuth::OnUnLinkUserCallback(const firebase::Future<firebase::auth::AuthResult>& result, void* user_data) {
    if (is_shutting_down.load()) {
        print_line("[Auth] Ignoring OnUnLinkUserCallback during shutdown");
        return;
    }
    if (result.error() == firebase::auth::kAuthErrorNone) {
        firebase::auth::User user = result.result()->user;
        print_line(String("[Auth] UnLink user succeeded"));
        user.UpdateUserProfile(profile);
    } else {
        print_line(String("[Auth] UnLink user failed with error ") + result.error_message());
    }
    emit_signal("account_unlinked",result.error_message());
}


// --- Existing Methods (preserved, with CharString fixes) ---

void FirebaseAuth::sign_in_anonymously()
{
    print_line("[Auth] Start anonymous sign in");
    firebase::Future<firebase::auth::AuthResult> result = auth->SignInAnonymously();
    result.OnCompletion([](const firebase::Future<firebase::auth::AuthResult>& result, void* user_data) {
                            ((FirebaseAuth*)user_data)->OnCreateUserCallback(result, user_data);
                        }, this);
}


void FirebaseAuth::sign_in_apple(String token, String nonce)
{
    print_line("[Auth] Start sign in to firebase with apple account");

    // CRITICAL: Store CharString to extend lifetime and prevent dangling pointer (Task-399)
    CharString token_cs = token.utf8();
    CharString nonce_cs = nonce.utf8();

    firebase::auth::Credential credential = firebase::auth::OAuthProvider::GetCredential(
        /*provider_id=*/"apple.com", token_cs.get_data(), nonce_cs.get_data(),
        /*access_token=*/nullptr);
    sign_in_provider(credential);

}

void FirebaseAuth::link_to_apple(String token, String nonce)
{
    print_line("[Auth] Start link firebase in to Apple");

    // CRITICAL: Store CharString to extend lifetime and prevent dangling pointer (Task-399)
    CharString token_cs = token.utf8();
    CharString nonce_cs = nonce.utf8();

    firebase::auth::Credential credential = firebase::auth::OAuthProvider::GetCredential(
        /*provider_id=*/"apple.com", token_cs.get_data(), nonce_cs.get_data(),
        /*access_token=*/nullptr);
    link_to_provider(credential);
}


void FirebaseAuth::sign_in_facebook(String token)
{
    print_line("[Auth] Start sign in to Firebase with Facebook");

    // CRITICAL: Store CharString to extend lifetime and prevent dangling pointer (Task-399)
    CharString token_cs = token.utf8();

    firebase::auth::Credential credential = firebase::auth::FacebookAuthProvider::GetCredential(token_cs.get_data());
    sign_in_provider(credential);
}

void FirebaseAuth::link_to_facebook(String token)
{
    print_line("[Auth] Start link firebase in to Facebook");

    // CRITICAL: Store CharString to extend lifetime and prevent dangling pointer (Task-399)
    CharString token_cs = token.utf8();

    firebase::auth::Credential credential = firebase::auth::FacebookAuthProvider::GetCredential(token_cs.get_data());
    link_to_provider(credential);
}

void FirebaseAuth::sign_in_provider(firebase::auth::Credential credential)
{
    firebase::Future<firebase::auth::AuthResult> result = auth->SignInAndRetrieveDataWithCredential(credential);
    result.OnCompletion([](const firebase::Future<firebase::auth::AuthResult>& result, void* user_data) {
                                ((FirebaseAuth*)user_data)->OnCreateUserCallback(result, user_data);
                            }, this);
}

void FirebaseAuth::link_to_provider(firebase::auth::Credential credential)
{
    firebase::auth::User current_user = auth->current_user();
    if(current_user.is_valid() == TRUE) {
        firebase::Future<firebase::auth::AuthResult> result = current_user.LinkWithCredential(credential);
        result.OnCompletion([](const firebase::Future<firebase::auth::AuthResult>& result, void* user_data) {
                                ((FirebaseAuth*)user_data)->OnLinkUserCallback(result, user_data);
                            }, this);
    }else{
        print_line("Cannot link to provider: no user logged in");
    }
}


void FirebaseAuth::unlink_provider(String provider_name)
{
    firebase::auth::User current_user = auth->current_user();
    print_line(String("[Auth] unlink attempt with provider: ") + provider_name);

    // CRITICAL: Store CharString to extend lifetime and prevent dangling pointer (Task-399)
    CharString provider_cs = provider_name.utf8();

    firebase::Future<firebase::auth::AuthResult> result = current_user.Unlink(provider_cs.get_data());
    result.OnCompletion([](const firebase::Future<firebase::auth::AuthResult>& result, void* user_data) {
                            ((FirebaseAuth*)user_data)->OnUnLinkUserCallback(result, user_data);
                            }, this);
}


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


// --- Binding Methods ---

void FirebaseAuth::_bind_methods() {
    // Existing methods (preserved for backward compatibility)
    ClassDB::bind_method(D_METHOD("sign_in_anonymously"), &FirebaseAuth::sign_in_anonymously);
    ClassDB::bind_method(D_METHOD("sign_in_facebook", "token"), &FirebaseAuth::sign_in_facebook);
    ClassDB::bind_method(D_METHOD("sign_in_apple", "token", "nonce"), &FirebaseAuth::sign_in_apple);
    ClassDB::bind_method(D_METHOD("is_logged_in"), &FirebaseAuth::is_logged_in);
    ClassDB::bind_method(D_METHOD("user_name"), &FirebaseAuth::user_name);
    ClassDB::bind_method(D_METHOD("email"), &FirebaseAuth::email);
    ClassDB::bind_method(D_METHOD("uid"), &FirebaseAuth::uid);
    ClassDB::bind_method(D_METHOD("photo_url"), &FirebaseAuth::photo_url);
    ClassDB::bind_method(D_METHOD("sign_out"), &FirebaseAuth::sign_out);
    ClassDB::bind_method(D_METHOD("providers"), &FirebaseAuth::providers);
    ClassDB::bind_method(D_METHOD("unlink_provider", "provider_name"), &FirebaseAuth::unlink_provider);
    ClassDB::bind_method(D_METHOD("link_to_facebook", "token"), &FirebaseAuth::link_to_facebook);
    ClassDB::bind_method(D_METHOD("link_to_apple", "token", "nonce"), &FirebaseAuth::link_to_apple);

    // New async methods with request IDs
    ClassDB::bind_method(D_METHOD("sign_in_anonymously_async", "request_id"), &FirebaseAuth::sign_in_anonymously_async);
    ClassDB::bind_method(D_METHOD("sign_in_facebook_async", "request_id", "token"), &FirebaseAuth::sign_in_facebook_async);
    ClassDB::bind_method(D_METHOD("sign_in_apple_async", "request_id", "token", "nonce"), &FirebaseAuth::sign_in_apple_async);
    ClassDB::bind_method(D_METHOD("sign_in_with_custom_token_async", "request_id", "token"), &FirebaseAuth::sign_in_with_custom_token_async);
    ClassDB::bind_method(D_METHOD("get_id_token_async", "request_id", "force_refresh"), &FirebaseAuth::get_id_token_async);
    ClassDB::bind_method(D_METHOD("link_facebook_async", "request_id", "token"), &FirebaseAuth::link_facebook_async);
    ClassDB::bind_method(D_METHOD("link_apple_async", "request_id", "token", "nonce"), &FirebaseAuth::link_apple_async);
    ClassDB::bind_method(D_METHOD("unlink_provider_async", "request_id", "provider_name"), &FirebaseAuth::unlink_provider_async);

    // Legacy signals (preserved for backward compatibility)
    ADD_SIGNAL(MethodInfo("logged_in", PropertyInfo(Variant::INT, "error")));
    ADD_SIGNAL(MethodInfo("account_linked", PropertyInfo(Variant::INT, "error")));
    ADD_SIGNAL(MethodInfo("account_unlinked", PropertyInfo(Variant::STRING, "error_message")));

    // New signals with request IDs (consistent format with database.h)
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
}
