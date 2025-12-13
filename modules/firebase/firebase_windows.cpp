// firebase_windows.cpp - Platform-specific Firebase initialization for Windows
// Shared logic is in firebase_common.cpp

#ifdef _WIN32

#include "firebase.h"
#include <cstdlib>  // For _exit()

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

void Firebase::quit_app() {
    // Perform Firebase cleanup before quitting
    cleanup_firebase();

    // Windows: Use _exit() for immediate termination for testing/CI
    _exit(0);
}

#endif // _WIN32
