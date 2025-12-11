#include "firebase.h"
#include "database.h"  // For FirebaseDatabase::begin_shutdown()

#if defined(__ANDROID__)
#include "platform/android/java_godot_wrapper.h"
#include "platform/android/os_android.h"
#include "platform/android/thread_jandroid.h"
#endif

#if defined(__APPLE__)
#include <TargetConditionals.h>
#include <unistd.h>  // For _exit()
#if TARGET_OS_IPHONE
// iOS-specific headers
#import "drivers/apple_embedded/godot_app_delegate.h"
#import "drivers/apple_embedded/app_delegate_service.h"
#import "drivers/apple_embedded/view_controller.h"
#include "core/object/object.h"
AppActivity _instance;
#elif TARGET_OS_OSX
// macOS: Foundation for NSBundle to locate config file
#import <Foundation/Foundation.h>
#include "core/object/object.h"
#endif
#endif

firebase::App* Firebase::app_ptr = NULL;

Firebase::Firebase() {
    if(app_ptr == NULL) {
        createApplication();
    }
}

firebase::App* Firebase::AppId() {
    if(app_ptr == NULL) {
        createApplication();
    }
    return app_ptr;
}

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
    print_line(String("[Firebase] Creating app (iOS)"));
    app_ptr = firebase::App::Create();
    _instance = (__bridge void *)[GDTAppDelegateService viewController].view;
    print_line(String("[Firebase] Success creating app"));
#elif TARGET_OS_OSX
    // macOS desktop initialization - try to load config from app bundle Resources
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
/*
AppActivity Firebase::GetAppActivity() {
#if defined(__ANDROID__)
    return _godot_instance;
#endif
#if defined(__APPLE__)
    return _instance;
#endif
}
*/
void Firebase::cleanup_firebase() {
    print_line(String("[Firebase] Starting cleanup sequence..."));

    if (app_ptr != NULL) {
        print_line(String("[Firebase] Cleaning up Firebase resources..."));

        // CRITICAL FIX: Call begin_shutdown() to prevent further Firebase callbacks
        // This prevents call_deferred emissions during app shutdown, avoiding use-after-free crashes
        FirebaseDatabase::begin_shutdown();

        // Note: firebase::App::Terminate() is not available in all SDK versions
        // The main cleanup needed is ensuring all listeners and pending operations are cleared

        print_line(String("[Firebase] Firebase cleanup completed"));
        app_ptr = NULL;
    } else {
        print_line(String("[Firebase] No active Firebase app to clean up"));
    }
}

void Firebase::quit_app() {
    // Perform Firebase cleanup before quitting
    cleanup_firebase();

#if TARGET_OS_IPHONE
    // iOS quit for testing/CI only
    // Use _exit() instead of exit() to bypass cleanup handlers and terminate immediately
    // This is necessary because exit() allows cleanup code to run, which can delay termination
    _exit(0);
#elif TARGET_OS_OSX
    // macOS: Use _exit() for immediate termination (same as iOS for testing/CI)
    _exit(0);
#else
    // Android/other platforms: no-op (they use Engine.get_main_loop().quit())
#endif
}

void Firebase::_bind_methods() {
    //ClassDB::bind_method(D_METHOD("AppId"), &Firebase::AppId);
    ClassDB::bind_method(D_METHOD("quit_app"), &Firebase::quit_app);
    ClassDB::bind_method(D_METHOD("cleanup_firebase"), &Firebase::cleanup_firebase);
}

