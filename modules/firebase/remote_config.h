#ifndef FirebaseRemoteConfig_h
#define FirebaseRemoteConfig_h

#include "core/reference.h"
#include "firebase/remote_config.h"
#include "firebase.h"

class FirebaseRemoteConfig : public Reference {
    GDCLASS(FirebaseRemoteConfig, Reference);
    
    protected:
    static bool inited;
    static void _bind_methods();
    static bool data_loaded;

    public:
    
    FirebaseRemoteConfig();
    void set_defaults(const Dictionary& params);
    bool get_boolean(const String& param);
    double get_double(const String& param);
    int64_t get_int(const String& param);
    String get_string(const String& param);
    bool loaded();
    void set_instant_fetching();
    //void OnFetchAndActivateUserCallback(const ::firebase::Future<bool>& future);
    
    private:

    static void* user_data;
    firebase::remote_config::RemoteConfig *rc; 
};

#endif // FirebaseRemoteConfig_h
