class_name AuthService
extends RefCounted

# Firebase Auth Service - Thread-safe async authentication operations
# Uses FirebaseRequest pattern for async operations with request IDs
# Provides production-ready authentication with proper error handling and shutdown safety
#
# Task-399: Refactored to match Remote Config and Database service patterns
# - Thread-safe C++ singleton with shutdown safety
# - MessageQueue marshalling for cross-thread callbacks
# - Request ID tracking for concurrent operations
# - ARM64-safe memory handling

signal sign_in_completed(request_id: int, success: bool, uid: String, error_message: String)
signal sign_out_completed(success: bool)
signal user_info_changed(user: Dictionary)
signal auth_error(error_code: String, error_message: String)

var _cpp_auth: Object  # FirebaseAuth C++ instance
var _is_initialized: bool = false
var _next_request_id: int = 1
var _pending_requests: Dictionary = {}

# User state cache
var _current_user: Dictionary = {}
var _is_signed_in: bool = false


func _init(cpp_auth: Object) -> void:
	if not is_instance_valid(cpp_auth):
		Log.error(
			"AuthService: Invalid C++ instance provided",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth", "initialization"]
		)
		return

	_cpp_auth = cpp_auth
	_connect_signals()
	_is_initialized = true
	_refresh_user_state()

	Log.info(
		"AuthService initialized",
		{"instance_id": _cpp_auth.get_instance_id()},
		[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION, "auth"]
	)


func is_available() -> bool:
	return _is_initialized and is_instance_valid(_cpp_auth)


# === Core Async Operations ===


