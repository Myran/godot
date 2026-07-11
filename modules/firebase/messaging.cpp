#include "messaging.h"
#include "core/object/callable_mp.h"
#include "core/object/class_db.h"

bool FirebaseMessaging::inited = false;
FirebaseMessagingListener *FirebaseMessaging::listener = NULL;
std::string FirebaseMessaging::_token;
std::mutex FirebaseMessaging::_token_mutex;
std::atomic<bool> FirebaseMessaging::is_shutting_down{false};

void FirebaseMessagingListener::OnMessage(const firebase::messaging::Message& message)
{
    // WORKER THREAD — Only C++ types, no Godot objects.
    // task-1084: a late FCM push can fire during/after teardown; bail before touching
    // singleton (which may be freed) or its call_deferred emit (torn-down MessageQueue).
    if (FirebaseMessaging::is_app_shutting_down()) {
        return;
    }
    // task-1077: setMessage copies only raw C++ here and defers the Godot Dictionary build to
    // the main thread. The previous worker-side String(message.from/message_id) + setMessage()
    // Dictionary build raced CowData _p — the b6e10f69c0 null-_p/SIGBUS class.
    this->singleton->setMessage(message);
}

void FirebaseMessagingListener::OnTokenReceived(const char* token)
{
    // WORKER THREAD — Only C++ types, no Godot objects.
    // task-1084: bail before touching singleton during teardown (see OnMessage).
    if (FirebaseMessaging::is_app_shutting_down()) {
        return;
    }
    // task-1077: pass the raw C string straight through; setToken stores it as std::string
    // under a mutex. No Godot String is built on the worker.
    this->singleton->setToken(token);
}

FirebaseMessaging::FirebaseMessaging() {
    if(!inited) {
        firebase::App* app = Firebase::AppId();
        if(app != NULL) {
            listener = new FirebaseMessagingListener();
            listener->singleton = this;
            firebase::messaging::Initialize(*app, listener);
            inited = true;
        }
    }
}

FirebaseMessaging::~FirebaseMessaging() {
    // Only clean up if this is the last instance and resources were initialized
    if (get_reference_count() == 1 && inited && listener != NULL) {
        delete listener;
        listener = NULL;
        inited = false;
        // We don't terminate Firebase Messaging here as it might be used by other parts of the app
    }
}

Variant FirebaseMessaging::token()
{
    // MAIN THREAD (GDScript getter) — build the Godot String here, under the lock.
    std::lock_guard<std::mutex> lock(_token_mutex);
    if (!_token.empty()) {
        return Variant(String(_token.c_str()));
    }
    return Variant();
}

void FirebaseMessaging::setToken(const char* token)
{
    // Called on the FCM worker thread (OnTokenReceived). Store raw std::string only.
    if (is_shutting_down.load()) {
        return;
    }
    {
        std::lock_guard<std::mutex> lock(_token_mutex);
        _token = token ? token : "";
    }
    call_deferred("emit_signal", "token");
}

void FirebaseMessaging::setMessage(const firebase::messaging::Message& message)
{
    // WORKER THREAD — copy ONLY raw C++ types. message.from / message.message_id are
    // std::string and message.data is std::map<std::string,std::string> in the SDK, so this
    // copy fully owns its data independent of the SDK callback frame. Build NO Godot object here.
    if (is_shutting_down.load()) {
        return;
    }
    PendingMessage pending;
    pending.from = message.from;
    pending.message_id = message.message_id;
    pending.data = message.data;
    int id;
    {
        std::lock_guard<std::mutex> lock(_msg_mutex);
        id = ++_msg_counter;
        _pending_messages[id] = std::move(pending);
    }
    // Hand off an int id; the Godot Dictionary is built on the main thread (mirrors
    // database.cpp _queue_child_event -> _handle_child_event_on_main_thread).
    callable_mp(this, &FirebaseMessaging::_handle_message_on_main_thread).call_deferred(id);
}

void FirebaseMessaging::_handle_message_on_main_thread(int id)
{
    // NOW ON MAIN THREAD — safe to build Godot Dictionary / String.
    if (is_app_shutting_down()) {
        std::lock_guard<std::mutex> lock(_msg_mutex);
        _pending_messages.erase(id);
        return;
    }
    PendingMessage pending;
    {
        std::lock_guard<std::mutex> lock(_msg_mutex);
        auto it = _pending_messages.find(id);
        if (it == _pending_messages.end()) {
            return;
        }
        pending = std::move(it->second);
        _pending_messages.erase(it);
    }
    Dictionary msg_data;
    msg_data["from"] = String(pending.from.c_str());
    msg_data["message_id"] = String(pending.message_id.c_str());
    Dictionary data_dict;
    for (const auto& entry : pending.data) {
        data_dict[String(entry.first.c_str())] = String(entry.second.c_str());
    }
    msg_data["data"] = data_dict;
    emit_signal("message", msg_data);
}

void FirebaseMessaging::begin_shutdown() {
    is_shutting_down.store(true);
    print_line("[Messaging] begin_shutdown() called - late FCM callbacks will be ignored");
}

bool FirebaseMessaging::is_app_shutting_down() {
    return is_shutting_down.load();
}

void FirebaseMessaging::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_token"), &FirebaseMessaging::token);
    ADD_SIGNAL(MethodInfo("token"));
    ADD_SIGNAL(MethodInfo("message", PropertyInfo(Variant::DICTIONARY, "message_data")));
}
