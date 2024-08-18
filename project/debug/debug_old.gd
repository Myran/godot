extends Control
signal fb_success(res)
signal apple_success(res)

const kBannerAdUnitAndroid = "ca-app-pub-3940256099942544/6300978111"
const kInterstitialAdUnitAndroid = "ca-app-pub-3940256099942544/1033173712"
const kBannerAdUnitIOS = "ca-app-pub-3940256099942544/2934735716"
const kFakeBannerAdUnitIOS = "ca-app-pub-3940256099942544/2934735716"
const kFakeInterstitialAdUnitIOS = "ca-app-pub-3940256099942544/4411468910"
const kRealInterstitialAdUnitIOS = "ca-app-pub-8265399856187334~2529757314"
const kFakeRewaredVideoAdUnitIOS = "ca-app-pub-3940256099942544/1712485313"
const kRealAdappIdIOS = "ca-app-pub-8265399856187334~2529757314"
var admob
var _auth
var db
var remote_config
var messaging
var count = 1
var godot_apple_auth
var home_game
@onready var status_label = %DebugRichTextLabel

func setup(init_args):
	print("setup with args",init_args)
func _ready():

	var debug_text
	if OS.is_debug_build():
		debug_text = "Build is debug"
	else:
		debug_text = "build is release"
	%DebugRichTextLabel2.text = str("OS: ",OS.get_name(),debug_text)
	%DebugRichTextLabel3.text = str("Commit: ",Engine.get_version_info()["hash"])



#	if ClassDB.class_exists("FirebaseAdmob"):
#		print("admob exists")
#		admob = ClassDB.instance("FirebaseAdmob")
#		admob.connect("interstitial_loading_result",self,"interstitial_loading_result")
#		admob.connect("interstitial_state",self,"interstitial_state")
#		admob.connect("rewarded_loading_result",self,"rewarded_loading_result")
#		admob.connect("rewarded_state",self,"rewarded_state")
#		admob.connect("rewarded_completed",self,"rewarded_completed")
#		admob.add_test_device("96702da077e2ee1afe72de96a03b6b48")
#		admob.init(kRealAdappIdIOS)
#		#Not working auto layout problem. Problably other
#		#admob.connect("banner_loading_result",self,"banner_loading_result")
#		#admob.load_banner(kFakeBannerAdUnitIOS)
#

#	if ClassDB.class_exists("FirebaseAuth") and true:
#		print("Auth exists debug")
#		_auth = ClassDB.instance("FirebaseAuth")
#		_auth.connect("logged_in",self,"logged_in")
#		_auth.connect("account_linked",self,"account_linked")
#
	if ClassDB.class_exists("FirebaseDatabase"):
		print("RealTime Database Singelton exists")
		db = ClassDB.instantiate("FirebaseDatabase")
		print("RealTime Database instance: ",db)
		#db.get_value.connect(self,get_value)
		db.connect("get_value",Callable(self,"get_value"))
		db.connect("child_changed",Callable(self,"child_changed"))
		db.connect("child_moved",Callable(self,"child_moved"))
		db.connect("child_removed",Callable(self,"child_removed"))
		db.connect("child_added",Callable(self,"child_added"))
		#db.connect("child_changed",self,"child_changed")
		#db.connect("child_moved",self,"child_moved")
		#db.connect("child_removed",self,"child_removed")
		#db.connect("child_added",self,"child_added")
		db.set_db_root(["users"])
#
	if ClassDB.class_exists("FirebaseRemoteConfig"):
		print("Remote Config exists")
		remote_config = ClassDB.instantiate("FirebaseRemoteConfig")
		#remote_config.loaded(remote_config_loaded)
		remote_config.connect("loaded",Callable(self,"remote_config_loaded"))
#
	if ClassDB.class_exists("FirebaseMessaging"):
		print("Messaging exists")
		messaging = ClassDB.instantiate("FirebaseMessaging")
		messaging.connect("token",Callable(self,"messaging_token"))
		messaging.connect("message",Callable(self,"messaging_message"))
#
#	if Engine.has_singleton("Facebook") or Engine.has_singleton("GodotFacebook"):
#		print("facebook singleton exists")
#		var _ret = facebook.connect("login_success",self,"facebook_login_success")
#	else:
#		print("Facebook singleton does not exist")
#
#	if Engine.has_singleton("GodotAppleAuth"):
#		print("Apple singleton exist")
#		godot_apple_auth = Engine.get_singleton("GodotAppleAuth")
#		godot_apple_auth.connect("credential", self, "_on_credential")
#		godot_apple_auth.connect("authorization", self, "_on_authorization")
#	else:
#		print("Apple singleton does not exist")

func messaging_token():
	print("Messaging: token set")
