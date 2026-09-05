#ifndef Firebase_h
#define Firebase_h

#include "core/object/ref_counted.h"
#include "firebase/app.h"

#if defined(__ANDROID__)
/// An Android Activity from Java.
typedef jobject AppActivity;
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
/// A pointer to an iOS UIView (Objective-C id type, only for .mm files).
typedef void *AppActivity;
#elif TARGET_OS_OSX
/// macOS doesn't need UI context for Firebase desktop initialization.
typedef void *AppActivity;
#else
typedef void *AppActivity;
#endif
#else
/// A void pointer for stub classes.
typedef void *AppActivity;
#endif // __ANDROID__, __APPLE__

class Firebase : public RefCounted {
	GDCLASS(Firebase, RefCounted);

protected:
	static firebase::App *app_ptr;
	static void _bind_methods();
	static void createApplication();

public:
	Firebase();
	// task-1502: route the Firebase SDK's own diagnostics into Godot's log sink.
	// Call once, before any SDK use. Idempotent.
	static void install_sdk_log_bridge();

	// Windows debug builds only: routes google_analytics.dll's own log messages into
	// the SDK sink and turns on its debug mode. The DLL is closed source and discards
	// events before its remote-config fetch lands, and this is the only channel that
	// reports what it does with them (task-1767).
	static void install_analytics_dll_log_bridge();
	static firebase::App *AppId();
	static AppActivity GetAppActivity();
	void cleanup_firebase();
	void quit_app();

	// iOS: Process Firebase notifications (task-414)
	// Firebase iOS SDK requires CheckForNotifications() to process async callbacks
	void process_notifications();
};

#endif // Firebase_h