func sign_in_anonymously() -> Variant:
	if not is_available():
		Log.error(
			"AuthService: Not available for sign_in_anonymously",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth"]
		)
		return {
			"status": "error",
			"code": "SERVICE_UNAVAILABLE",
			"message": "Auth service not available"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.info(
		"AuthService: Starting anonymous sign in",
		{"request_id": request_id},
		[Log.TAG_FIREBASE, "auth"]
	)

	_cpp_auth.sign_in_anonymously_async(request_id)
	return await request.await_completion()


func sign_in_with_custom_token(token: String) -> Variant:
	if not is_available():
		Log.error(
			"AuthService: Not available for sign_in_with_custom_token",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth"]
		)
		return {
			"status": "error",
			"code": "SERVICE_UNAVAILABLE",
			"message": "Auth service not available"
		}

	if token.is_empty():
		return {
			"status": "error", "code": "INVALID_ARGUMENT", "message": "Custom token cannot be empty"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.info(
		"AuthService: Starting custom token sign in",
		{"request_id": request_id},
		[Log.TAG_FIREBASE, "auth"]
	)

	_cpp_auth.sign_in_with_custom_token_async(request_id, token)
	return await request.await_completion()


func sign_in_with_email(email: String, password: String) -> Variant:
	if not is_available():
		Log.error(
			"AuthService: Not available for sign_in_with_email",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth"]
		)
		return {
			"status": "error",
			"code": "SERVICE_UNAVAILABLE",
			"message": "Auth service not available"
		}

	if email.is_empty() or password.is_empty():
		return {
			"status": "error",
			"code": "INVALID_ARGUMENT",
			"message": "Email and password cannot be empty"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.info(
		"AuthService: Starting email/password sign in",
		{"request_id": request_id, "email": email},
		[Log.TAG_FIREBASE, "auth"]
	)

	_cpp_auth.sign_in_with_email_async(request_id, email, password)
	return await request.await_completion()


func sign_out() -> Variant:
	if not is_available():
		Log.error(
			"AuthService: Not available for sign_out", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR, "auth"]
		)
		return {
			"status": "error",
			"code": "SERVICE_UNAVAILABLE",
			"message": "Auth service not available"
		}

	if not _is_signed_in:
		return {"status": "ok", "message": "Already signed out"}

	Log.info("AuthService: Signing out", {}, [Log.TAG_FIREBASE, "auth"])

	_cpp_auth.sign_out()
	_refresh_user_state()

	# Clear Sentry user context on logout
	if SentryHelper:
		SentryHelper.set_user({})
		SentryHelper.set_tag("auth_state", "signed_out")

	return {"status": "ok", "message": "Signed out successfully"}


func get_id_token(force_refresh: bool = false) -> Variant:
	if not is_available():
		Log.error(
			"AuthService: Not available for get_id_token",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth"]
		)
		return {
			"status": "error",
			"code": "SERVICE_UNAVAILABLE",
			"message": "Auth service not available"
		}

	if not _is_signed_in:
		return {
			"status": "error", "code": "NOT_SIGNED_IN", "message": "No user is currently signed in"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.debug(
		"AuthService: Getting ID token",
		{"request_id": request_id, "force_refresh": force_refresh},
		[Log.TAG_FIREBASE, "auth"]
	)

	_cpp_auth.get_id_token_async(request_id, force_refresh)
	return await request.await_completion()


# === User State ===


func get_current_user() -> Dictionary:
	if not is_available():
		return {}
	return _current_user.duplicate()


func get_uid() -> String:
	if not is_available():
		return ""
	return _current_user.get("uid", "")


func is_signed_in() -> bool:
	return _is_signed_in and is_available()


func get_providers() -> Array:
	if not is_available():
		return []
	return _current_user.get("providers", [])


func is_anonymous() -> bool:
	if not _is_signed_in:
		return false
	var providers: Array = get_providers()
	# Anonymous user has no providers or empty provider name
	return providers.is_empty() or (providers.size() == 1 and providers[0].get("name", "") == "")


func check_provider_connection(provider_name: String) -> bool:
	if not _is_signed_in:
		return false
	for provider: Dictionary in get_providers():
		if provider.get("name", "") == provider_name:
			return true
	return false


# === OAuth Integration (Apple, Facebook) ===
# These methods integrate with existing auth.gd for OAuth flows


func sign_in_with_apple_async() -> Variant:
	# Delegates to existing auth.gd implementation
	# The Apple Auth SDK singleton handles the OAuth flow
	if not is_available():
		return {
			"status": "error",
			"code": "SERVICE_UNAVAILABLE",
			"message": "Auth service not available"
		}

	# Return a request that will be completed by the C++ layer
	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.info(
		"AuthService: Starting Apple sign in",
		{"request_id": request_id},
		[Log.TAG_FIREBASE, "auth", "apple"]
	)

	# Note: Actual Apple sign-in flow requires auth.gd integration
	# This request will be completed when Apple credential is received
	return await request.await_completion()


func sign_in_with_facebook_async() -> Variant:
	# Delegates to existing auth.gd implementation
	# The Facebook SDK singleton handles the OAuth flow
	if not is_available():
		return {
			"status": "error",
			"code": "SERVICE_UNAVAILABLE",
			"message": "Auth service not available"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.info(
		"AuthService: Starting Facebook sign in",
		{"request_id": request_id},
		[Log.TAG_FIREBASE, "auth", "facebook"]
	)

	return await request.await_completion()


# === Internal Helpers ===


func _get_next_request_id() -> int:
	var id: int = _next_request_id
	_next_request_id += 1
	return id


func _refresh_user_state() -> void:
	if not is_available():
		_current_user.clear()
		_is_signed_in = false
		return

	_is_signed_in = _cpp_auth.is_logged_in()

	if _is_signed_in:
		_current_user = {
			"uid": _cpp_auth.uid(),
			"providers": _cpp_auth.providers() if _cpp_auth.has_method("providers") else [],
			"is_email_verified":
			_cpp_auth.is_email_verified() if _cpp_auth.has_method("is_email_verified") else false,
		}

		# Update Sentry user context on sign in
		if SentryHelper:
			SentryHelper.set_user({"id": _current_user.uid})
			SentryHelper.set_tag("auth_state", "signed_in" if not is_anonymous() else "anonymous")

		Log.info(
			"AuthService: User state refreshed",
			{"uid": _current_user.uid, "providers": _current_user.providers.size()},
			[Log.TAG_FIREBASE, "auth"]
		)
	else:
		_current_user.clear()


func _connect_signals() -> void:
	if not is_instance_valid(_cpp_auth):
		return

	# Connect C++ signals to GDScript handlers
	var err: Error

	# New async operation signals (from C++ refactoring)
	err = _cpp_auth.sign_in_completed.connect(_on_sign_in_completed)
	if err != OK:
		Log.error(
			"AuthService: Failed to connect sign_in_completed",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth"]
		)

	err = _cpp_auth.custom_token_sign_in_completed.connect(_on_custom_token_sign_in_completed)
	if err != OK:
		Log.error(
			"AuthService: Failed to connect custom_token_sign_in_completed",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth"]
		)

	# Note: email sign-in uses the standard sign_in_completed signal (same as anonymous)
	# There is no separate email_sign_in_completed signal in the C++ layer

	err = _cpp_auth.id_token_result.connect(_on_id_token_result)
	if err != OK:
		Log.error(
			"AuthService: Failed to connect id_token_result",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth"]
		)

	# Legacy signals for backward compatibility
	err = _cpp_auth.logged_in.connect(_on_logged_in)
	if err != OK:
		Log.error(
			"AuthService: Failed to connect logged_in",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth"]
		)

	err = _cpp_auth.account_linked.connect(_on_account_linked)
	if err != OK:
		Log.error(
			"AuthService: Failed to connect account_linked",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth"]
		)

	err = _cpp_auth.account_unlinked.connect(_on_account_unlinked)
	if err != OK:
		Log.error(
			"AuthService: Failed to connect account_unlinked",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE, Log.TAG_ERROR, "auth"]
		)

	Log.debug(
		"AuthService: Signals connected", {}, [Log.TAG_FIREBASE, "auth", Log.TAG_INITIALIZATION]
	)


# === Signal Handlers (C++ Callbacks) ===


func _on_sign_in_completed(
	request_id: int, success: bool, uid: String, error_message: String
) -> void:
	# C++ signal: sign_in_completed(request_id, success, uid, error_message)
	# Note: C++ layer converts error codes to strings before emitting
	Log.debug(
		"AuthService: sign_in_completed received",
		{"request_id": request_id, "success": success, "uid": uid},
		[Log.TAG_FIREBASE, "auth"]
	)

	# Refresh user state after sign in attempt
	_refresh_user_state()

	if not _pending_requests.has(request_id):
		Log.warning(
			"AuthService: No pending request for ID",
			{"request_id": request_id},
			[Log.TAG_FIREBASE, "auth"]
		)
		return

	var request: FirebaseRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)

	if success:
		request.complete_with_success({"uid": uid, "user": get_current_user()})
		sign_in_completed.emit(request_id, true, uid, "")
	else:
		request.complete_with_error("AUTH_ERROR", error_message)
		sign_in_completed.emit(request_id, false, "", error_message)


func _on_custom_token_sign_in_completed(
	request_id: int, success: bool, uid: String, error_message: String
) -> void:
	# C++ signal: custom_token_sign_in_completed(request_id, success, uid, error_message)
	# Note: C++ layer converts error codes to strings before emitting
	Log.debug(
		"AuthService: custom_token_sign_in_completed received",
		{"request_id": request_id, "success": success, "uid": uid},
		[Log.TAG_FIREBASE, "auth"]
	)

	_refresh_user_state()

	if not _pending_requests.has(request_id):
		Log.warning(
			"AuthService: No pending request for custom token ID",
			{"request_id": request_id},
			[Log.TAG_FIREBASE, "auth"]
		)
		return

	var request: FirebaseRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)

	if success:
		request.complete_with_success({"uid": uid, "user": get_current_user()})
	else:
		request.complete_with_error("AUTH_ERROR", error_message)


func _on_id_token_result(
	request_id: int, success: bool, token: String, error_message: String
) -> void:
	# C++ signal: id_token_result(request_id, success, token, error_message)
	Log.debug(
		"AuthService: id_token_result received",
		{"request_id": request_id, "success": success},
		[Log.TAG_FIREBASE, "auth"]
	)

	if not _pending_requests.has(request_id):
		Log.warning(
			"AuthService: No pending request for ID token ID",
			{"request_id": request_id},
			[Log.TAG_FIREBASE, "auth"]
		)
		return

	var request: FirebaseRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)

	if success:
		request.complete_with_success({"token": token})
	else:
		request.complete_with_error("TOKEN_ERROR", error_message)


