#include "remote_config.h"
#include "convertor.h"
#include "firebase/remote_config.h"

bool FirebaseRemoteConfig::inited = false;
bool FirebaseRemoteConfig::data_loaded = false;
void* FirebaseRemoteConfig::user_data;
firebase::remote_config::RemoteConfig *rc = NULL;

FirebaseRemoteConfig::FirebaseRemoteConfig() {
    if(!inited) {
        print_line("[RemConf] Init remote config");
        user_data = this;
        firebase::App* app = Firebase::AppId();
        if(app != NULL) {
            rc = ::firebase::remote_config::RemoteConfig::GetInstance(app);
            rc->FetchAndActivate().OnCompletion([](const ::firebase::Future<bool>& future)  {
               //std::function<void (const Future<bool> &)>
                 print_line("[RemConf] On Completion test remote config");
                //FirebaseRemoteConfig* frc = static_cast<FirebaseRemoteConfig*>(user_data);
                FirebaseRemoteConfig *frc = (FirebaseRemoteConfig*)user_data;
                if(future.status() == firebase::kFutureStatusComplete) {
                         // activate preloaded configs
                        print_line("[RemConf] Fetched remote config data activated");
                        data_loaded = true;
                        frc->emit_signal("loaded");
                         }
                });
        };
            /*if(firebase::remote_config::Initialized(*app) == firebase::kInitResultSuccess) {
                firebase::remote_config::Fetch().OnCompletion([](const firebase::Future<void>& completed_future, void* user_data) {
                                                                  FirebaseRemoteConfig *frc = (FirebaseRemoteConfig*)user_data;
                                                                  if(completed_future.status() == firebase::kFutureStatusComplete) {
                                                                      if(firebase::remote_config::ActivateFetched()) {
                                                                          // activate preloaded configs
                                                                          print_line("[RemConf] Fetched remote config data activated");
                                                                          data_loaded = true;
                                                                          frc->emit_signal("loaded");
                                                                      } else {
                                                                          print_line("[RemConf] Fetched remote config data was not activated");
                                                                      }
                                                                  } else {
                                                                      print_line("[RemConf] Fetch data failed");
                                                                  }
                                                              }, this);
                inited = true;
            }*/
        }
    };
void FirebaseRemoteConfig::set_instant_fetching()
{
    print_line("[RemConf]Settings fetch intervall to 0");
    ::firebase::remote_config::ConfigSettings settings;
    settings.minimum_fetch_interval_in_milliseconds = 0; // caution, only do this in debug mode!
    rc->SetConfigSettings(settings);
}
void FirebaseRemoteConfig::set_defaults(const Dictionary& params)
{
    firebase::remote_config::ConfigKeyValueVariant pars[params.size()];
    for(int i=0; i<params.size(); i++) {
        Variant key = params.get_key_at_index(i);
        Variant val = params.get_value_at_index(i);
        firebase::remote_config::ConfigKeyValueVariant ckv;
        ckv.key = ((String)key).utf8().get_data();
        if(val.get_type() == Variant::INT)
            ckv.value = firebase::Variant((int)val);
        //else if(val.get_type() == Variant::REAL)
          //  ckv.value = firebase::Variant((double)val);
        else
            ckv.value = Convertor::toFirebaseVariant((String)val);
        pars[i] = ckv;
    }

    rc->SetDefaults(pars, params.size()).OnCompletion([](const ::firebase::Future<void>& future){
         print_line("[RemConf] set defaults completed");
     });
}

bool FirebaseRemoteConfig::get_boolean(const String& param)
{
    return rc->GetBoolean(param.utf8().get_data());
}

double FirebaseRemoteConfig::get_double(const String& param)
{
    return rc->GetDouble(param.utf8().get_data());
}

int64_t FirebaseRemoteConfig::get_int(const String& param)
{
    return rc->GetLong(param.utf8().get_data());

}

String FirebaseRemoteConfig::get_string(const String& param)
{
    return String(rc->GetString(param.utf8().get_data()).c_str());
}

bool FirebaseRemoteConfig::loaded()
{
    return data_loaded;
}

void FirebaseRemoteConfig::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_instant_fetching"),&FirebaseRemoteConfig::set_instant_fetching);
    ClassDB::bind_method(D_METHOD("set_defaults", "params"), &FirebaseRemoteConfig::set_defaults);
    ClassDB::bind_method(D_METHOD("get_boolean", "param"), &FirebaseRemoteConfig::get_boolean);
    ClassDB::bind_method(D_METHOD("get_double", "param"), &FirebaseRemoteConfig::get_double);
    ClassDB::bind_method(D_METHOD("get_int", "param"), &FirebaseRemoteConfig::get_int);
    ClassDB::bind_method(D_METHOD("get_string", "param"), &FirebaseRemoteConfig::get_string);
    ClassDB::bind_method(D_METHOD("loaded"), &FirebaseRemoteConfig::loaded);
    ADD_SIGNAL(MethodInfo("loaded"));
}
