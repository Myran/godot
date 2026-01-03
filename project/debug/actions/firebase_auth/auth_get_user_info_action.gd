class_name AuthGetUserInfoAction
extends CPPAuthDebugAction


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.auth.get_user_info"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Starting get user info test...")
	var start_time: int = Time.get_ticks_msec()

	var auth: Object = get_cpp_firebase_auth()
	if not is_instance_valid(auth):
		return DebugActionResult.new_failure(
			"FirebaseAuth C++ instance not available",
			"AUTH_UNAVAILABLE",
			DebugActionResult.ErrorCategory.FIREBASE,
			null,
			0,
			action_name,
			{}
		)

	var is_logged_in: bool = auth.is_logged_in()
	var uid: String = auth.uid() if auth.has_method("uid") else ""
	var providers: Array = []

	if auth.has_method("providers"):
		providers = auth.providers()

	var is_email_verified: bool = false
	if auth.has_method("is_email_verified"):
		is_email_verified = auth.is_email_verified()

	var duration: int = Time.get_ticks_msec() - start_time

	var metadata: Dictionary = {
		"is_logged_in": is_logged_in,
		"uid": uid,
		"provider_count": providers.size(),
		"providers": providers,
		"is_email_verified": is_email_verified,
		"is_anonymous":
		providers.is_empty() or (providers.size() == 1 and providers[0].get("name", "") == ""),
		"timestamp": Time.get_unix_time_from_system()
	}

	Log.info("✅ User info retrieved", metadata, ["debug", "cpp_auth", "user_info"])

	return DebugActionResult.new_success(true, 0, action_name, metadata)
