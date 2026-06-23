#include "messaging.h"

bool FirebaseMessaging::inited = false;
FirebaseMessagingListener *FirebaseMessaging::listener = NULL;
String FirebaseMessaging::_token;
std::atomic<bool> FirebaseMessaging::is_shutting_down{false};

void FirebaseMessagingListener::OnMessage(const firebase::messaging::Message& message)
{
    // task-1084: a late FCM push can fire during/after teardown; bail before touching
    // singleton (which may be freed) or its call_deferred emit (torn-down MessageQueue).
    if (FirebaseMessaging::is_app_shutting_down()) {
        return;
    }
    print_line("FCM Message arrived");
    this->singleton->setMessage(message);
    String from = message.from.c_str();
    String mess_id = message.message_id.c_str();
    print_line("From: " + from);
    print_line("Message ID: " + mess_id);

}

void FirebaseMessagingListener::OnTokenReceived(const char* token)
{
    // task-1084: bail before touching singleton during teardown (see OnMessage).
    if (FirebaseMessaging::is_app_shutting_down()) {
        return;
    }
    String str;
    str += token;
    print_line(String("Get FCM Token: ") + str);
    this->singleton->setToken(str);
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
    if(_token.size() > 0) {
        return Variant(_token);
    } else {
        return Variant();
    }
}

void FirebaseMessaging::setToken(String token)
{
    if (is_shutting_down.load()) {
        return;
    }
    _token = token;
    call_deferred("emit_signal", "token");
}

void FirebaseMessaging::setMessage(const firebase::messaging::Message& message)
{
    if (is_shutting_down.load()) {
        return;
    }
    // Extract relevant data from the message
    Dictionary msg_data;
    msg_data["from"] = String(message.from.c_str());
    msg_data["message_id"] = String(message.message_id.c_str());
    
    // Convert data to Godot format
    Dictionary data_dict;
    for (const auto& entry : message.data) {
        data_dict[String(entry.first.c_str())] = String(entry.second.c_str());
    }
    msg_data["data"] = data_dict;
    
    call_deferred("emit_signal", "message", msg_data);
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
