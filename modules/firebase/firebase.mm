#include "firebase.h"

#if defined(__ANDROID__)
#include "platform/android/java_godot_wrapper.h"
#include "platform/android/os_android.h"
#include "platform/android/thread_jandroid.h"
//extern jobject _godot_instance;
#endif
#if defined(__APPLE__)
#import "app_delegate.h"
#include "core/object/object.h"
AppActivity _instance;
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
    //JNIEnv *env = ThreadAndroid::get_env();
    // Vet inte konsekvenserna av detta riktigt?
    JNIEnv *env = get_jni_env();
    //app_ptr = firebase::App::Create(firebase::AppOptions(), env, _godot_instance);
    OS_Android *os_android = (OS_Android *)OS::get_singleton();
    jobject activity = os_android->get_godot_java()->get_activity();
    if (!env) {
        print_line(String("[Firebase] error: NO ENV"));
    }
    if (!activity){
        print_line(String("[Firebase] error: NO ACTIVITY"));
    }
     
    print_line(String("[Firebase] Creating app"));
    app_ptr = firebase::App::Create(firebase::AppOptions(), env, activity);
    print_line(String("[Firebase] Success creating app"));
#else
    app_ptr = firebase::App::Create();
    _instance = (ViewController *)((AppDelegate *)[[UIApplication sharedApplication] delegate]).window.rootViewController.view;
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
void Firebase::_bind_methods() {
    //ClassDB::bind_method(D_METHOD("AppId"), &Firebase::AppId);
}

