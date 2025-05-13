extends Node

signal fb_respons(res: Dictionary)
signal apple_auth_respons(res: Dictionary)

# We can't use FirebaseAuth type directly as it's not defined in the current scope
# Using Object with clear naming convention to maintain type safety
var firebase_auth: Object  # FirebaseAuth instance
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
	@warning_ignore("redundant_await")
	await Engine.get_main_loop().process_frame
	if !auth.is_apple_available():
		return false
	godot_apple_auth.credential()
	if apple_aut_res.is_empty():
		@warning_ignore("redundant_await")
		apple_aut_res = await godot_apple_auth.credential
	var respons: Dictionary = apple_aut_res
	apple_aut_res = {}
	return respons.get("state", "") == "authorized"


func check_provider_connection(provider_name: String) -> bool:
	if !firebase_auth:
		return false
	if firebase_auth.is_logged_in():
		for provider: Dictionary in firebase_auth.providers():
			if provider.has("name") and provider.name == provider_name:
				return true
	else:
		Log.warning(
			"Checking provider connection but not logged in",
			{"provider": provider_name},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth", "validation"]
		)
	return false


func _ready() -> void:
	if ClassDB.class_exists("FirebaseAuth") and true:
		Log.info("Firebase Auth module available", {}, [Log.TAG_FIREBASE, "initialization", "auth"])
		firebase_auth = ClassDB.instantiate("FirebaseAuth")
		Log.debug(
			"Firebase Auth instance created", {}, [Log.TAG_FIREBASE, "initialization", "auth"]
		)
		firebase_auth.connect("logged_in", Callable(self, "logged_in"))

	if Engine.has_singleton("Facebook") or Engine.has_singleton("GodotFacebook"):
		Log.info(
			"Facebook SDK available", {}, [Log.TAG_FIREBASE, "initialization", "auth", "facebook"]
		)
		facebook.connect("fb_login_success", Callable(self, "facebook_login_success"))
		facebook.connect("fb_login_failed", Callable(self, "facebook_login_failed"))
		facebook.connect("fb_login_cancelled", Callable(self, "facebook_login_cancelled"))

	if Engine.has_singleton("GodotAppleAuth"):
		Log.info(
			"Apple Auth module available", {}, [Log.TAG_FIREBASE, "initialization", "auth", "apple"]
		)
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
	Log.info("Starting Apple sign-in flow", {}, [Log.TAG_FIREBASE, "auth", "apple"])
	if !godot_apple_auth.is_available():
		Log.error(
			"Apple auth is not available",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth", "apple", "validation"]
		)
		return -1

	godot_apple_auth.sign_in()
	@warning_ignore("redundant_await")
	var result: Dictionary = await self.apple_auth_respons
	if result.has("error"):
		Log.warning(
			"Apple auth sign in failed or cancelled",
			{"error": result.has("error")},
			[Log.TAG_FIREBASE, "auth", "apple"]
		)
		return -1

	firebase_auth.sign_in_apple(result.token, result.nonce)
	@warning_ignore("redundant_await")
	var auth_res: int = await firebase_auth.logged_in
	return auth_res


func sign_in_facebook() -> int:
	Log.info("Starting Facebook sign-in flow", {}, [Log.TAG_FIREBASE, "auth", "facebook"])
	if !is_facebook_available():
		Log.error(
			"Facebook sign in attempted but Facebook SDK not available",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth", "facebook", "validation"]
		)
		return -1

	var login_resp: bool = facebook.login()
	if !login_resp:
		Log.warning(
			"Facebook login API call failed",
			{},
			[Log.TAG_FIREBASE, "auth", "facebook", Log.TAG_NETWORK]
		)
		return -1

	@warning_ignore("redundant_await")
	var res: Dictionary = await self.fb_respons
	if res.has("respons") and res.respons != "success":
		Log.warning(
			"Facebook login failed or cancelled",
			{"response": res},
			[Log.TAG_FIREBASE, "auth", "facebook"]
		)
		return -1

	firebase_auth.sign_in_facebook(res.arg)
	@warning_ignore("redundant_await")
	var auth_res: int = await firebase_auth.logged_in
	return auth_res


