extends Node

signal fb_respons(res: Dictionary)
signal apple_auth_respons(res: Dictionary)

var firebase_auth: Object
var godot_apple_auth: Object
var apple_aut_res: Dictionary = {}

func uid() -> String:
	return firebase_auth.uid()


func is_available() -> bool:
	return ClassDB.class_exists("FirebaseAuth")


func is_apple_available() -> bool:
	return Engine.has_singleton("GodotAppleAuth")


func is_facebook_available() -> bool:
	return Engine.has_singleton("Facebook") or Engine.has_singleton("GodotFacebook")


func is_connected_to_facebook() -> bool:
	if is_facebook_available():
		if facebook.is_logged_in():
			return true
	return false


func is_connected_to_apple() -> bool:
	return check_provider_connection("apple.com")


func is_apple_logged_in() -> bool:
	await Engine.get_main_loop().process_frame
	if !auth.is_apple_available():
		return false
	godot_apple_auth.credential()
	if apple_aut_res.is_empty():
		apple_aut_res = await godot_apple_auth.credential
	var respons: Dictionary = apple_aut_res
	apple_aut_res = {}
	return respons.get("state", "") == "authorized"


func check_provider_connection(provider_name: String) -> bool:
	if !firebase_auth:
		return false
	if firebase_auth.is_logged_in():
		for provider : Dictionary in firebase_auth.providers():
			if provider.name == provider_name:
				return true
	else:
		print("Auth: checking provider connection however not logged in: ", provider_name)
	return false


func _ready() -> void:
	if ClassDB.class_exists("FirebaseAuth") and true:
		print("Auth exists data source")
		firebase_auth = ClassDB.instantiate("FirebaseAuth")
		print("Firebase Auth created")
		firebase_auth.connect("logged_in", Callable(self, "logged_in"))
	
	if Engine.has_singleton("Facebook") or Engine.has_singleton("GodotFacebook"):
		print("facebook singleton exists")
		facebook.connect("fb_login_success", Callable(self, "facebook_login_success"))
		facebook.connect("fb_login_failed", Callable(self, "facebook_login_failed"))
		facebook.connect("fb_login_cancelled", Callable(self, "facebook_login_cancelled"))
	
	if Engine.has_singleton("GodotAppleAuth"):
		print("Apple singleton exist")
		godot_apple_auth = Engine.get_singleton("GodotAppleAuth")
		godot_apple_auth.connect("credential", Callable(self, "_on_credential"))
		godot_apple_auth.connect("authorization", Callable(self, "_on_authorization"))


func facebook_login_success(res: String) -> void:
	emit_signal("fb_respons", {"respons": "success", "arg": res})


func facebook_login_failed(res: String) -> void:
	emit_signal("fb_respons", {"respons": "failed", "arg": res})


func facebook_login_cancelled() -> void:
	emit_signal("fb_respons", {"respons": "cancelled", "arg": null})


func sign_in_apple() -> int:
	print("Auth: Apple sign in to firebase")
	if !godot_apple_auth.is_available():
		push_error("Auth: Apple auth is not available")
		return -1
	
	godot_apple_auth.sign_in()
	var result: Dictionary = await self.apple_auth_respons
	if result.has("error"):
		push_warning(str("Auth: Apple auth sign in failed / cancelled"))
		return -1

	firebase_auth.sign_in_apple(result.token, result.nonce)
	var auth_res: int = await firebase_auth.logged_in
	return auth_res


func sign_in_facebook() -> int:
	print("AUTH: sign in facebook")
	if !is_facebook_available():
		push_error("AUTH:facebook sign in attempted but facebook not available")
		return -1
	
	var login_resp: bool = facebook.login()
	if !login_resp:
		push_warning("facebook.login() failed")
		return -1
	
	var res: Dictionary = await self.fb_respons
	if res.respons != "success":
		push_warning(str("Facebook login failed / cancelled", res))
		return -1
	
	firebase_auth.sign_in_facebook(res.arg)
	var auth_res: int = await firebase_auth.logged_in
	return auth_res


func log_out_facebook() -> bool:
	print("AUTH: Facebook log out")
	await Engine.get_main_loop().process_frame
	if !is_facebook_available():
		push_warning("AUTH: facebook not available")
		return false
	
	facebook.logout()
	return !facebook.is_logged_in()


func unlink_facebook() -> void:
	print("Auth: unlink facebook")
	firebase_auth.unlink_provider("facebook.com")
	var _res: String = await firebase_auth.account_unlinked


func link_facebook() -> int:
	print("Auth: link to facebook started")
	var login_resp: bool = facebook.login()
	if !login_resp:
		push_warning("Facebook.login() failed")
		return -1
	
	var res: Dictionary = await self.fb_respons
	if res.respons != "success":
		push_warning(str("Auth: Facebook login respons fail / cancelled res:", res))
		return -1
	
	firebase_auth.link_to_facebook(res.arg)
	var link_res: int = await firebase_auth.account_linked
	return link_res


func log_out_apple() -> void:
	print("Apple log out start")
	if is_apple_available():
		godot_apple_auth.sign_out()
	await Engine.get_main_loop().process_frame


func link_apple() -> int:
	print("button: link to Apple ")
	if !godot_apple_auth:
		return -1
	
	godot_apple_auth.sign_in()
	var result: Dictionary = await self.apple_auth_respons
	if result.has("error"):
		return -1
	
	firebase_auth.link_to_apple(result.token, result.nonce)
	var res: int = await firebase_auth.account_linked
	return res


func unlink_apple() -> void:
	print("Button: unlink apple")
	firebase_auth.unlink_provider("apple.com")
	var _res: String = await firebase_auth.account_unlinked


func _on_credential(result: Dictionary) -> void:
	apple_aut_res = result
	if result.has("error"):
		print(result.error)


func _on_authorization(result: Dictionary) -> void:
	if result.has("error"):
		emit_signal("apple_auth_respons", result)
	else:
		emit_signal("apple_auth_respons", result)


func apple_credential() -> void:
	godot_apple_auth.credential()


func logged_in(res: int) -> void:
	print("Auth: Logged in: ", res)


func login() -> int:
	var retval: int = 0
	print("Auth: attempt login")
	await Engine.get_main_loop().process_frame
	
	if !is_available():
		push_warning("Auth: Auth not available")
		return 1
	
	if !firebase_auth.is_logged_in():
		firebase_auth.sign_in_anonymously()
		retval = await firebase_auth.logged_in
	
	return retval
