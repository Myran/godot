## Firebase Analytics Service - Handles Analytics event logging
## Fire-and-forget pattern - no async callbacks needed
class_name AnalyticsService
extends RefCounted

# Firebase Analytics Service - Handles event logging and user properties
# All operations are synchronous fire-and-forget (no await needed)

var _native: FirebaseAnalytics
var _is_initialized: bool = false


## Initialize with native C++ FirebaseAnalytics instance
func _init(native_analytics: FirebaseAnalytics = null) -> void:
	if native_analytics != null and is_instance_valid(native_analytics):
		_native = native_analytics
	else:
		_native = ClassDB.instantiate("FirebaseAnalytics") as FirebaseAnalytics

	if is_instance_valid(_native):
		_native.initialize()
		_is_initialized = _native.is_initialized()
		Log.info("AnalyticsService initialized", {}, [Log.TAG_FIREBASE, Log.TAG_INITIALIZATION])
	else:
		Log.error(
			"AnalyticsService: Failed to get FirebaseAnalytics native instance",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)


func is_available() -> bool:
	return _is_initialized and is_instance_valid(_native)


## --- Core Event Logging ---


## Log a simple event without parameters
func log_event(event_name: String) -> void:
	if not is_available():
		Log.warning("AnalyticsService: Not available for log_event", {}, [Log.TAG_FIREBASE])
		return

	_native.log_event(event_name)
	Log.debug(
		"AnalyticsService: log_event - " + event_name, {"event": event_name}, [Log.TAG_FIREBASE]
	)


## Log an event with a single string parameter
func log_event_string(event_name: String, param_name: String, value: String) -> void:
	if not is_available():
		Log.warning("AnalyticsService: Not available for log_event_string", {}, [Log.TAG_FIREBASE])
		return

	_native.log_event_string(event_name, param_name, value)
	Log.debug(
		"AnalyticsService: log_event_string - " + event_name,
		{"event": event_name, "param": param_name},
		[Log.TAG_FIREBASE]
	)


## Log an event with a single int parameter
func log_event_int(event_name: String, param_name: String, value: int) -> void:
	if not is_available():
		Log.warning("AnalyticsService: Not available for log_event_int", {}, [Log.TAG_FIREBASE])
		return

	_native.log_event_int(event_name, param_name, value)
	Log.debug(
		"AnalyticsService: log_event_int - " + event_name,
		{"event": event_name, "param": param_name},
		[Log.TAG_FIREBASE]
	)


## Log an event with a single float parameter
func log_event_double(event_name: String, param_name: String, value: float) -> void:
	if not is_available():
		Log.warning("AnalyticsService: Not available for log_event_double", {}, [Log.TAG_FIREBASE])
		return

	_native.log_event_double(event_name, param_name, value)
	Log.debug(
		"AnalyticsService: log_event_double - " + event_name,
		{"event": event_name, "param": param_name},
		[Log.TAG_FIREBASE]
	)


## Log an event with multiple parameters from Dictionary
func log_event_params(event_name: String, params: Dictionary) -> void:
	if not is_available():
		Log.warning("AnalyticsService: Not available for log_event_params", {}, [Log.TAG_FIREBASE])
		return

	_native.log_event_params(event_name, params)
	Log.debug(
		"AnalyticsService: log_event_params - " + event_name,
		{"event": event_name, "param_count": params.size()},
		[Log.TAG_FIREBASE]
	)


## --- User Properties ---


## Set a user property for segmentation
func set_user_property(name: String, value: String) -> void:
	if not is_available():
		Log.warning("AnalyticsService: Not available for set_user_property", {}, [Log.TAG_FIREBASE])
		return

	_native.set_user_property(name, value)
	Log.debug(
		"AnalyticsService: set_user_property - " + name,
		{"property": name, "value": value},
		[Log.TAG_FIREBASE]
	)


## --- User ID ---


## Set user ID for cross-device tracking
func set_user_id(user_id: String) -> void:
	if not is_available():
		Log.warning("AnalyticsService: Not available for set_user_id", {}, [Log.TAG_FIREBASE])
		return

	_native.set_user_id(user_id)
	Log.info("AnalyticsService: set_user_id", {"user_id": user_id}, [Log.TAG_FIREBASE])


