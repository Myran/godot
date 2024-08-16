extends Node


var firebase_auth
var godot_apple_auth

signal fb_respons(res)
signal apple_auth_respons(res)
#signal cred_recieved (res)

var apple_aut_res = null


func uid():
	return firebase_auth.uid()

func is_available():
	return ClassDB.class_exists("FirebaseAuth")

func is_apple_available():
	return Engine.has_singleton("GodotAppleAuth")

func is_facebook_available():
	return Engine.has_singleton("Facebook") or Engine.has_singleton("GodotFacebook")

func is_connected_to_facebook():
	if is_facebook_available():
		if facebook.is_logged_in():
			return true
	return false

func is_connected_to_apple():
	return check_provider_connection("apple.com")


func is_apple_logged_in():
	await Engine.get_main_loop().process_frame
	
	
	if !auth.is_apple_available():
		return false
	godot_apple_auth.credential()
	if apple_aut_res == null:
		apple_aut_res = await godot_apple_auth.credential
	var respons = apple_aut_res
	apple_aut_res = null
	if respons.state == "authorized":
		return true
	return false

func check_provider_connection(provider_name):
	if !firebase_auth:
		return false
	if firebase_auth.is_logged_in():
		for provider in firebase_auth.providers():
			if provider.name==provider_name:
				return true
	else:
		print("Auth: checking provider connection however not logged in: ",provider_name)
	return false

func _ready():
	if ClassDB.class_exists("FirebaseAuth") and true:
		print("Auth exists data source")
#		firebase_auth = ClassDB.instance("FirebaseAuth")
		firebase_auth = ClassDB.instantiate("FirebaseAuth")
		print("Auth created")
		firebase_auth.connect("logged_in",self,"logged_in")
	else:
		print("FirebaseAuth datasource does NOT exist")

	if Engine.has_singleton("Facebook") or Engine.has_singleton("GodotFacebook"):
		print("facebook singleton exists")
		facebook.fb_login_success.connect(facebook_login_success)
		facebook.fb_login_failed.connect(facebook_login_failed)
		facebook.fb_login_cancelled.connect(facebook_login_cancelled)
		#facebook.connect("login_success",self,"facebook_login_success")
		#facebook.connect("login_failed",self,"facebook_login_failed")
		#facebook.connect("login_cancelled",self,"facebook_login_cancelled")
	else:
		print("Facebook singleton does not exist")

	if Engine.has_singleton("GodotAppleAuth"):
		print("Apple singleton exist")
		godot_apple_auth = Engine.get_singleton("GodotAppleAuth")
		godot_apple_auth.connect("credential", self, "_on_credential")
		godot_apple_auth.connect("authorization", self, "_on_authorization")
	else:
		print("Apple singleton does not exist")


func facebook_login_success(res):
	emit_signal("fb_respons",{"respons":"success","arg":res})

func facebook_login_failed(res):
	emit_signal("fb_respons",{"respons":"failed","arg":res})

func facebook_login_cancelled():
	emit_signal("fb_respons",{"respons":"cancelled","arg":null})


func sign_in_apple():
	print("Auth: Apple sign in to firebase")
	if !godot_apple_auth.is_available():
		push_error("Auth: Apple auth is not available")
		return -1
	print("Auth: attempt sign in Apple authorization")
	godot_apple_auth.sign_in()
	var result= await self.apple_auth_respons
	if result.has("error"):
		push_warning(str("Auth: Apple auth sign in failed / cancelled"))
		return -1

	print("Attempt sign in firebase authorization")
	firebase_auth.sign_in_apple(result.token,result.nonce)
	var auth_res = await firebase_auth.logged_in
	auth_res = int(auth_res)
	if auth_res == 0:
		print("AUTH: Firebase auth sign in success")
	else:
		print("Auth: Firebase auth sing in failed with error: ",auth_res)
	return auth_res


func sign_in_facebook():
	print("AUTH: sign in facebook")
	if !is_facebook_available():
		push_error("AUTH:facebook sign in attempted but facebook not available")
		return -1
	var login_resp = facebook.login()
	if !login_resp:
		push_warning("facebook.login() failed")
		return -1
	var res = await self.fb_respons
	if res.respons != "success":
		push_warning(str("Facebook login failed / cancelled",res))
		return -1
	print("AUTH: fb login result: ",res)
	firebase_auth.sign_in_facebook(res.arg)
	var auth_res = await firebase_auth.logged_in
	auth_res = int(auth_res)
	if auth_res == 0:
		print("AUTH: Firebase auth sign in success")
	else:
		print("AUTH: Firebase auth sign in failed with error: ",auth_res)
	return auth_res

