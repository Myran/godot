// godot/modules/firebase/analytics.cpp
#include "analytics.h"
#include "firebase.h" // For Firebase::AppId()

// Godot Core Headers
#include "core/error/error_macros.h"
#include "core/object/class_db.h"
#include "core/os/os.h"
#include "core/string/print_string.h"

// Firebase SDK Headers
#include "firebase/app.h"
#include "firebase/analytics.h"

// --- Static Constants: Event Names ---
const String FirebaseAnalytics::EVENT_AD_IMPRESSION = "ad_impression";
const String FirebaseAnalytics::EVENT_ADD_PAYMENT_INFO = "add_payment_info";
const String FirebaseAnalytics::EVENT_ADD_SHIPPING_INFO = "add_shipping_info";
const String FirebaseAnalytics::EVENT_ADD_TO_CART = "add_to_cart";
const String FirebaseAnalytics::EVENT_ADD_TO_WISHLIST = "add_to_wishlist";
const String FirebaseAnalytics::EVENT_APP_OPEN = "app_open";
const String FirebaseAnalytics::EVENT_BEGIN_CHECKOUT = "begin_checkout";
const String FirebaseAnalytics::EVENT_CAMPAIGN_DETAILS = "campaign_details";
const String FirebaseAnalytics::EVENT_CHECKOUT_PROGRESS = "checkout_progress";
const String FirebaseAnalytics::EVENT_EARN_VIRTUAL_CURRENCY = "earn_virtual_currency";
const String FirebaseAnalytics::EVENT_ECOMMERCE_PURCHASE = "ecommerce_purchase";
const String FirebaseAnalytics::EVENT_GENERATE_LEAD = "generate_lead";
const String FirebaseAnalytics::EVENT_JOIN_GROUP = "join_group";
const String FirebaseAnalytics::EVENT_LEVEL_END = "level_end";
const String FirebaseAnalytics::EVENT_LEVEL_START = "level_start";
const String FirebaseAnalytics::EVENT_LEVEL_UP = "level_up";
const String FirebaseAnalytics::EVENT_LOGIN = "login";
const String FirebaseAnalytics::EVENT_POST_SCORE = "post_score";
const String FirebaseAnalytics::EVENT_PURCHASE = "purchase";
const String FirebaseAnalytics::EVENT_REFUND = "refund";
const String FirebaseAnalytics::EVENT_REMOVE_FROM_CART = "remove_from_cart";
const String FirebaseAnalytics::EVENT_SCREEN_VIEW = "screen_view";
const String FirebaseAnalytics::EVENT_SEARCH = "search";
const String FirebaseAnalytics::EVENT_SELECT_CONTENT = "select_content";
const String FirebaseAnalytics::EVENT_SELECT_ITEM = "select_item";
const String FirebaseAnalytics::EVENT_SHARE = "share";
const String FirebaseAnalytics::EVENT_SIGN_UP = "sign_up";
const String FirebaseAnalytics::EVENT_SPEND_VIRTUAL_CURRENCY = "spend_virtual_currency";
const String FirebaseAnalytics::EVENT_TUTORIAL_BEGIN = "tutorial_begin";
const String FirebaseAnalytics::EVENT_TUTORIAL_COMPLETE = "tutorial_complete";
const String FirebaseAnalytics::EVENT_UNLOCK_ACHIEVEMENT = "unlock_achievement";
const String FirebaseAnalytics::EVENT_VIEW_ITEM = "view_item";
const String FirebaseAnalytics::EVENT_VIEW_ITEM_LIST = "view_item_list";
const String FirebaseAnalytics::EVENT_VIEW_SEARCH_RESULTS = "view_search_results";

// --- Static Constants: Parameter Names ---
const String FirebaseAnalytics::PARAM_ACHIEVEMENT_ID = "achievement_id";
const String FirebaseAnalytics::PARAM_CHARACTER = "character";
const String FirebaseAnalytics::PARAM_LEVEL = "level";
const String FirebaseAnalytics::PARAM_SCORE = "score";
const String FirebaseAnalytics::PARAM_ITEM_ID = "item_id";
const String FirebaseAnalytics::PARAM_ITEM_NAME = "item_name";
const String FirebaseAnalytics::PARAM_ITEM_CATEGORY = "item_category";
const String FirebaseAnalytics::PARAM_QUANTITY = "quantity";
const String FirebaseAnalytics::PARAM_PRICE = "price";
const String FirebaseAnalytics::PARAM_VALUE = "value";
const String FirebaseAnalytics::PARAM_CURRENCY = "currency";
const String FirebaseAnalytics::PARAM_VIRTUAL_CURRENCY_NAME = "virtual_currency_name";
const String FirebaseAnalytics::PARAM_SIGN_UP_METHOD = "sign_up_method";
const String FirebaseAnalytics::PARAM_GROUP_ID = "group_id";
const String FirebaseAnalytics::PARAM_SCREEN_NAME = "screen_name";
const String FirebaseAnalytics::PARAM_SEARCH_TERM = "search_term";