## --- Configuration ---


## Enable or disable analytics collection (for privacy/GDPR)
func set_analytics_collection_enabled(enabled: bool) -> void:
	if not is_available():
		Log.warning(
			"AnalyticsService: Not available for set_analytics_collection_enabled",
			{},
			[Log.TAG_FIREBASE]
		)
		return

	_native.set_analytics_collection_enabled(enabled)
	Log.info(
		"AnalyticsService: Collection " + ("enabled" if enabled else "disabled"),
		{"enabled": enabled},
		[Log.TAG_FIREBASE]
	)


## Reset analytics data (clear cached data)
func reset_analytics_data() -> void:
	if not is_available():
		Log.warning(
			"AnalyticsService: Not available for reset_analytics_data", {}, [Log.TAG_FIREBASE]
		)
		return

	_native.reset_analytics_data()
	Log.info("AnalyticsService: Data reset", {}, [Log.TAG_FIREBASE])


## Set session timeout duration in milliseconds
func set_session_timeout_duration(milliseconds: int) -> void:
	if not is_available():
		Log.warning(
			"AnalyticsService: Not available for set_session_timeout_duration",
			{},
			[Log.TAG_FIREBASE]
		)
		return

	_native.set_session_timeout_duration(milliseconds)
	Log.debug(
		"AnalyticsService: Session timeout set to " + str(milliseconds) + "ms",
		{"ms": milliseconds},
		[Log.TAG_FIREBASE]
	)


## --- Game-Specific Event Helpers ---
## These provide convenient wrappers for common game analytics events


## Track when a player starts a battle
func track_battle_start(battle_type: String, level: int) -> void:
	log_event_params("battle_start", {"type": battle_type, "level": level})


## Track when a player ends a battle (win or lose)
func track_battle_end(battle_type: String, level: int, victory: bool, score: int) -> void:
	log_event_params(
		"battle_end", {"type": battle_type, "level": level, "victory": victory, "score": score}
	)


## Track when a card is played
func track_card_played(card_id: String, card_name: String, level: int) -> void:
	log_event_params("card_played", {"id": card_id, "name": card_name, "level": level})


## Track when a level is completed
func track_level_complete(level: int, stars: int) -> void:
	log_event_params("level_complete", {"level": level, "stars": stars})


## Track when a level is failed
func track_level_failed(level: int, attempts: int) -> void:
	log_event_params("level_failed", {"level": level, "attempts": attempts})


## Track when a player makes a purchase
func track_purchase(item_id: String, item_name: String, value: float, currency: String) -> void:
	log_event_params(
		"purchase",
		{"item_id": item_id, "item_name": item_name, "value": value, "currency": currency}
	)


## Track tutorial begin
func track_tutorial_begin() -> void:
	log_event(EVENT_TUTORIAL_BEGIN)


## Track tutorial complete
func track_tutorial_complete() -> void:
	log_event(EVENT_TUTORIAL_COMPLETE)


## Track achievement unlock
func track_achievement_unlock(achievement_id: String) -> void:
	log_event_params(EVENT_UNLOCK_ACHIEVEMENT, {PARAM_ACHIEVEMENT_ID: achievement_id})


## Track score post
func track_post_score(score: int, level: int) -> void:
	log_event_params(EVENT_POST_SCORE, {PARAM_SCORE: score, PARAM_LEVEL: level})


## Track level up
func track_level_up(level: int, character: String = "") -> void:
	var params: Dictionary = {PARAM_LEVEL: level}
	if not character.is_empty():
		params[PARAM_CHARACTER] = character
	log_event_params(EVENT_LEVEL_UP, params)


## Track screen view
func track_screen_view(screen_name: String, screen_class: String = "") -> void:
	var params: Dictionary = {PARAM_SCREEN_NAME: screen_name}
	if not screen_class.is_empty():
		params["screen_class"] = screen_class
	log_event_params(EVENT_SCREEN_VIEW, params)


## Track login
func track_login(method: String = "") -> void:
	var params: Dictionary = {}
	if not method.is_empty():
		params[PARAM_SIGN_UP_METHOD] = method
	log_event_params(EVENT_LOGIN, params)