func messaging_message():
	print("Messaging: message: ")

func _on_Button_remote_config_string_pressed():
	print("Button remote config string press")
	remote_config.set_instant_fetching()
	var rc_string = "local value"
	rc_string = remote_config.get_string("test_string")
	printt("Remote string:",rc_string)
	status_label.text = str("Remote config string: ",rc_string)

func remote_config_loaded():
	printt("Remote config loaded")

func _on_Button_update_pressed():
	printt("Button update pressed")
	db.update_children(["update"],{"key1":"value","key2":"value"})

func _on_Button_delete_pressed():
	print("Button delete pressed")
	db.remove_value(["tom"])

func _on_Button_push_child_pressed():
	var key = "pushed"
	var pushString = db.push_child(["push",key])
	printt("Pushed string key:",key,"return string",pushString)
	db.set_value(["push",pushString],count)
	count = count + 1

func _on_Button_set_value_pressed():
	printt("Set value pressed")
	db.set_value(["tom"],str("Value",count))
	count = count + 1
func _on_Button_get_value_pressed():
	printt("Get_value pressed")
	var retval = db.get_value(["tom"])
	status_label.text = str("RTDB: Get Value: ",retval)

func child_moved(key,value):
	printt("child moved",key,"value",value)

func child_added(key,value):
	printt("child added",key,"value",value)

func child_removed(key,value):
	printt("child removed",key,"value",value)

func child_changed(key,value):
	printt("Child changed:","key:",key,"value",value)
	status_label.text = str("Value changed: ",key,"\n","value: ",value)

func get_value(key,value):
	printt("key:",key,"Value:",value)
	status_label.text = str("Get_value for key: ",key,"\n","Value: ",value)


func _on_Button_send_all_tracking_events_pressed():
	print("Tracking button pressed")
	if ClassDB.class_exists("FirebaseAnalytics"):
		print("FirebaseAnalytics exists")
		var a = ClassDB.instantiate("FirebaseAnalytics")
		a.log_event("testlog_event")
		a.log_int("testlog_int","int",99)
		a.log_long("testlog_long","long",99)
		a.log_double("testlog_double","double",99)
		a.log_string("testlog_string","string","stringToLog")
		#log_param dont work
		a.log_params("testlog_params",{"string":"start","int":99,"bool":true})
		a.user_property("has_test_property","test_propery")
		a.user_id("0")
		a.screen_name("start_screen","start_class")
		a.log_event("earn_virtual_currency")


func logged_in(res):
	print("_auth: DEBUG  Logged in: ",res)
	status_label.text = str("Auth: Logged in: ",res)

func _on_Button_sign_in_anon_pressed():
	print("button: sign in anon")
	var retval = await auth.login()
	print("login result:",retval)
	%DebugRichTextLabel.text = str("login result: ",retval)
	#_auth.sign_in_anonymously()
	#var auth_res = await _auth.logged_in()
	#if auth_res =="":
		#print("Firebase auth login success")
	#else:
		#print("Firebase auth login failed with error: ",auth_res)


func facebook_login_success(res):
	emit_signal("fb_success",res)

func _on_Button_sign_in_facebook_pressed():
	print("button: sign in facebook")
	facebook.login()
	var res = await fb_success
	print("fb login success")
	status_label.text = str("FB:",res)
	_auth.sign_in_facebook(res)
	var auth_res = await _auth.logged_in()
	if auth_res =="":
		print("Firebase auth login success")
	else:
		print("Firebase auth login failed with error: ",auth_res)

func _on_Button_unlink_Facebook_pressed():
	print("Button: unlink facebook")
	_auth.unlink_provider("facebook.com")
	var res = await auth.account_unlinked()
	if res == "":
		print("Facebook account unlinked successfully")
	else:
		print("Facebook account unlink unsuccessful error:",res)

func _on_Button_link_Facebook_pressed():
	print("button: link to facebook")
	facebook.login()
	var res = await fb_success
	print("fb login success")
	status_label.text = str("FB:",res)
	_auth.link_to_facebook(res)
	var link_res = await auth.account_linked()
	if link_res == "":
		print("Facebook account linked successfully")
	else:
		print("Facebook account link unsuccessful error:",res)


func _on_Auth_Apple_login_pressed():
	print("button: apple login")
	if godot_apple_auth.is_available():
		print("apple auth is available")
		godot_apple_auth.sign_in()
		var result= await apple_success
		_auth.sign_in_apple(result.token,result.nonce)
		var auth_res = await _auth.logged_in()
		if auth_res =="":
			print("Firebase auth login success")
		else:
			print("Firebase auth login failed with error: ",auth_res)
	else:
		print("apple auth is not available")


