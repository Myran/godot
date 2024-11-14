extends Node

signal fb_inited
signal fb_login_success(token)
signal fb_login_cancelled
signal fb_login_failed(error)
signal fb_request_success(result)
signal fb_request_cancelled
signal fb_request_failed(error)
signal fb_logged_out

var _fb = null
var token = null
var user = null
const _APP_ID = 914537337160544


func _ready():
#	pause_mode = Node.PAUSE_MODE_PROCESS
	#if not ProjectSettings.has_setting('Facebook/FB_APP_ID'):
	#push_error('Facebook/FB_APP_ID not found! Set it in engine.cfg!')
	#return
	#var app_id = ProjectSettings.get_setting('Facebook/FB_APP_ID')
	var app_id = _APP_ID
	if Engine.has_singleton("GodotFacebook"):  # Android
		_fb = Engine.get_singleton("GodotFacebook")
		_fb.init(app_id)
		_fb.setFacebookCallbackId(get_instance_id())
		print("Facebook plugin Android inited")
		fb_inited.emit()

	elif Engine.has_singleton("Facebook"):  # iOS
		_fb = Engine.get_singleton("Facebook")
		_fb.init(app_id)
		_fb.setFacebookCallbackId(self)
		print("Facebook plugin iOS inited")
		fb_inited.emit()
	else:
		print("Facebook plugin not found!")


func login(permissions = null):
	if _fb != null:
		if permissions == null:
			#permissions = ["public_profile", 'email', 'user_friends']
			permissions = ["public_profile", "email"]
		_fb.login(permissions)
		return true
	else:
		return false


func game_request(message, recipients = "", objectId = ""):
	if _fb != null:
		_fb.gameRequest(message, recipients, objectId)


func game_requests(object, method):
	if _fb != null:
		if OS.get_name() == "iOS":
			_fb.callApi("/me/apprequests", {}, object, method)
		else:
			_fb.callApi("/me/apprequests", {}, object.get_instance_id(), method)


func logout():
	if _fb != null:
		_fb.logout()
		print("_fb logout sent")
		fb_logged_out.emit()


func is_logged_in():
	if _fb != null:
		return _fb.isLoggedIn()
	else:
		return false


func user_profile(object, method):
	if _fb != null:
		if OS.get_name() == "iOS":
			_fb.callApi("/me", {"fields": "id,name,first_name,last_name,picture"}, object, method)
		else:
			_fb.callApi(
				"/me",
				{"fields": "id,name,first_name,last_name,picture"},
				object.get_instance_id(),
				method
			)


func get_friends(object, method):
	if _fb != null:
		if OS.get_name() == "iOS":
			_fb.callApi(
				"/me/friends",
				{"fields": "name,first_name,last_name,picture", "limit": 3000},
				object,
				method
			)
		else:
			_fb.callApi(
				"/me/friends",
				{"fields": "name,first_name,last_name,picture", "limit": 3000},
				object.get_instance_id(),
				method
			)


func get_invitable_friends(object, method):
	if _fb != null:
		if OS.get_name() == "iOS":
			_fb.callApi(
				"/me/invitable_friends",
				{"fields": "first_name,last_name,picture", "limit": 3000},
				object,
				method
			)
		else:
			_fb.callApi(
				"/me/invitable_friends",
				{"fields": "first_name,last_name,picture", "limit": 3000},
				object.get_instance_id(),
				method
			)


# FB Analytics

