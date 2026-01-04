// firebase_common.cpp - Shared Firebase implementation across all platforms
// Platform-specific createApplication() is implemented in:
// - firebase_platform.mm (Android/iOS/macOS)
// - firebase_windows.cpp (Windows)

#include "firebase.h"
#include "database.h"  // For FirebaseDatabase::begin_shutdown()

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

        // CRITICAL FIX: Call begin_shutdown() to prevent further Firebase callbacks
        // This prevents call_deferred emissions during app shutdown, avoiding use-after-free crashes
        FirebaseDatabase::begin_shutdown();

        print_line(String("[Firebase] Firebase cleanup completed"));
        app_ptr = NULL;
    } else {
        print_line(String("[Firebase] No active Firebase app to clean up"));
    }
}

void Firebase::_bind_methods() {
    ClassDB::bind_method(D_METHOD("quit_app"), &Firebase::quit_app);
    ClassDB::bind_method(D_METHOD("cleanup_firebase"), &Firebase::cleanup_firebase);
}

// Note: createApplication() and quit_app() are platform-specific
// and implemented in firebase_platform.mm or firebase_windows.cpp
