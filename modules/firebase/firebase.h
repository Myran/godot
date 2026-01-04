#ifndef Firebase_h
#define Firebase_h

#include "core/object/ref_counted.h"
#include "firebase/app.h"
#include "firebase/gma/types.h"

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
	static firebase::App *AppId();
	static AppActivity GetAppActivity();
	void cleanup_firebase();
	void quit_app();

	// iOS: Process Firebase notifications (task-414)
	// Firebase iOS SDK requires CheckForNotifications() to process async callbacks
	void process_notifications();
};

#endif // Firebase_h
