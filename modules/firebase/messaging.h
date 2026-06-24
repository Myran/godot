#ifndef FirebaseMessaging_h
#define FirebaseMessaging_h

#include <atomic>
#include <map>
#include <mutex>
#include <string>

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
    // task-1077: _token is written on the FCM worker thread (OnTokenReceived -> setToken) and
    // read on the main thread (token() / GDScript). Stored as raw std::string under a mutex —
    // NO Godot String (CowData) is built on the worker; the Godot String is built in token()
    // on the main thread. (The previous `static String _token` was a worker/main data race.)
    static std::string _token;
    static std::mutex _token_mutex;
    // task-1077: FCM messages arrive on an SDK worker thread. Copy ONLY raw C++
    // (std::string / std::map) there, hand an int id to the main thread, and build the Godot
    // Dictionary in _handle_message_on_main_thread — mirrors database.cpp's listener-event
    // pattern (the b6e10f69c0 null-_p/SIGBUS fix class).
    struct PendingMessage {
        std::string from;
        std::string message_id;
        std::map<std::string, std::string> data;
    };
    std::mutex _msg_mutex;
    std::map<int, PendingMessage> _pending_messages;
    int _msg_counter = 0;
    // task-1084: set true at app teardown so late FCM Listener callbacks skip the
    // call_deferred("emit_signal", ...) that would push onto a torn-down MessageQueue
    // / deref a freed singleton (FCM has no GDScript wrapper holding the instance alive).
    static std::atomic<bool> is_shutting_down;

    public:

    FirebaseMessaging();
    ~FirebaseMessaging();
    Variant token();
    // task-1077: takes the raw C string from the listener (no Godot String built on the worker).
    void setToken(const char* token);
    void setMessage(const firebase::messaging::Message& message);
    // task-1077: main-thread handler — builds the Godot Dictionary + emits "message".
    void _handle_message_on_main_thread(int id);
    // task-1084: teardown guard (mirrors FirebaseRemoteConfig/Database/Auth/Firestore).
    static void begin_shutdown();
    static bool is_app_shutting_down();
};

#endif // FirebaseMessaging_h
