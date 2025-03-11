#include "messaging.h"

bool FirebaseMessaging::inited = false;
FirebaseMessagingListener *FirebaseMessaging::listener = NULL;
String FirebaseMessaging::_token;

void FirebaseMessagingListener::OnMessage(const firebase::messaging::Message& message)
{
    print_line("FCM Message arrived");
    this->singleton->setMessage(message);
    String from = message.from.c_str();
    String mess_id = message.message_id.c_str();
    print_line("From: " + from);
    print_line("Message ID: " + mess_id);

}

void FirebaseMessagingListener::OnTokenReceived(const char* token)
{
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
    _token = token;
    call_deferred("emit_signal", "token");
}

void FirebaseMessaging::setMessage(const firebase::messaging::Message& message)
{
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

void FirebaseMessaging::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_token"), &FirebaseMessaging::token);
    ADD_SIGNAL(MethodInfo("token"));
    ADD_SIGNAL(MethodInfo("message", PropertyInfo(Variant::DICTIONARY, "message_data")));
}
