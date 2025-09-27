extends Node

signal fb_inited
signal fb_login_success(token: String)
signal fb_login_cancelled
signal fb_login_failed(error: String)
signal fb_request_success(result: Dictionary)
signal fb_request_cancelled
signal fb_request_failed(error: String)
signal fb_logged_out

const _APP_ID: int = 914537337160544

var _fb: Object = null
var _token: String = ""
var _user: Dictionary = {}


func _ready() -> void:
	if Engine.has_singleton("GodotFacebook"):  # Android
		_fb = Engine.get_singleton("GodotFacebook")
		_fb.init(_APP_ID)
		_fb.setFacebookCallbackId(get_instance_id())
		Log.info("Facebook plugin Android inited", {}, [Log.TAG_FACEBOOK, Log.TAG_INITIALIZATION])
		fb_inited.emit()
	elif Engine.has_singleton("Facebook"):  # iOS
		_fb = Engine.get_singleton("Facebook")
		_fb.init(_APP_ID)
		_fb.setFacebookCallbackId(self)
		Log.info("Facebook plugin iOS inited", {}, [Log.TAG_FACEBOOK, Log.TAG_INITIALIZATION])
		fb_inited.emit()
	else:
		Log.warning("Facebook plugin not found!", {}, [Log.TAG_FACEBOOK, Log.TAG_ERROR])


func login(permissions: Array[String] = ["public_profile", "email"]) -> bool:
	if _fb != null:
		_fb.login(permissions)
		return true
	return false


func game_request(message: String, recipients: String = "", object_id: String = "") -> void:
	if _fb != null:
		_fb.gameRequest(message, recipients, object_id)


func game_requests(object: Object, method: String) -> void:
	if _fb != null:
		if OS.get_name() == "iOS":
			_fb.callApi("/me/apprequests", {}, object, method)
		else:
			_fb.callApi("/me/apprequests", {}, object.get_instance_id(), method)


func logout() -> void:
	if _fb != null:
		_fb.logout()
		Log.info("Facebook logout sent", {}, [Log.TAG_FACEBOOK, Log.TAG_AUTH])
		fb_logged_out.emit()


func is_logged_in() -> bool:
	return _fb != null && _fb.isLoggedIn()


func user_profile(object: Object, method: String) -> void:
	if _fb != null:
		var fields: Dictionary = {"fields": "id,name,first_name,last_name,picture"}
		if OS.get_name() == "iOS":
			_fb.callApi("/me", fields, object, method)
		else:
			_fb.callApi("/me", fields, object.get_instance_id(), method)


func get_friends(object: Object, method: String) -> void:
	if _fb != null:
		var params: Dictionary = {"fields": "name,first_name,last_name,picture", "limit": 3000}
		if OS.get_name() == "iOS":
			_fb.callApi("/me/friends", params, object, method)
		else:
			_fb.callApi("/me/friends", params, object.get_instance_id(), method)


func get_invitable_friends(object: Object, method: String) -> void:
	if _fb != null:
		var params: Dictionary = {"fields": "first_name,last_name,picture", "limit": 3000}
		if OS.get_name() == "iOS":
			_fb.callApi("/me/invitable_friends", params, object, method)
		else:
			_fb.callApi("/me/invitable_friends", params, object.get_instance_id(), method)


func set_push_token(push_token: String) -> void:
	if _fb != null:
		_fb.set_push_token(push_token)


func log_event(event: String, value: float = 0.0, params: Dictionary = {}) -> void:
	if _fb != null:
		if value != 0.0 && !params.is_empty():
			_fb.log_event_value_params(event, value, params)
		elif value != 0.0:
			_fb.log_event_value(event, value)
		elif !params.is_empty():
			_fb.log_event_params(event, params)
		else:
			_fb.log_event(event)


func log_purchase(price: float, currency: String = "USD", params: Dictionary = {}) -> void:
	if _fb != null:
		if !params.is_empty():
			_fb.log_purchase_params(price, currency, params)
		else:
			_fb.log_purchase(price, currency)


func deep_link_uri() -> String:
	return _fb.deep_link_uri() if _fb != null else ""


func deep_link_ref() -> String:
	return _fb.deep_link_ref() if _fb != null else ""


func deep_link_promo() -> String:
	return _fb.deep_link_promo() if _fb != null else ""


func set_advertiser_tracking(enabled: bool) -> void:
	if _fb != null && OS.get_name() == "iOS":
		_fb.setAdvertiserTracking(enabled)


func login_success(tkn: String) -> void:
	_token = tkn
	Log.info(
		"Facebook login success",
		{"token_length": tkn.length()},
		[Log.TAG_FACEBOOK, Log.TAG_AUTH_LOGIN]
	)
	fb_login_success.emit(tkn)


func login_cancelled() -> void:
	_token = ""
	_user = {}
	Log.info("Facebook login cancelled", {}, [Log.TAG_FACEBOOK, Log.TAG_AUTH])
	fb_login_cancelled.emit()


func login_failed(error: String) -> void:
	_token = ""
	_user = {}
	Log.error(
		"Facebook login failed", {"error": error}, [Log.TAG_FACEBOOK, Log.TAG_AUTH, Log.TAG_ERROR]
	)
	fb_login_failed.emit(error)


func request_success(result: Dictionary) -> void:
	fb_request_success.emit(result)


func request_cancelled() -> void:
	Log.warning("Facebook request cancelled", {}, [Log.TAG_NETWORK])
	fb_request_cancelled.emit()


func request_failed(err: String) -> void:
	Log.error("Facebook request failed", {"error": err}, [Log.TAG_NETWORK, Log.TAG_ERROR])
	fb_request_failed.emit(err)
