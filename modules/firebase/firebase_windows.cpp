// Windows-specific implementation of Firebase class
// This is the Windows equivalent of firebase.mm (which handles Apple platforms)

#ifdef _WIN32

#include "firebase.h"
#include "database.h"  // For FirebaseDatabase::begin_shutdown()
#include <cstdlib>     // For _exit()

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

void Firebase::createApplication() {
    // Windows desktop initialization
    // Firebase C++ SDK automatically looks for google-services-desktop.json in current directory
    print_line(String("[Firebase] Creating app (Windows)"));
    app_ptr = firebase::App::Create();
    if (app_ptr != nullptr) {
        print_line(String("[Firebase] Success creating app"));
    } else {
        print_line(String("[Firebase] Failed to create app - check google-services-desktop.json"));
    }
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

void Firebase::quit_app() {
    // Perform Firebase cleanup before quitting
    cleanup_firebase();

    // Windows: Use _exit() for immediate termination for testing/CI
    _exit(0);
}

void Firebase::_bind_methods() {
    ClassDB::bind_method(D_METHOD("quit_app"), &Firebase::quit_app);
    ClassDB::bind_method(D_METHOD("cleanup_firebase"), &Firebase::cleanup_firebase);
}

#endif // _WIN32
