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
#include "messaging.h"
/*

#include "functions.h"

*/
void initialize_firebase_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
			return;
	}
	ClassDB::register_class<Firebase>();
	ClassDB::register_class<FirebaseAnalytics>();
	//ClassDB::register_class<FirebaseAdmob>();

	// startar med bara firebase
	ClassDB::register_class<FirebaseAuth>();
	ClassDB::register_class<FirebaseRemoteConfig>();
	ClassDB::register_class<FirebaseDatabase>();
	ClassDB::register_class<FirebaseMessaging>();
	/*
	ClassDB::register_class<FirebaseFunctions>();

	*/
}

void uninitialize_firebase_module(ModuleInitializationLevel p_level) {
	//nothing to do here
}