func _on_Auth_Apple_log_out_pressed():
	print("button: apple log out")
	godot_apple_auth.sign_out()

func _on_Auth_Apple_link_pressed():
	print("button: link to Apple ")
	if !godot_apple_auth:
		print("apple auth does not exist")
		return
	godot_apple_auth.sign_in()
	var result= await apple_success
	print("apple login success")
	_auth.link_to_apple(result.token,result.nonce)
	var res = await _auth.account_linked
	if res == "":
		print("Apple account linked successfully")
	else:
		print("Apple account link unsuccessful error:",res)

func _on_Auth_Apple_unlink_pressed():
	print("Button: unlink apple")
	_auth.unlink_provider("apple.com")
	var res = await _auth.account_unlinked()
	if res == "":
		print("Apple account unlinked successfully")
	else:
		print("Apple account unlink unsuccessful error:",res)


func account_linked(_res):
	print("Account linked result:",_res)
	pass

func _on_Auth_Apple_has_provider_pressed():
	status_label.text= str("Auth: Is account connected to apple:", is_connected_to_apple())
func _on_Auth_fb_has_provider_pressed():
	status_label.text= str("Auth: Is account connected to facebook:", is_connected_to_facebook())
func _on_Button_sign_out_pressed():
	print("button: sign out")
	_auth.sign_out()

func _on_Button_get_all_info_pressed():
	print("button: show all info")
	%DebugRichTextLabel.text = str("Name: ",auth.user_name(),"\n","Email: ",auth.email(),"\n","uid: ",auth.uid(),"\n") #,"photourl: ",auth.avatar_url())
	print("providers: ", _auth.providers())
func is_connected_to_facebook():
	return check_provider_connection("facebook.com")
func is_connected_to_apple():
	return check_provider_connection("apple.com")
func check_provider_connection(provider_name):
	if _auth.is_logged_in():
		for provider in _auth.providers():
			if provider.name==provider_name:
				return true
	else:
		print("not logged in")
	return false
#func _on_Button_is_logged_in_pressed():
	#print("button: is_logged_in")
	#status_label.text= str("_auth: Is logged in?",_auth.is_logged_in())
func _on_Button_close_pressed():
	visible = false

func _on_credential(result: Dictionary):
	# "authorized" <- user ID is in good state
	# "not_found" <- user ID was not found
	# "revoked" <- user ID was revoked by the user
	if result.has("error"):
		print(result.error)
	else:
		print(result.state)
func _on_authorization(result: Dictionary):
	if result.has("error"):
		print(result.error)
		status_label.text= str(result.error)
	else:
		# Required
		print("apple auth:")
		print("token: ",result.token)
		print("used_id: ",result.user_id)
		# Optional (can be empty)
		print("email ",result.email)
		print("name ",result.name)
		print("nonce ",result.nonce)
		status_label.text= str("Apple auth:","\n","Name: ",result.name,"\n","Mail:",result.email,"\n","User_id:",result.user_id,"\n","token: ",result.token,"\n","nonce:",result.nonce)
		print("attempting to connect apple sign in to firebase")
		emit_signal("apple_success",result)

#func _on_Button_summator_test_pressed():
	#var s = Summator.new()
	#s.connect("result",self,"result")
	#s.add(10)
	#s.add(100)
	#print(s.get_total())
	#status_label.text = str("summator:",s.get_total())
	#s.reset()
	#print("summator total:",s.get_total())
#func result():
	#print("summator result signal")

func _on_Button_func_is_interstitial_loaded_pressed():
	print("Return Value: is_interstitial_loaded:",admob.is_interstitial_loaded())
	status_label.text = str("Return Value: is_interstitial_loaded:",admob.is_interstitial_loaded())

func _on_Button_func_is_reward_loaded_pressed():
	status_label.text = str("Return Value: is_rewarded_loaded:",admob.is_rewarded_loaded())

func interstitial_loading_result(res):
	print("interstitial_loading_result",res)

func rewarded_completed():
	print("Rewarded completed")
	status_label.text = "Rewarded completed"
func rewarded_state(state):
	print("rewarded state changed:",state)

func interstitial_state(state):
	print("interstitial state changed:",state)

func _on_Button_load_interstitial_pressed():
	admob.load_interstitial(kFakeInterstitialAdUnitIOS)

func _on_Button_play_interstitial_pressed():
	print("button play interstital pressed")
	admob.show_interstitial()

func _on_Button_load_rewarded_video_pressed():
	print("Button load rewarded video pressed")
	admob.load_rewarded(kFakeRewaredVideoAdUnitIOS)

func _on_Button_play_rewarded_video_pressed():
	print("Button play rewarded video pressed")
	admob.show_rewarded()
func rewarded_loading_result(res):
	print("Rewarded loading result",res)