"""

// Public event names

// General purpose
FBSDKAppEventNameCompletedRegistration   = fb_mobile_complete_registration
FBSDKAppEventNameViewedContent           = fb_mobile_content_view
FBSDKAppEventNameSearched                = fb_mobile_search
FBSDKAppEventNameRated                   = fb_mobile_rate
FBSDKAppEventNameCompletedTutorial       = fb_mobile_tutorial_completion
FBSDKAppEventNameContact                 = Contact
FBSDKAppEventNameCustomizeProduct        = CustomizeProduct
FBSDKAppEventNameDonate                  = Donate
FBSDKAppEventNameFindLocation            = FindLocation
FBSDKAppEventNameSchedule                = Schedule
FBSDKAppEventNameStartTrial              = StartTrial
FBSDKAppEventNameSubmitApplication       = SubmitApplication
FBSDKAppEventNameSubscribe               = Subscribe
FBSDKAppEventNameSubscriptionHeartbeat   = SubscriptionHeartbeat
FBSDKAppEventNameAdImpression            = AdImpression
FBSDKAppEventNameAdClick                 = AdClick

// Ecommerce related
FBSDKAppEventNameAddedToCart             = fb_mobile_add_to_cart
FBSDKAppEventNameAddedToWishlist         = fb_mobile_add_to_wishlist
FBSDKAppEventNameInitiatedCheckout       = fb_mobile_initiated_checkout
FBSDKAppEventNameAddedPaymentInfo        = fb_mobile_add_payment_info
FBSDKAppEventNameProductCatalogUpdate    = fb_mobile_catalog_update
FBSDKAppEventNamePurchased               = fb_mobile_purchase

// Gaming related
FBSDKAppEventNameAchievedLevel           = fb_mobile_level_achieved
FBSDKAppEventNameUnlockedAchievement     = fb_mobile_achievement_unlocked
FBSDKAppEventNameSpentCredits            = fb_mobile_spent_credits


// Public event parameter names

FBSDKAppEventParameterNameCurrency               = fb_currency
FBSDKAppEventParameterNameRegistrationMethod     = fb_registration_method
FBSDKAppEventParameterNameContentType            = fb_content_type
FBSDKAppEventParameterNameContent                = fb_content
FBSDKAppEventParameterNameContentID              = fb_content_id
FBSDKAppEventParameterNameSearchString           = fb_search_string
FBSDKAppEventParameterNameSuccess                = fb_success
FBSDKAppEventParameterNameMaxRatingValue         = fb_max_rating_value
FBSDKAppEventParameterNamePaymentInfoAvailable   = fb_payment_info_available
FBSDKAppEventParameterNameNumItems               = fb_num_items
FBSDKAppEventParameterNameLevel                  = fb_level
FBSDKAppEventParameterNameDescription            = fb_description
FBSDKAppEventParameterLaunchSource               = fb_mobile_launch_source
FBSDKAppEventParameterNameAdType                 = ad_type
FBSDKAppEventParameterNameOrderID                = fb_order_id
"""


func set_push_token(_token):
	if _fb != null:
		_fb.set_push_token(_token)


func log_event(event, value = 0, params = null):
	if _fb != null:
		if value != 0 and params != null:
			_fb.log_event_value_params(event, value, params)
		elif value != 0:
			_fb.log_event_value(event, value)
		elif params != null:
			_fb.log_event_params(event, params)
		else:
			_fb.log_event(event)


func log_purchase(price, currency = "USD", params = null):
	if _fb != null:
		if params != null:
			_fb.log_purchase_params(price, currency, params)
		else:
			_fb.log_purchase(price, currency)


func deep_link_uri():
	if _fb != null:
		return _fb.deep_link_uri()
	else:
		return null


func deep_link_ref():
	if _fb != null:
		return _fb.deep_link_ref()
	else:
		return null


func deep_link_promo():
	if _fb != null:
		return _fb.deep_link_promo()
	else:
		return null


func set_advertiser_tracking(enabled: bool) -> void:
	if _fb != null and OS.get_name() == "iOS":
		_fb.setAdvertiserTracking(enabled)


# FACEBOOK SDK CALLBACKS


func login_success(tkn):
	token = tkn
	print("Facebook login success: %s" % tkn)
	fb_login_success.emit(tkn)


func login_cancelled():
	token = null
	user = null
	print("Facebook login cancelled")
	fb_login_cancelled.emit()


func login_failed(error):
	token = null
	user = null
	print("Facebook login failed: %s" % error)
	fb_login_failed.emit(error)


func request_success(result):
	#print('Facebook request finished: %s'%var2str(result))
	fb_request_success.emit(result)


func request_cancelled():
	push_warning("Facebook request cancelled")
	fb_request_cancelled.emit()


func request_failed(err):
	push_error("Facebook request failed: %s" % var_to_str(err))
	fb_request_failed.emit(err)
