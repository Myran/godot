#include "remote_config.h"
#include "convertor.h"
#include "firebase/remote_config.h"
#include "firebase/app.h"
#include "firebase/future.h"
// #include "firebase/error.h" // Keep removed as it caused errors
#include "firebase/database/common.h" // Ensure this is included for firebase::database::kErrorNone
#include <vector>
#include "core/string/print_string.h"
#include "core/variant/callable.h"

bool FirebaseRemoteConfig::inited = false;
bool FirebaseRemoteConfig::data_loaded = false;
void* FirebaseRemoteConfig::user_data;
firebase::remote_config::RemoteConfig *rc = nullptr;

FirebaseRemoteConfig::FirebaseRemoteConfig() {
	if(!inited) {
		print_line("[RemConf] Init remote config");
		user_data = this;
		firebase::App* app = Firebase::AppId();
		if(app != nullptr) {
			rc = ::firebase::remote_config::RemoteConfig::GetInstance(app);

			if (rc != nullptr) {
				print_line("[RemConf] Remote config instance obtained successfully.");
				rc->FetchAndActivate().OnCompletion([](const ::firebase::Future<bool>& future) {
					print_line("[RemConf] FetchAndActivate completed.");
					FirebaseRemoteConfig *frc = static_cast<FirebaseRemoteConfig*>(user_data);
					if(future.status() == firebase::kFutureStatusComplete) {
						// CORRECTED: Use firebase::database::kErrorNone as suggested by compiler
						if (future.error() == firebase::database::kErrorNone && future.result() != nullptr && *future.result()) {
							print_line("[RemConf] Fetched remote config data activated.");
							data_loaded = true;
							frc->call_deferred(SNAME("emit_signal"), SNAME("loaded"));
						} else {
							const char* msg = future.error_message() ? future.error_message() : "Unknown failure";
							print_error(String("[RemConf] FetchAndActivate failed. Error: ") + String::num_int64(future.error()) + " - " + msg);
						}
					} else {
						print_error(String("[RemConf] FetchAndActivate future did not complete. Status: ") + String::num_int64(future.status()));
					}
				});
				inited = true;
			} else {
				print_error("[RemConf] Failed to get Remote Config instance (GetInstance returned null).");
				rc = nullptr;
			}
		} else {
			print_error("[RemConf] Firebase App not available for Remote Config.");
		}
	}
}

void FirebaseRemoteConfig::set_instant_fetching() {
	if (!rc) { print_error("[RemConf] Remote Config not initialized."); return; }
	print_line("[RemConf] Setting fetch interval to 0");
	::firebase::remote_config::ConfigSettings settings;
	settings.minimum_fetch_interval_in_milliseconds = 0;
	rc->SetConfigSettings(settings);
}

void FirebaseRemoteConfig::set_defaults(const Dictionary& params) {
	if (!rc) { print_error("[RemConf] Remote Config not initialized."); return; }
	print_line("[RemConf] set_defaults Started");

	std::vector<firebase::remote_config::ConfigKeyValueVariant> defaults_vector;
	defaults_vector.reserve(params.size());

	Array keys = params.keys();
	for (int i = 0; i < keys.size(); ++i) {
		Variant key = keys[i];
		Variant val = params[key];
		if (key.get_type() != Variant::STRING) { continue; }
		firebase::remote_config::ConfigKeyValueVariant ckv;
		ckv.key = ((String)key).utf8().get_data();
		ckv.value = Convertor::toFirebaseVariant(val);
		if (!ckv.value.is_null()) { defaults_vector.push_back(ckv); }
	}

	if (!defaults_vector.empty()) {
		rc->SetDefaults(defaults_vector.data(), defaults_vector.size()).OnCompletion([](const ::firebase::Future<void>& future){
			// CORRECTED: Use firebase::database::kErrorNone as suggested by compiler
			if (future.status() == firebase::kFutureStatusComplete && future.error() == firebase::database::kErrorNone) {
				print_line("[RemConf] set_defaults completed successfully.");
			} else {
				const char* msg = future.error_message() ? future.error_message() : "Unknown error";
				print_error(String("[RemConf] set_defaults failed. Error: ") + String::num_int64(future.error()) + " - " + msg);
			}
		 });
	} else {
		print_line("[RemConf] No valid defaults provided to set_defaults.");
	}
}

bool FirebaseRemoteConfig::get_boolean(const String& param) { return rc ? rc->GetBoolean(param.utf8().get_data()) : false; }
double FirebaseRemoteConfig::get_double(const String& param) { return rc ? rc->GetDouble(param.utf8().get_data()) : 0.0; }
int64_t FirebaseRemoteConfig::get_int(const String& param) { return rc ? rc->GetLong(param.utf8().get_data()) : 0; }
String FirebaseRemoteConfig::get_string(const String& param) { return rc ? String::utf8(rc->GetString(param.utf8().get_data()).c_str()) : ""; }
bool FirebaseRemoteConfig::loaded() { return data_loaded; }

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