// --- Static Constants: User Property Names ---
const String FirebaseAnalytics::PROPERTY_SIGN_UP_METHOD = "sign_up_method";

// --- Thread-Safe Singleton Member Initialization ---
std::mutex FirebaseAnalytics::initialization_mutex;
std::atomic<bool> FirebaseAnalytics::inited(false);
std::atomic<bool> FirebaseAnalytics::is_shutting_down(false);
Ref<FirebaseAnalytics> FirebaseAnalytics::singleton_instance;
std::mutex FirebaseAnalytics::instance_mutex;

// --- Constructor ---
FirebaseAnalytics::FirebaseAnalytics() {
	// Instance initialization if needed
}

// --- Destructor ---
FirebaseAnalytics::~FirebaseAnalytics() {
	// Cleanup handled by cleanup() method
}

// --- Singleton Access ---
FirebaseAnalytics& FirebaseAnalytics::get_instance() {
	std::lock_guard<std::mutex> lock(instance_mutex);
	if (singleton_instance.is_null()) {
		singleton_instance = memnew(FirebaseAnalytics);
	}
	return *singleton_instance.ptr();
}

// --- Cleanup ---
void FirebaseAnalytics::cleanup() {
	std::lock_guard<std::mutex> lock(instance_mutex);
	if (singleton_instance.is_valid()) {
		singleton_instance->reset_analytics_data();
		singleton_instance.unref();
	}
	inited.store(false);
}

// --- Shutdown Control ---
void FirebaseAnalytics::begin_shutdown() {
	is_shutting_down.store(true);
}

bool FirebaseAnalytics::is_app_shutting_down() {
	return is_shutting_down.load();
}

// --- Bind Methods ---
void FirebaseAnalytics::_bind_methods() {
	// Initialization
	ClassDB::bind_method(D_METHOD("initialize"), &FirebaseAnalytics::initialize);
	ClassDB::bind_method(D_METHOD("is_initialized"), &FirebaseAnalytics::is_initialized);

	// Core Analytics Methods
	ClassDB::bind_method(D_METHOD("log_event", "event_name"), &FirebaseAnalytics::log_event);
	ClassDB::bind_method(D_METHOD("log_event_string", "event_name", "param_name", "value"), &FirebaseAnalytics::log_event_string);
	ClassDB::bind_method(D_METHOD("log_event_int", "event_name", "param_name", "value"), &FirebaseAnalytics::log_event_int);
	ClassDB::bind_method(D_METHOD("log_event_double", "event_name", "param_name", "value"), &FirebaseAnalytics::log_event_double);
	ClassDB::bind_method(D_METHOD("log_event_params", "event_name", "params"), &FirebaseAnalytics::log_event_params);

	// User Properties
	ClassDB::bind_method(D_METHOD("set_user_property", "name", "value"), &FirebaseAnalytics::set_user_property);

	// User ID
	ClassDB::bind_method(D_METHOD("set_user_id", "user_id"), &FirebaseAnalytics::set_user_id);

	// Configuration
	ClassDB::bind_method(D_METHOD("set_analytics_collection_enabled", "enabled"), &FirebaseAnalytics::set_analytics_collection_enabled);
	ClassDB::bind_method(D_METHOD("reset_analytics_data"), &FirebaseAnalytics::reset_analytics_data);
	ClassDB::bind_method(D_METHOD("set_session_timeout_duration", "milliseconds"), &FirebaseAnalytics::set_session_timeout_duration);
}

// --- Initialize ---
void FirebaseAnalytics::initialize() {
	std::lock_guard<std::mutex> lock(initialization_mutex);
	if (inited.load()) {
		print_verbose("[Analytics C++] Already initialized, skipping.");
		return;
	}

	firebase::App* app = Firebase::AppId();
	if (!app) {
		print_error("[Analytics C++] Firebase App not initialized. Cannot initialize Analytics.");
		return;
	}

	// Initialize Firebase Analytics (fire-and-forget, no Future needed)
	firebase::analytics::Initialize(*app);
	firebase::analytics::SetAnalyticsCollectionEnabled(true);

	inited.store(true);
	print_verbose("[Analytics C++] Initialized successfully.");
}

