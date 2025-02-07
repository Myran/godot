extends Control

signal fb_success(res: Dictionary)
signal apple_success(res: Dictionary)

# const kBannerAdUnitAndroid: String = "ca-app-pub-3940256099942544/6300978111"
# const kInterstitialAdUnitAndroid: String = "ca-app-pub-3940256099942544/1033173712"
# const kBannerAdUnitIOS: String = "ca-app-pub-3940256099942544/2934735716"
# const kFakeBannerAdUnitIOS: String = "ca-app-pub-3940256099942544/2934735716"
const FAKE_INTERSTITIAL_AD_UNIT_IOS: String = "ca-app-pub-3940256099942544/4411468910"
# const kRealInterstitialAdUnitIOS: String = "ca-app-pub-8265399856187334~2529757314"
const FAKE_REWARDED_VIDEO_AD_UNIT_IOS: String = "ca-app-pub-3940256099942544/1712485313"
# const kRealAdappIdIOS: String = "ca-app-pub-8265399856187334~2529757314"

var admob: Object
var db: Object
var remote_config: Object
var messaging: Object
var count: int = 1
var godot_apple_auth: Object
var home_game: Node
var _auth: Object

@onready var status_label: RichTextLabel = %DebugRichTextLabel


func setup(init_args: Dictionary) -> void:
	print("setup with args", init_args)


func _ready() -> void:
	var debug_text: String
	if OS.is_debug_build():
		debug_text = "Build is debug"
	else:
		debug_text = "build is release"
	%DebugRichTextLabel2.text = str("OS: ", OS.get_name(), debug_text)
	%DebugRichTextLabel3.text = str("Commit: ", Engine.get_version_info()["hash"])

	if ClassDB.class_exists("FirebaseDatabase"):
		print("RealTime Database Singelton exists")
		db = ClassDB.instantiate("FirebaseDatabase")
		print("RealTime Database instance: ", db)
		db.connect("get_value", Callable(self, "get_value"), CONNECT_DEFERRED)
		db.connect("child_changed", Callable(self, "child_changed"), CONNECT_DEFERRED)
		db.connect("child_moved", Callable(self, "child_moved"), CONNECT_DEFERRED)
		db.connect("child_removed", Callable(self, "child_removed"), CONNECT_DEFERRED)
		db.connect("child_added", Callable(self, "child_added"), CONNECT_DEFERRED)
		db.set_db_root(["users"])

	if ClassDB.class_exists("FirebaseRemoteConfig"):
		print("Remote Config exists")
		remote_config = ClassDB.instantiate("FirebaseRemoteConfig")
		remote_config.connect("loaded", Callable(self, "remote_config_loaded"))

	if Engine.has_singleton("Facebook") or Engine.has_singleton("GodotFacebook"):
		print("facebook singleton exists")
	else:
		print("Facebook singleton does not exist")


func messaging_token() -> void:
	print("Messaging: token set")


func messaging_message() -> void:
	print("Messaging: message: ")


func _on_Button_remote_config_string_pressed() -> void:
	print("Button remote config string press")
	remote_config.set_instant_fetching()
	var rc_string: String = "local value"
	rc_string = remote_config.get_string("test_string")
	printt("Remote string:", rc_string)
	status_label.text = str("Remote config string: ", rc_string)


func remote_config_loaded() -> void:
	printt("Remote config loaded")


func _on_Button_update_pressed() -> void:
	printt("Button update pressed")
	db.update_children(["update"], {"key1": "value", "key2": "value"})


func _on_Button_delete_pressed() -> void:
	print("Button delete pressed")
	db.remove_value(["tom"])


func _on_Button_push_child_pressed() -> void:
	var key: String = "pushed"
	var pushString: String = db.push_child(["push", key])
	printt("Pushed string key:", key, "return string", pushString)
	db.set_value(["push", pushString], count)
	count = count + 1


func _on_Button_set_value_pressed() -> void:
	printt("Set value pressed")
	db.set_value(["tom"], str("Value", count))
	count = count + 1


func _on_Button_get_value_pressed() -> void:
	printt("Get_value pressed")
	db.get_value(["tom"])


func child_moved(key: String, value: Variant) -> void:
	printt("child moved", key, "value", value)


func child_added(key: String, value: Variant) -> void:
	printt("child added", key, "value", value)


func child_removed(key: String, value: Variant) -> void:
	printt("child removed", key, "value", value)


func child_changed(key: String, value: Variant) -> void:
	printt("Child changed:", "key:", key, "value", value)
	status_label.call_deferred("set_text", str("Value changed: ", key, "\n", "value: ", value))


func get_value(key: String, value: Variant) -> void:
	printt("key:", key, "Value:", value)
	status_label.text = str("Get_value for key: ", key, "\n", "Value: ", value)


func _on_Button_send_all_tracking_events_pressed() -> void:
	print("Tracking button pressed")
	if ClassDB.class_exists("FirebaseAnalytics"):
		print("FirebaseAnalytics exists")
		var a: Object = ClassDB.instantiate("FirebaseAnalytics")
		a.log_event("testlog_event")
		a.log_int("testlog_int", "int", 99)
		a.log_long("testlog_long", "long", 99)
		a.log_double("testlog_double", "double", 99)
		a.log_string("testlog_string", "string", "stringToLog")
		a.log_params("testlog_params", {"string": "start", "int": 99, "bool": true})
		a.user_property("has_test_property", "test_propery")
		a.user_id("0")
		a.screen_name("start_screen", "start_class")
		a.log_event("earn_virtual_currency")


