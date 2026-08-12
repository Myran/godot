/* register_types.cpp */

#include "register_types.h"
#include "core/object/class_db.h"
#include "firebase.h"
#include "analytics.h"
//#include "admob.h"
#include "auth.h"
#include "modules/register_module_types.h"
#include "remote_config.h"
#include "database.h"
#include "firestore.h"
#include "messaging.h"
/*

#include "functions.h"

*/
void initialize_firebase_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
			return;
	}
	// task-1502: install before anything can touch the SDK, so an SDK-side
	// failure during the very first App::Create() is still captured.
	Firebase::install_sdk_log_bridge();

	ClassDB::register_class<Firebase>();
	ClassDB::register_class<FirebaseAnalytics>();
	//ClassDB::register_class<FirebaseAdmob>();

	// startar med bara firebase
	ClassDB::register_class<FirebaseAuth>();
	ClassDB::register_class<FirebaseRemoteConfig>();
	ClassDB::register_class<FirebaseDatabase>();
	ClassDB::register_class<FirebaseFirestore>();
	ClassDB::register_class<FirebaseMessaging>();
	/*
	ClassDB::register_class<FirebaseFunctions>();

	*/
}

void uninitialize_firebase_module(ModuleInitializationLevel p_level) {
	//nothing to do here
}