func log_out_facebook():
	print("AUTH: Facebook log out")
	await Engine.get_main_loop().process_frame
	if !is_facebook_available():
		push_warning("AUTH: facebook not available")
		# inte bra men vad returna?
		return false
	facebook.logout()
	print("AUTH: facebook logout done")
	return facebook.is_logged_in()

func unlink_Facebook():
	print("Auth: unlink facebook")
	firebase_auth.unlink_provider("facebook.com")
	var res = await firebase_auth.account_unlinked
	if res == "":
		print("Auth: Facebook account unlinked successfully")
	else:
		print("Auth: Facebook account unlink unsuccessful error:",res)


func link_Facebook():
	print("Auth: link to facebook started")
	print("Auth: attempt fb login")
	var login_resp = facebook.login()
	if !login_resp:
		push_warning("Facebook.login() failed")
		return -1
	var res = await self.fb_respons
	if res.respons != "success":
		push_warning(str("Auth: Facebook login respons fail / cancelled res:",res))
		return -1
	print("Auth: facebook login success")
	#status_label.text = str("FB:",res)
	firebase_auth.link_to_facebook(res.arg)
	var link_res = await firebase_auth.account_linked
	if link_res == 0:
		print("Auth: Facebook account linked successfully")
	else:
		print("Auth: Facebook account link unsuccessful error:",link_res)
	return link_res


func log_out_apple():
	print("Apple log out start")
	if is_apple_available():
		godot_apple_auth.sign_out()
		print("Apple logout done")
	else:
		push_warning("AUTH: apple is not available")
	await Engine.get_main_loop().process_frame


func link_apple():
	print("button: link to Apple ")
	if !godot_apple_auth:
		print("apple auth does not exist")
		return
	godot_apple_auth.sign_in()
	var result= await self.apple_auth_respons
	if result.has("error"):
		push_warning(str("Auth: Apple auth sign error: ",result))
		return -1
	print("Auth: Apple auth sign in success")
	firebase_auth.link_to_apple(result.token,result.nonce)
	var res = await firebase_auth.account_linked
	if res == 0:
		print("Auth: Apple account linked successfully")
	else:
		print("Auth: Apple account link unsuccessful error:",res)
	return res


func unlink_apple():
	print("Button: unlink apple")
	firebase_auth.unlink_provider("apple.com")
	var res = await firebase_auth.account_unlinked
	if res == "":
		print("Apple account unlinked successfully")
	else:
		print("Apple account unlink unsuccessful error:",res)


func _on_credential(result: Dictionary):
	# "authorized" <- user ID is in good state
	# "not_found" <- user ID was not found
	# "revoked" <- user ID was revoked by the user
	apple_aut_res = result
	if result.has("error"):
		print(result.error)
	else:
		print("credential state: ", result.state)


func _on_authorization(result: Dictionary):
	if result.has("error"):
		print("Auth: apple authorization respons error: ",result.error)
		emit_signal("apple_auth_respons",result)
		#status_label.text= str(result.error)
	else:
		# Required
		print("apple auth:")
		print("token: ",result.token)
		print("used_id: ",result.user_id)
		# Optional (can be empty)
		print("email ",result.email)
		print("name ",result.name)
		print("nonce ",result.nonce)
		#status_label.text= str("Apple auth:","\n","Name: ",result.name,"\n","Mail:",result.email,"\n","User_id:",result.user_id,"\n","token: ",result.token,"\n","nonce:",result.nonce)
		print("Auth: apple authorization respons OK")
		emit_signal("apple_auth_respons",result)



func apple_credential():
	godot_apple_auth.credential()


func logged_in(res):
	print("Auth: Logged in: ", res)


func login():
	var retval = 0
	print("Auth: attempt login")
	await Engine.get_main_loop().process_frame
	if !is_available():
		push_warning("Auth: Auth not available")
		retval = 1
		return retval
	if !firebase_auth.is_logged_in():
		firebase_auth.sign_in_anonymously()
		retval = await firebase_auth.logged_in
		print("Auth: Firebase login done: ",retval)

	else:
		print("Auth: Already logged in")
	if retval == 0:
		print("Auth uid:",firebase_auth.uid())
	return retval
