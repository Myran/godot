#ifndef FirebaseAnalytics_h
#define FirebaseAnalytics_h

#include "core/object/ref_counted.h"
#include "core/os/os.h"
#include "core/string/ustring.h"
#include "core/variant/variant.h"
#include "core/os/mutex.h"
#include "core/os/memory.h"

// Forward declare Firebase SDK types
namespace firebase {
class App;
namespace analytics {
} // namespace analytics
} // namespace firebase

#include "firebase.h"
#include <map>
#include <memory>
#include <atomic>
#include <mutex>
#include <vector>

// Include Firebase SDK headers for Analytics
// Note: event_names.h, parameter_names.h, user_property_names.h are not needed
// as we define our own constants for GDScript compatibility
#include "firebase/analytics.h"

class FirebaseAnalytics : public RefCounted {
	GDCLASS(FirebaseAnalytics, RefCounted);

private:
	// Thread-safe initialization guard
	static std::mutex initialization_mutex;
	static std::atomic<bool> inited;
	static std::atomic<bool> is_shutting_down;

	// Private constructor for singleton pattern
	FirebaseAnalytics();

protected:
	static void _bind_methods();

public:
	// macOS crash prevention - shutdown control methods
	static void begin_shutdown();
	static bool is_app_shutting_down();

	// Delete copy constructor for singleton pattern
	FirebaseAnalytics(const FirebaseAnalytics&) = delete;
	~FirebaseAnalytics();

	// --- Initialization ---
	void initialize();
	bool is_initialized() const;

	// --- Core Analytics Methods (Fire-and-Forget) ---

	// Log an event without parameters
	void log_event(const String& event_name);

	// Log an event with a single string parameter
	void log_event_string(const String& event_name, const String& param_name, const String& value);

	// Log an event with a single int parameter
	void log_event_int(const String& event_name, const String& param_name, int64_t value);

	// Log an event with a single float (double) parameter
	void log_event_double(const String& event_name, const String& param_name, double value);

	// Log an event with multiple parameters from Dictionary
	void log_event_params(const String& event_name, const Dictionary& params);

	// --- User Properties ---

	// Set a user property (key-value pair for user segmentation)
	void set_user_property(const String& name, const String& value);

	// --- User ID ---

	// Set user ID for cross-device tracking
	void set_user_id(const String& user_id);

	// --- Configuration ---

	// Enable or disable analytics collection (for privacy/GDPR)
	void set_analytics_collection_enabled(bool enabled);

	// Reset analytics data (clear all cached data)
	void reset_analytics_data();

	// Set minimum session duration (in milliseconds)
	void set_session_timeout_duration(int milliseconds);

	// --- Predefined Event Constants ---
	// These are exposed as constants for GDScript convenience

	// Event names
	static const String EVENT_AD_IMPRESSION;
	static const String EVENT_ADD_PAYMENT_INFO;
	static const String EVENT_ADD_SHIPPING_INFO;
	static const String EVENT_ADD_TO_CART;
	static const String EVENT_ADD_TO_WISHLIST;
	static const String EVENT_APP_OPEN;
	static const String EVENT_BEGIN_CHECKOUT;
	static const String EVENT_CAMPAIGN_DETAILS;
	static const String EVENT_CHECKOUT_PROGRESS;
	static const String EVENT_EARN_VIRTUAL_CURRENCY;
	static const String EVENT_ECOMMERCE_PURCHASE;
	static const String EVENT_GENERATE_LEAD;
	static const String EVENT_JOIN_GROUP;
	static const String EVENT_LEVEL_END;
	static const String EVENT_LEVEL_START;
	static const String EVENT_LEVEL_UP;
	static const String EVENT_LOGIN;
	static const String EVENT_POST_SCORE;
	static const String EVENT_PURCHASE;
	static const String EVENT_REFUND;
	static const String EVENT_REMOVE_FROM_CART;
	static const String EVENT_SCREEN_VIEW;
	static const String EVENT_SEARCH;
	static const String EVENT_SELECT_CONTENT;
	static const String EVENT_SELECT_ITEM;
	static const String EVENT_SHARE;
	static const String EVENT_SIGN_UP;
	static const String EVENT_SPEND_VIRTUAL_CURRENCY;
	static const String EVENT_TUTORIAL_BEGIN;
	static const String EVENT_TUTORIAL_COMPLETE;
	static const String EVENT_UNLOCK_ACHIEVEMENT;
	static const String EVENT_VIEW_ITEM;
	static const String EVENT_VIEW_ITEM_LIST;
	static const String EVENT_VIEW_SEARCH_RESULTS;

	// Common parameter names
	static const String PARAM_ACHIEVEMENT_ID;
	static const String PARAM_LEVEL;
	static const String PARAM_CHARACTER;
	static const String PARAM_SCORE;
	static const String PARAM_ITEM_ID;
	static const String PARAM_ITEM_NAME;
	static const String PARAM_ITEM_CATEGORY;
	static const String PARAM_QUANTITY;
	static const String PARAM_PRICE;
	static const String PARAM_VALUE;
	static const String PARAM_CURRENCY;
	static const String PARAM_VIRTUAL_CURRENCY_NAME;
	static const String PARAM_SIGN_UP_METHOD;
	static const String PARAM_GROUP_ID;
	static const String PARAM_SCREEN_NAME;
	static const String PARAM_SEARCH_TERM;

	// Common user property names
	static const String PROPERTY_SIGN_UP_METHOD;
};

#endif // FirebaseAnalytics_h