## Track sign up
func track_sign_up(method: String) -> void:
	log_event_params(EVENT_SIGN_UP, {PARAM_SIGN_UP_METHOD: method})


## Track share event
func track_share(content_type: String, item_id: String = "") -> void:
	var params: Dictionary = {"content_type": content_type}
	if not item_id.is_empty():
		params["item_id"] = item_id
	log_event_params(EVENT_SHARE, params)


## Track search
func track_search(search_term: String) -> void:
	log_event_params(EVENT_SEARCH, {PARAM_SEARCH_TERM: search_term})


## --- Predefined Event Constants ---
## These match Firebase Analytics predefined events

## Event names
const EVENT_AD_IMPRESSION: String = "ad_impression"
const EVENT_ADD_PAYMENT_INFO: String = "add_payment_info"
const EVENT_ADD_SHIPPING_INFO: String = "add_shipping_info"
const EVENT_ADD_TO_CART: String = "add_to_cart"
const EVENT_ADD_TO_WISHLIST: String = "add_to_wishlist"
const EVENT_APP_OPEN: String = "app_open"
const EVENT_BEGIN_CHECKOUT: String = "begin_checkout"
const EVENT_CAMPAIGN_DETAILS: String = "campaign_details"
const EVENT_CHECKOUT_PROGRESS: String = "checkout_progress"
const EVENT_EARN_VIRTUAL_CURRENCY: String = "earn_virtual_currency"
const EVENT_ECOMMERCE_PURCHASE: String = "ecommerce_purchase"
const EVENT_GENERATE_LEAD: String = "generate_lead"
const EVENT_JOIN_GROUP: String = "join_group"
const EVENT_LEVEL_END: String = "level_end"
const EVENT_LEVEL_START: String = "level_start"
const EVENT_LEVEL_UP: String = "level_up"
const EVENT_LOGIN: String = "login"
const EVENT_POST_SCORE: String = "post_score"
const EVENT_PURCHASE: String = "purchase"
const EVENT_REFUND: String = "refund"
const EVENT_REMOVE_FROM_CART: String = "remove_from_cart"
const EVENT_SCREEN_VIEW: String = "screen_view"
const EVENT_SEARCH: String = "search"
const EVENT_SELECT_CONTENT: String = "select_content"
const EVENT_SELECT_ITEM: String = "select_item"
const EVENT_SHARE: String = "share"
const EVENT_SIGN_UP: String = "sign_up"
const EVENT_SPEND_VIRTUAL_CURRENCY: String = "spend_virtual_currency"
const EVENT_TUTORIAL_BEGIN: String = "tutorial_begin"
const EVENT_TUTORIAL_COMPLETE: String = "tutorial_complete"
const EVENT_UNLOCK_ACHIEVEMENT: String = "unlock_achievement"
const EVENT_VIEW_ITEM: String = "view_item"
const EVENT_VIEW_ITEM_LIST: String = "view_item_list"
const EVENT_VIEW_SEARCH_RESULTS: String = "view_search_results"

## Common parameter names
const PARAM_ACHIEVEMENT_ID: String = "achievement_id"
const PARAM_CHARACTER: String = "character"
const PARAM_LEVEL: String = "level"
const PARAM_SCORE: String = "score"
const PARAM_ITEM_ID: String = "item_id"
const PARAM_ITEM_NAME: String = "item_name"
const PARAM_ITEM_CATEGORY: String = "item_category"
const PARAM_QUANTITY: String = "quantity"
const PARAM_PRICE: String = "price"
const PARAM_VALUE: String = "value"
const PARAM_CURRENCY: String = "currency"
const PARAM_VIRTUAL_CURRENCY_NAME: String = "virtual_currency_name"
const PARAM_SIGN_UP_METHOD: String = "sign_up_method"
const PARAM_GROUP_ID: String = "group_id"
const PARAM_SCREEN_NAME: String = "screen_name"
const PARAM_SEARCH_TERM: String = "search_term"

## Common user property names
const PROPERTY_SIGN_UP_METHOD: String = "sign_up_method"
