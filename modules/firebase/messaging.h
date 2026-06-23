#ifndef FirebaseMessaging_h
#define FirebaseMessaging_h

#include <atomic>

#include "core/object/ref_counted.h"
#include "firebase/messaging.h"
#include "firebase.h"

class FirebaseMessaging;

class FirebaseMessagingListener : public firebase::messaging::Listener {
    public:
    FirebaseMessaging *singleton;
    void OnMessage(const firebase::messaging::Message& message);
    void OnTokenReceived(const char* token);
};

class FirebaseMessaging : public RefCounted {
    GDCLASS(FirebaseMessaging, RefCounted);
    
    protected:
    static bool inited;
    static void _bind_methods();
    static FirebaseMessagingListener* listener;
    static String _token;
    // task-1084: set true at app teardown so late FCM Listener callbacks skip the
    // call_deferred("emit_signal", ...) that would push onto a torn-down MessageQueue
    // / deref a freed singleton (FCM has no GDScript wrapper holding the instance alive).
    static std::atomic<bool> is_shutting_down;

    public:

    FirebaseMessaging();
    ~FirebaseMessaging();
    Variant token();
    void setToken(String token);
    void setMessage(const firebase::messaging::Message& message);
    // task-1084: teardown guard (mirrors FirebaseRemoteConfig/Database/Auth/Firestore).
    static void begin_shutdown();
    static bool is_app_shutting_down();
};

#endif // FirebaseMessaging_h