func logged_in(res: String) -> void:
	print("_auth: DEBUG  Logged in: ", res)
	status_label.text = str("Auth: Logged in: ", res)


func _on_Button_sign_in_anon_pressed() -> void:
	print("button: sign in anon")
	var retval: int = await auth.login()
	print(str("login result: ", retval))
	status_label.call_deferred("set_text", str("login result: ", retval))


func facebook_login_success(res: Dictionary) -> void:
	fb_success.emit(res)


func _on_Button_sign_in_facebook_pressed() -> void:
	auth.sign_in_facebook()


func _on_Button_unlink_Facebook_pressed() -> void:
	auth.unlink_facebook()


func _on_Button_link_Facebook_pressed() -> void:
	auth.link_facebook()


func _on_Auth_Apple_login_pressed() -> void:
	print("button: apple login")
	if godot_apple_auth.is_available():
		print("apple auth is available")
		godot_apple_auth.sign_in()
		var result: Dictionary = await apple_success
		_auth.sign_in_apple(result.token, result.nonce)
		var auth_res: String = await _auth.logged_in()
		if auth_res == "":
			print("Firebase auth login success")
		else:
			print("Firebase auth login failed with error: ", auth_res)
	else:
		print("apple auth is not available")


func _on_Auth_Apple_log_out_pressed() -> void:
	print("button: apple log out")
	godot_apple_auth.sign_out()


func _on_Auth_Apple_link_pressed() -> void:
	print("button: link to Apple ")
	if !godot_apple_auth:
		print("apple auth does not exist")
		return
	godot_apple_auth.sign_in()
	var result: Dictionary = await apple_success
	print("apple login success")
	_auth.link_to_apple(result.token, result.nonce)
	var res: String = await _auth.account_linked
	if res == "":
		print("Apple account linked successfully")
	else:
		print("Apple account link unsuccessful error:", res)


func _on_Auth_Apple_unlink_pressed() -> void:
	print("Button: unlink apple")
	_auth.unlink_provider("apple.com")
	var res: String = await _auth.account_unlinked()
	if res == "":
		print("Apple account unlinked successfully")
	else:
		print("Apple account unlink unsuccessful error:", res)


func account_linked(_res: String) -> void:
	print("Account linked result:", _res)


func _on_Auth_Apple_has_provider_pressed() -> void:
	status_label.text = str("Auth: Is account connected to apple:", is_connected_to_apple())


func _on_Auth_fb_has_provider_pressed() -> void:
	status_label.text = str("Auth: Is account connected to facebook:", is_connected_to_facebook())


func _on_Button_sign_out_pressed() -> void:
	print("button: sign out")
	auth.log_out_facebook()


func _on_Button_get_all_info_pressed() -> void:
	print("button: show all info (Not implemented)")


func is_connected_to_facebook() -> bool:
	return check_provider_connection("facebook.com")


func is_connected_to_apple() -> bool:
	return check_provider_connection("apple.com")


func check_provider_connection(provider_name: String) -> bool:
	if _auth.is_logged_in():
		for provider : Dictionary in _auth.providers():
			if provider.name == provider_name:
				return true
	else:
		print("not logged in")
	return false


func _on_Button_close_pressed() -> void:
	visible = false


func _on_credential(result: Dictionary) -> void:
	if result.has("error"):
		print(result.error)
	else:
		print(result.state)


func _on_authorization(result: Dictionary) -> void:
	if result.has("error"):
		print(result.error)
		status_label.text = str(result.error)
	else:
		print("apple auth:")
		print("token: ", result.token)
		print("used_id: ", result.user_id)
		print("email ", result.email)
		print("name ", result.name)
		print("nonce ", result.nonce)
		status_label.text = str(
			"Apple auth:",
			"\n",
			"Name: ",
			result.name,
			"\n",
			"Mail:",
			result.email,
			"\n",
			"User_id:",
			result.user_id,
			"\n",
			"token: ",
			result.token,
			"\n",
			"nonce:",
			result.nonce
		)
		print("attempting to connect apple sign in to firebase")
		emit_signal("apple_success", result)


func _on_Button_func_is_interstitial_loaded_pressed() -> void:
	print("Return Value: is_interstitial_loaded:", admob.is_interstitial_loaded())
	status_label.text = str("Return Value: is_interstitial_loaded:", admob.is_interstitial_loaded())


func _on_Button_func_is_reward_loaded_pressed() -> void:
	status_label.text = str("Return Value: is_rewarded_loaded:", admob.is_rewarded_loaded())


func interstitial_loading_result(res: String) -> void:
	print("interstitial_loading_result", res)


func rewarded_completed() -> void:
	print("Rewarded completed")
	status_label.text = "Rewarded completed"


func rewarded_state(state: String) -> void:
	print("rewarded state changed:", state)


func interstitial_state(state: String) -> void:
	print("interstitial state changed:", state)


func _on_Button_load_interstitial_pressed() -> void:
	admob.load_interstitial(FAKE_INTERSTITIAL_AD_UNIT_IOS)


func _on_Button_play_interstitial_pressed() -> void:
	print("button play interstital pressed")
	admob.show_interstitial()


func _on_Button_load_rewarded_video_pressed() -> void:
	print("Button load rewarded video pressed")
	admob.load_rewarded(FAKE_REWARDED_VIDEO_AD_UNIT_IOS)


func _on_Button_play_rewarded_video_pressed() -> void:
	print("Button play rewarded video pressed")
	admob.show_rewarded()


func rewarded_loading_result(res: String) -> void:
	print("Rewarded loading result", res)