func log_out_facebook() -> bool:
	Log.info("Facebook logout requested", {}, [Log.TAG_FIREBASE, "auth", "facebook"])
	@warning_ignore("redundant_await")
	await Engine.get_main_loop().process_frame
	if !is_facebook_available():
		Log.warning(
			"Facebook logout requested but Facebook SDK not available",
			{},
			[Log.TAG_FIREBASE, "auth", "facebook", "validation"]
		)
		return false

	facebook.logout()
	return !facebook.is_logged_in()


func unlink_facebook() -> void:
	Log.info("Unlinking Facebook provider", {}, [Log.TAG_FIREBASE, "auth", "facebook"])
	firebase_auth.unlink_provider("facebook.com")
	@warning_ignore("redundant_await")
	var _res: String = await firebase_auth.account_unlinked


func link_facebook() -> int:
	Log.info("Starting Facebook account linking", {}, [Log.TAG_FIREBASE, "auth", "facebook"])
	var login_resp: bool = facebook.login()
	if !login_resp:
		Log.warning(
			"Facebook login API call failed during account linking",
			{},
			[Log.TAG_FIREBASE, "auth", "facebook", Log.TAG_NETWORK]
		)
		return -1

	@warning_ignore("redundant_await")
	var res: Dictionary = await self.fb_respons
	if res.has("respons") and res.respons != "success":
		Log.warning(
			"Facebook login failed or cancelled during account linking",
			{"response": res},
			[Log.TAG_FIREBASE, "auth", "facebook"]
		)
		return -1

	firebase_auth.link_to_facebook(res.arg)
	@warning_ignore("redundant_await")
	var link_res: int = await firebase_auth.account_linked
	return link_res


func log_out_apple() -> void:
	Log.info("Apple logout requested", {}, [Log.TAG_FIREBASE, "auth", "apple"])
	if is_apple_available():
		godot_apple_auth.sign_out()
	@warning_ignore("redundant_await")
	await Engine.get_main_loop().process_frame


func link_apple() -> int:
	Log.info("Starting Apple account linking", {}, [Log.TAG_FIREBASE, "auth", "apple"])
	if !godot_apple_auth:
		return -1

	godot_apple_auth.sign_in()
	@warning_ignore("redundant_await")
	var result: Dictionary = await self.apple_auth_respons
	if result.has("error"):
		return -1

	firebase_auth.link_to_apple(result.token, result.nonce)
	@warning_ignore("redundant_await")
	var res: int = await firebase_auth.account_linked
	return res


func unlink_apple() -> void:
	Log.info("Unlinking Apple provider", {}, [Log.TAG_FIREBASE, "auth", "apple"])
	firebase_auth.unlink_provider("apple.com")
	@warning_ignore("redundant_await")
	var _res: String = await firebase_auth.account_unlinked


func _on_credential(result: Dictionary) -> void:
	apple_aut_res = result
	if result.has("error"):
		Log.error(
			"Apple Auth error",
			{"error": result.error},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth", "apple"]
		)


func _on_authorization(result: Dictionary) -> void:
	if result.has("error"):
		emit_signal("apple_auth_respons", result)
	else:
		emit_signal("apple_auth_respons", result)


func apple_credential() -> void:
	godot_apple_auth.credential()


func logged_in(res: int) -> void:
	Log.info("Firebase login completed", {"result_code": res}, [Log.TAG_FIREBASE, "auth"])


func login() -> int:
	var retval: int = 0
	Log.info("Attempting Firebase login", {}, [Log.TAG_FIREBASE, "auth"])
	@warning_ignore("redundant_await")
	await Engine.get_main_loop().process_frame

	if !is_available():
		Log.warning(
			"Firebase Auth module not available", {}, [Log.TAG_FIREBASE, "auth", "validation"]
		)
		return 1

	if !firebase_auth.is_logged_in():
		firebase_auth.sign_in_anonymously()
		@warning_ignore("redundant_await")
		retval = await firebase_auth.logged_in

	return retval