bool FirebaseAnalytics::is_initialized() const {
	return inited.load();
}

// --- Helper: Convert Dictionary to Firebase Parameters ---
// NOTE: This function is now inline-only in log_event_params to ensure CharStrings
// live in the same scope as the Parameters that reference them.

// --- Core Analytics Methods (Fire-and-Forget) ---

void FirebaseAnalytics::log_event(const String& event_name) {
	if (!inited.load() || is_shutting_down.load()) {
		print_verbose("[Analytics C++] Not initialized or shutting down. Ignoring log_event.");
		return;
	}

	if (event_name.is_empty()) {
		print_verbose("[Analytics C++] Event name is empty. Ignoring.");
		return;
	}

	// CRITICAL FIX: Store CharString to prevent dangling pointer
	CharString event_cs = event_name.utf8();
	firebase::analytics::LogEvent(event_cs.get_data());
	print_verbose(String("[Analytics C++] Logged event: ") + event_name);
}

void FirebaseAnalytics::log_event_string(const String& event_name, const String& param_name, const String& value) {
	if (!inited.load() || is_shutting_down.load()) {
		print_verbose("[Analytics C++] Not initialized or shutting down. Ignoring log_event_string.");
		return;
	}

	// CRITICAL FIX: Store CharString objects to prevent dangling pointers
	CharString event_cs = event_name.utf8();
	CharString param_cs = param_name.utf8();
	CharString value_cs = value.utf8();

	firebase::analytics::LogEvent(event_cs.get_data(), param_cs.get_data(), value_cs.get_data());
	print_verbose(String("[Analytics C++] Logged event: ") + event_name + " with string param.");
}

void FirebaseAnalytics::log_event_int(const String& event_name, const String& param_name, int64_t value) {
	if (!inited.load() || is_shutting_down.load()) {
		print_verbose("[Analytics C++] Not initialized or shutting down. Ignoring log_event_int.");
		return;
	}

	// CRITICAL FIX: Store CharString objects to prevent dangling pointers
	CharString event_cs = event_name.utf8();
	CharString param_cs = param_name.utf8();

	firebase::analytics::LogEvent(event_cs.get_data(), param_cs.get_data(), value);
	print_verbose(String("[Analytics C++] Logged event: ") + event_name + " with int param.");
}

void FirebaseAnalytics::log_event_double(const String& event_name, const String& param_name, double value) {
	if (!inited.load() || is_shutting_down.load()) {
		print_verbose("[Analytics C++] Not initialized or shutting down. Ignoring log_event_double.");
		return;
	}

	// CRITICAL FIX: Store CharString objects to prevent dangling pointers
	CharString event_cs = event_name.utf8();
	CharString param_cs = param_name.utf8();

	firebase::analytics::LogEvent(event_cs.get_data(), param_cs.get_data(), value);
	print_verbose(String("[Analytics C++] Logged event: ") + event_name + " with double param.");
}

