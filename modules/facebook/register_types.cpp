#include "register_types.h"

#include "core/version.h"

#if VERSION_MAJOR == 4
#include "core/config/engine.h"
#else
#include "core/engine.h"
#endif

#include "Facebook.hpp"

FacebookPlugin *_singleton = NULL;
void initialize_facebook_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
			return;
	}
	_singleton = memnew(FacebookPlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("Facebook", _singleton));
}
void uninitialize_facebook_module(ModuleInitializationLevel p_level) {
	if (_singleton) {
		memdelete(_singleton);
	}
}
