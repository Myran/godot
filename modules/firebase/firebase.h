#ifndef Firebase_h
#define Firebase_h

#include "core/object/ref_counted.h"
#include "firebase/app.h"
#include "firebase/gma/types.h"
#if defined(__ANDROID__)
/// An Android Activity from Java.
typedef jobject AppActivity;
#elif defined(__APPLE__)
/// A pointer to an iOS UIView.
typedef id AppActivity;
#else
/// A void pointer for stub classes.
typedef void *AppActivity;
#endif // __ANDROID__, TARGET_OS_IPHONE

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
};

#endif // Firebase_h