void FirebaseAnalytics::log_event_params(const String& event_name, const Dictionary& params) {
	if (!inited.load() || is_shutting_down.load()) {
		print_verbose("[Analytics C++] Not initialized or shutting down. Ignoring log_event_params.");
		return;
	}

	if (event_name.is_empty()) {
		print_verbose("[Analytics C++] Event name is empty. Ignoring.");
		return;
	}

	// CRITICAL FIX: Store CharString to prevent dangling pointer
	CharString event_cs = event_name.utf8();

	// Handle empty params - use simple LogEvent
	if (params.is_empty()) {
		firebase::analytics::LogEvent(event_cs.get_data());
		print_verbose(String("[Analytics C++] Logged event: ") + event_name);
		return;
	}

	// CRITICAL: All CharStrings MUST be declared here to ensure they live until
	// firebase::analytics::LogEvent completes. The Parameter objects store pointers
	// to this data, so the CharStrings must outlive the Parameters.
	std::vector<CharString> key_strings;
	std::vector<CharString> value_strings;
	std::vector<firebase::analytics::Parameter> fb_params;

	Array keys = params.keys();
	key_strings.reserve(keys.size());
	value_strings.reserve(keys.size());
	fb_params.reserve(keys.size());

	// Convert Dictionary to Firebase Parameters (inlined to ensure CharString lifetime)
	for (int i = 0; i < keys.size(); i++) {
		Variant key_var = keys[i];
		Variant value_var = params[key_var];

		// Convert key to CharString and store in vector
		String key_str = key_var;
		key_strings.push_back(key_str.utf8());
		const char* key_cstr = key_strings.back().get_data();

		// Convert value based on type and create Parameter
		if (value_var.get_type() == Variant::STRING) {
			String value_str = value_var;
			value_strings.push_back(value_str.utf8());
			const char* value_cstr = value_strings.back().get_data();
			fb_params.push_back(firebase::analytics::Parameter(key_cstr, value_cstr));
		} else if (value_var.get_type() == Variant::INT) {
			int64_t value_int = value_var;
			fb_params.push_back(firebase::analytics::Parameter(key_cstr, static_cast<int64_t>(value_int)));
		} else if (value_var.get_type() == Variant::FLOAT) {
			double value_double = value_var;
			fb_params.push_back(firebase::analytics::Parameter(key_cstr, value_double));
		} else if (value_var.get_type() == Variant::BOOL) {
			bool value_bool = value_var;
			fb_params.push_back(firebase::analytics::Parameter(key_cstr, static_cast<int64_t>(value_bool ? 1LL : 0LL)));
		} else {
			// For unsupported types, convert to string representation
			String value_str = String(value_var);
			value_strings.push_back(value_str.utf8());
			const char* value_cstr = value_strings.back().get_data();
			fb_params.push_back(firebase::analytics::Parameter(key_cstr, value_cstr));
		}
	}

	// Now call LogEvent - all CharStrings are still valid in this scope
	firebase::analytics::LogEvent(event_cs.get_data(), fb_params.data(), fb_params.size());
	print_verbose(String("[Analytics C++] Logged event: ") + event_name + " with " + itos(fb_params.size()) + " params.");
}

// --- User Properties ---

void FirebaseAnalytics::set_user_property(const String& name, const String& value) {
	if (!inited.load() || is_shutting_down.load()) {
		print_verbose("[Analytics C++] Not initialized or shutting down. Ignoring set_user_property.");
		return;
	}

	if (name.is_empty()) {
		print_verbose("[Analytics C++] User property name is empty. Ignoring.");
		return;
	}

	// CRITICAL FIX: Store CharString objects to prevent dangling pointers
	CharString name_cs = name.utf8();
	CharString value_cs = value.utf8();

	firebase::analytics::SetUserProperty(name_cs.get_data(), value_cs.get_data());
	print_verbose(String("[Analytics C++] Set user property: ") + name);
}

// --- User ID ---

void FirebaseAnalytics::set_user_id(const String& user_id) {
	if (!inited.load() || is_shutting_down.load()) {
		print_verbose("[Analytics C++] Not initialized or shutting down. Ignoring set_user_id.");
		return;
	}

	// CRITICAL FIX: Store CharString to prevent dangling pointer
	CharString user_id_cs = user_id.utf8();

	firebase::analytics::SetUserId(user_id_cs.get_data());
	print_verbose(String("[Analytics C++] Set user ID: ") + user_id);
}

// --- Configuration ---

void FirebaseAnalytics::set_analytics_collection_enabled(bool enabled) {
	if (!inited.load() || is_shutting_down.load()) {
		print_verbose("[Analytics C++] Not initialized or shutting down. Ignoring set_analytics_collection_enabled.");
		return;
	}

	firebase::analytics::SetAnalyticsCollectionEnabled(enabled);
	print_verbose(String("[Analytics C++] Analytics collection ") + (enabled ? "enabled" : "disabled"));
}

void FirebaseAnalytics::reset_analytics_data() {
	if (!inited.load() || is_shutting_down.load()) {
		print_verbose("[Analytics C++] Not initialized or shutting down. Ignoring reset_analytics_data.");
		return;
	}

	firebase::analytics::ResetAnalyticsData();
	print_verbose("[Analytics C++] Analytics data reset");
}

void FirebaseAnalytics::set_session_timeout_duration(int milliseconds) {
	if (!inited.load() || is_shutting_down.load()) {
		print_verbose("[Analytics C++] Not initialized or shutting down. Ignoring set_session_timeout_duration.");
		return;
	}

	firebase::analytics::SetSessionTimeoutDuration(milliseconds);
	print_verbose(String("[Analytics C++] Session timeout set to ") + itos(milliseconds) + "ms");
}
