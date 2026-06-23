// firebase_common.cpp - Shared Firebase implementation across all platforms
// Platform-specific createApplication() is implemented in:
// - firebase_platform.mm (Android/iOS/macOS)
// - firebase_windows.cpp (Windows)

#include "firebase.h"
#include "database.h"        // For FirebaseDatabase::begin_shutdown()
#include "remote_config.h"   // For FirebaseRemoteConfig::begin_shutdown() (task-1081)
#include "auth.h"            // For FirebaseAuth::begin_shutdown() (task-1084)
#include "firestore.h"       // For FirebaseFirestore::begin_shutdown() (task-1084)
#include "analytics.h"       // For FirebaseAnalytics::begin_shutdown() (task-1084)

#if defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#include "firebase/app.h"
#endif
#endif

firebase::App* Firebase::app_ptr = NULL;

Firebase::Firebase() {
    if (app_ptr == NULL) {
        createApplication();
    }
}

firebase::App* Firebase::AppId() {
    if (app_ptr == NULL) {
        createApplication();
    }
    return app_ptr;
}

void Firebase::cleanup_firebase() {
    print_line(String("[Firebase] Starting cleanup sequence..."));

    if (app_ptr != NULL) {
        print_line(String("[Firebase] Cleaning up Firebase resources..."));

        // CRITICAL FIX: Call begin_shutdown() on Firebase services that might be active
        // to prevent further callbacks during app shutdown, avoiding use-after-free crashes
        // Only Database is guaranteed to be used (card retrieval), others are optional
        FirebaseDatabase::begin_shutdown();

        // task-1081: RemoteConfig must ALSO begin_shutdown. The boot balance overlay
        // (BalanceOverlay.fetch_and_apply) fires a fetch_and_activate at startup; if that
        // SDK future is still pending at quit, its worker-thread completion lambda would
        // push_callable(callable_mp(this,...)) onto a torn-down MessageQueue -> 0xC0000005
        // (Windows shutdown crash). begin_shutdown() only flips an atomic flag + prints
        // (no SDK calls, no static-init-order hazard), so it is safe even if RemoteConfig
        // was never initialized. The flag makes both the worker-lambda guard and the
        // main-thread handler guards (remote_config.cpp) skip late callbacks.
        FirebaseRemoteConfig::begin_shutdown();

        // task-1084: teardown parity. Auth, Firestore, and Analytics each register
        // firebase::Future OnCompletion worker-thread lambdas that push_callable onto the
        // MessageQueue; the is_shutting_down guards already exist atop those lambdas (auth.cpp,
        // firestore.cpp, analytics.cpp) but stayed DORMANT because begin_shutdown() was never
        // called for them — so a still-pending future firing during teardown could push onto a
        // torn-down MessageQueue / dereference a freed `this` (the same 0xC0000005 class as
        // task-1081). Each begin_shutdown() only flips an atomic flag + prints (no SDK calls,
        // no static-init-order hazard), so it is safe even if the service was never initialized.
        FirebaseAuth::begin_shutdown();
        FirebaseFirestore::begin_shutdown();
        FirebaseAnalytics::begin_shutdown();

        print_line(String("[Firebase] Firebase cleanup completed"));
        app_ptr = NULL;
    } else {
        print_line(String("[Firebase] No active Firebase app to clean up"));
    }
}

void Firebase::_bind_methods() {
    ClassDB::bind_method(D_METHOD("quit_app"), &Firebase::quit_app);
    ClassDB::bind_method(D_METHOD("cleanup_firebase"), &Firebase::cleanup_firebase);
    ClassDB::bind_method(D_METHOD("process_notifications"), &Firebase::process_notifications);
}

// Note: createApplication() and quit_app() are platform-specific
// and implemented in firebase_platform.mm or firebase_windows.cpp