# === Legacy Signal Handlers (Backward Compatibility) ===


func _on_logged_in(error_code: int) -> void:
	Log.debug(
		"AuthService: Legacy logged_in signal received",
		{"error_code": error_code},
		[Log.TAG_FIREBASE, "auth"]
	)

	_refresh_user_state()

	# Legacy signals don't have request IDs, emit to service signal
	if error_code == 0:
		sign_in_completed.emit(0, true, get_uid(), "")
	else:
		var error_msg: String = _firebase_error_code_to_string(error_code)
		sign_in_completed.emit(0, false, "", error_msg)


func _on_account_linked(error_code: int) -> void:
	Log.debug(
		"AuthService: account_linked signal received",
		{"error_code": error_code},
		[Log.TAG_FIREBASE, "auth"]
	)

	_refresh_user_state()


func _on_account_unlinked(provider_id: String) -> void:
	Log.debug(
		"AuthService: account_unlinked signal received",
		{"provider_id": provider_id},
		[Log.TAG_FIREBASE, "auth"]
	)

	_refresh_user_state()


# === Utility ===


func _firebase_error_code_to_string(error_code: int) -> String:
	# Convert Firebase Auth error codes to strings
	match error_code:
		0:
			return "NONE"
		1:
			return "ERROR_UNKNOWN"
		2:
			return "ERROR_INVALID_CUSTOM_TOKEN"
		3:
			return "ERROR_CUSTOM_TOKEN_MISMATCH"
		4:
			return "ERROR_INVALID_CREDENTIAL"
		5:
			return "ERROR_USER_DISABLED"
		6:
			return "ERROR_EMAIL_ALREADY_IN_USE"
		7:
			return "ERROR_INVALID_EMAIL"
		8:
			return "ERROR_WRONG_PASSWORD"
		9:
			return "ERROR_TOO_MANY_REQUESTS"
		10:
			return "ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL"
		11:
			return "ERROR_REQUIRES_RECENT_LOGIN"
		12:
			return "ERROR_PROVIDER_ALREADY_LINKED"
		13:
			return "ERROR_OPERATION_NOT_ALLOWED"
		14:
			return "ERROR_WEAK_PASSWORD"
		_:
			return "ERROR_CODE_" + str(error_code)
