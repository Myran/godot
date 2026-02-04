// firebase_windows.cpp - Platform-specific Firebase initialization for Windows
// Shared logic is in firebase_common.cpp

#ifdef _WIN32

#include "firebase.h"
#include <cstdlib>  // For _exit()
#include <cstdio>   // For fflush(), _flushall()

void Firebase::createApplication() {
    // Windows desktop initialization

    // Check if app already exists before creating (prevents double init warning)
    app_ptr = firebase::App::GetInstance();
    if (app_ptr != nullptr) {
        print_line(String("[Firebase] Using existing Firebase app instance (Windows)"));
        return;
    }

    // Firebase C++ SDK automatically looks for google-services-desktop.json in current directory
    print_line(String("[Firebase] Creating app (Windows)"));
    // Match Firebase example: no app name argument for desktop (Task-434)
    app_ptr = firebase::App::Create();
    if (app_ptr != nullptr) {
        print_line(String("[Firebase] Success creating app"));
    } else {
        print_line(String("[Firebase] Failed to create app - check google-services-desktop.json"));
    }
}

void Firebase::quit_app() {
    // Perform Firebase cleanup before quitting
    cleanup_firebase();

    // Windows: Use _exit() for immediate termination for testing/CI
    // Task-520: Flush all file buffers before _exit() to ensure logs are written to disk.
    // _exit() bypasses ALL cleanup including OS file buffer flushing, causing log truncation.
    fflush(NULL);
    _flushall();  // Windows-specific: flush all streams including those without buffers
    _exit(0);
}

void Firebase::process_notifications() {
    // Windows: No-op - Windows doesn't use NSRunLoop like Apple platforms
    // Firebase C++ SDK on Windows uses its own internal threading for callbacks
}

#endif // _WIN32
