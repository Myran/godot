// firebase_platform.mm - Platform-specific Firebase initialization for Android/iOS/macOS
// Shared logic is in firebase_common.cpp

#include "firebase.h"

#if defined(__ANDROID__)
#include "platform/android/java_godot_wrapper.h"
#include "platform/android/os_android.h"
#include "platform/android/thread_jandroid.h"
#endif

#if defined(__APPLE__)
#include <TargetConditionals.h>
#include <unistd.h>  // For _exit()
#include <CoreFoundation/CoreFoundation.h>  // For CFRunLoopRunInMode (task-414)
#if TARGET_OS_IPHONE
// iOS-specific headers
#import "drivers/apple_embedded/godot_app_delegate.h"
#import "drivers/apple_embedded/app_delegate_service.h"
#import "drivers/apple_embedded/godot_view_controller.h"
#include "core/object/object.h"
AppActivity _instance;
#elif TARGET_OS_OSX
// macOS: Foundation for NSBundle to locate config file
#import <Foundation/Foundation.h>
#include "core/object/object.h"
#endif
#endif

void Firebase::createApplication() {
#if defined(__ANDROID__)
    JNIEnv *env = get_jni_env();
    OS_Android *os_android = (OS_Android *)OS::get_singleton();
    jobject activity = os_android->get_godot_java()->get_activity();
    if (!env) {
        print_line(String("[Firebase] error: NO ENV"));
    }
    if (!activity){
        print_line(String("[Firebase] error: NO ACTIVITY"));
    }

    print_line(String("[Firebase] Creating app (Android)"));
    app_ptr = firebase::App::Create(firebase::AppOptions(), env, activity);
    print_line(String("[Firebase] Success creating app"));
#elif TARGET_OS_IPHONE
    // iOS initialization with UI context

    // Check if app already exists before creating (same pattern as macOS)
    app_ptr = firebase::App::GetInstance();
    if (app_ptr != NULL) {
        print_line(String("[Firebase] Using existing Firebase app instance (iOS)"));
        _instance = (__bridge void *)[GDTAppDelegateService viewController].view;
        return;
    }

    print_line(String("[Firebase] Creating app (iOS)"));
    app_ptr = firebase::App::Create();
    _instance = (__bridge void *)[GDTAppDelegateService viewController].view;
    print_line(String("[Firebase] Success creating app"));
#elif TARGET_OS_OSX
    // macOS desktop initialization - try to load config from app bundle Resources

    // CRITICAL FIX (task-486): Check if app already exists before creating
    // This prevents "App __FIRAPP_DEFAULT already created" warning when
    // Firebase is re-initialized (e.g., during test cycles or app restarts)
    app_ptr = firebase::App::GetInstance();
    if (app_ptr != NULL) {
        print_line(String("[Firebase] Using existing Firebase app instance (macOS)"));
        return;
    }

    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* resourcePath = [mainBundle resourcePath];
    NSString* configPath = [resourcePath stringByAppendingString:@"/google-services-desktop.json"];

    print_line(String("[Firebase] Looking for config at: ") + String([configPath UTF8String]));

    // Check if config file exists in bundle
    if ([[NSFileManager defaultManager] fileExistsAtPath:configPath]) {
        print_line(String("[Firebase] Config file found, loading..."));

        // For desktop apps, we need to set the working directory to the bundle Resources
        NSString* bundlePath = [resourcePath stringByAppendingString:@"/"];
        [[NSFileManager defaultManager] changeCurrentDirectoryPath:bundlePath];

        print_line(String("[Firebase] Creating app (macOS)"));
        app_ptr = firebase::App::Create();
        print_line(String("[Firebase] Success creating app"));
    } else {
        print_line(String("[Firebase] Config file not found, creating app without config"));
        print_line(String("[Firebase] Creating app (macOS)"));
        app_ptr = firebase::App::Create();
        print_line(String("[Firebase] App created but will not be properly configured"));
    }
#endif
}

void Firebase::quit_app() {
    // Perform Firebase cleanup before quitting
    cleanup_firebase();

#if TARGET_OS_IPHONE
    // iOS quit for testing/CI only (Task-290)
    // Use _exit() instead of exit() to bypass cleanup handlers and terminate immediately
    //
    // Task-520: Flush all file buffers before _exit() to ensure logs are written to disk.
    // _exit() bypasses ALL cleanup including OS file buffer flushing, causing log truncation.
    // fflush(NULL) flushes all open output streams (stdout, stderr, and file handles).
    // sync() forces kernel to flush filesystem buffers to physical storage.
    fflush(NULL);
    sync();
    _exit(0);
#elif TARGET_OS_OSX
    // macOS: Use _exit() for immediate termination (same as iOS for testing/CI)
    // Task-520: Same flush pattern as iOS
    fflush(NULL);
    sync();
    _exit(0);
#else
    // Android/other platforms: no-op (they use Engine.get_main_loop().quit())
#endif
}

void Firebase::process_notifications() {
#if TARGET_OS_IPHONE || TARGET_OS_OSX
    // CRITICAL (task-414): Firebase iOS/macOS SDK uses NSRunLoop to dispatch async callbacks
    // Without pumping the runloop, Future<T>::OnCompletion callbacks never execute
    // This is required for Auth, Database, Firestore, Messaging, etc. callbacks to work
    //
    // PERFORMANCE (task-414): Use CFRunLoopRunInMode with 0 timeout for minimal overhead
    // - 0 seconds = don't wait, just process any pending events
    // - returnAfterSourceHandled = true for quick return after processing
    // - Estimated overhead: ~0.01ms per call (safe for per-frame calling)
    //
    // Reference: firebase-cpp-sdk-repo/messaging/tests/ios/messaging_test_util.mm:59
    @autoreleasepool {
        // Process any pending Firebase callbacks without blocking
        // Returns immediately if no callbacks pending, or after processing one
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
    }
#endif
    // Android: JNI callbacks work differently, no action needed
}
