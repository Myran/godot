class_name RemoteConfigService
extends RefCounted

# Firebase Remote Config Service - Handles Remote Config operations
# Uses FirebaseRequest pattern for async operations
# Provides feature flag helpers and fetch throttling

signal config_loaded
signal config_error(error_code: String, error_message: String)

var _cpp_remote_config: Object  # FirebaseRemoteConfig C++ instance
var _is_initialized: bool = false
var _next_request_id: int = 1
var _pending_requests: Dictionary = {}

# Fetch throttling (client-side enforcement)
var _last_fetch_time_ms: int = 0
var _developer_mode_enabled: bool = false  # Developer mode bypasses throttling
const MIN_FETCH_INTERVAL_PRODUCTION_MS: int = 43200000  # 12 hours
const MIN_FETCH_INTERVAL_DEV_MS: int = 60000  # 1 minute


func _init(cpp_remote_config: Object) -> void:
	if not is_instance_valid(cpp_remote_config):
		Log.error(
			"RemoteConfigService: Invalid C++ instance provided",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	_cpp_remote_config = cpp_remote_config
	_connect_signals()
	_is_initialized = true

	Log.info(
		"RemoteConfigService initialized",
		{"instance_id": _cpp_remote_config.get_instance_id()},
		[Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)


func is_available() -> bool:
	return _is_initialized and is_instance_valid(_cpp_remote_config)


# === Fetch Throttling ===


func _get_min_fetch_interval_ms() -> int:
	if OS.is_debug_build():
		return MIN_FETCH_INTERVAL_DEV_MS
	return MIN_FETCH_INTERVAL_PRODUCTION_MS


func _can_fetch() -> bool:
	# Developer mode bypasses all throttling
	if _developer_mode_enabled:
		return true

	var now_ms: int = Time.get_ticks_msec()
	var interval_ms: int = _get_min_fetch_interval_ms()
	return (now_ms - _last_fetch_time_ms) >= interval_ms


func get_time_until_next_fetch_ms() -> int:
	var now_ms: int = Time.get_ticks_msec()
	var interval_ms: int = _get_min_fetch_interval_ms()
	var time_since_fetch: int = now_ms - _last_fetch_time_ms
	if time_since_fetch >= interval_ms:
		return 0
	return interval_ms - time_since_fetch


# === Core Async Operations ===


func fetch_and_activate() -> Variant:
	if not is_available():
		Log.error(
			"RemoteConfigService: Not available for fetch_and_activate",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {
			"status": "error",
			"code": "SERVICE_UNAVAILABLE",
			"message": "Remote Config not available"
		}

	if not _can_fetch():
		var time_remaining: int = get_time_until_next_fetch_ms()
		Log.warning(
			"RemoteConfigService: Fetch throttled",
			{"time_remaining_ms": time_remaining},
			[Log.TAG_FIREBASE]
		)
		return {
			"status": "error",
			"code": "THROTTLED",
			"message": "Fetch throttled, try again in " + str(time_remaining / 1000) + " seconds"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.debug(
		"RemoteConfigService: Starting fetch_and_activate",
		{"request_id": request_id},
		[Log.TAG_FIREBASE]
	)

	_cpp_remote_config.fetch_and_activate_async(request_id)
	_last_fetch_time_ms = Time.get_ticks_msec()

	var result: Variant = await request.await_completion()

	if result.get("status") == "ok":
		Log.info(
			"RemoteConfigService: fetch_and_activate completed successfully",
			{
				"request_id": request_id,
				"activated": result.get("payload", {}).get("activated", false)
			},
			[Log.TAG_FIREBASE]
		)
		config_loaded.emit()
	else:
		Log.error(
			"RemoteConfigService: fetch_and_activate failed",
			{"request_id": request_id, "error": result},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)

	return result


func fetch() -> Variant:
	if not is_available():
		Log.error(
			"RemoteConfigService: Not available for fetch", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {
			"status": "error",
			"code": "SERVICE_UNAVAILABLE",
			"message": "Remote Config not available"
		}

	if not _can_fetch():
		var time_remaining: int = get_time_until_next_fetch_ms()
		Log.warning(
			"RemoteConfigService: Fetch throttled",
			{"time_remaining_ms": time_remaining},
			[Log.TAG_FIREBASE]
		)
		return {"status": "error", "code": "THROTTLED", "message": "Fetch throttled"}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.debug("RemoteConfigService: Starting fetch", {"request_id": request_id}, [Log.TAG_FIREBASE])

	_cpp_remote_config.fetch_async(request_id)
	_last_fetch_time_ms = Time.get_ticks_msec()

	return await request.await_completion()


func activate() -> Variant:
	if not is_available():
		Log.error(
			"RemoteConfigService: Not available for activate", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {
			"status": "error",
			"code": "SERVICE_UNAVAILABLE",
			"message": "Remote Config not available"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.debug(
		"RemoteConfigService: Starting activate", {"request_id": request_id}, [Log.TAG_FIREBASE]
	)

	_cpp_remote_config.activate_async(request_id)

	var result: Variant = await request.await_completion()

	if result.get("status") == "ok":
		config_loaded.emit()

	return result


# === Value Retrieval (Synchronous) ===


func get_boolean(key: String, default_value: bool = false) -> bool:
	if not is_available() or not _cpp_remote_config.loaded():
		return default_value
	return _cpp_remote_config.get_boolean(key)


func get_string(key: String, default_value: String = "") -> String:
	if not is_available() or not _cpp_remote_config.loaded():
		return default_value
	return _cpp_remote_config.get_string(key)


func get_int(key: String, default_value: int = 0) -> int:
	if not is_available() or not _cpp_remote_config.loaded():
		return default_value
	return _cpp_remote_config.get_int(key)


func get_float(key: String, default_value: float = 0.0) -> float:
	if not is_available() or not _cpp_remote_config.loaded():
		return default_value
	return _cpp_remote_config.get_double(key)


func get_json(key: String) -> Dictionary:
	if not is_available() or not _cpp_remote_config.loaded():
		return {}
	return _cpp_remote_config.get_json(key)


# === Feature Flag Helpers ===


func is_feature_enabled(feature_key: String, default_enabled: bool = false) -> bool:
	return get_boolean(feature_key, default_enabled)


func get_feature_variant(feature_key: String, default_variant: String = "control") -> String:
	return get_string(feature_key, default_variant)


# === Key Enumeration ===


func get_all_keys() -> Array:
	if not is_available():
		return []
	return _cpp_remote_config.get_keys()


func get_keys_with_prefix(prefix: String) -> Array:
	if not is_available():
		return []
	return _cpp_remote_config.get_keys_by_prefix(prefix)


# === Status & Info ===


func is_loaded() -> bool:
	if not is_available():
		return false
	return _cpp_remote_config.loaded()


func get_fetch_info() -> Dictionary:
	if not is_available():
		return {"error": "Service not available"}
	return _cpp_remote_config.get_fetch_info()


# === Configuration ===


func set_defaults(defaults: Dictionary) -> void:
	if not is_available():
		Log.error(
			"RemoteConfigService: Not available for set_defaults",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	Log.debug(
		"RemoteConfigService: Setting defaults (sync)",
		{"key_count": defaults.size()},
		[Log.TAG_FIREBASE]
	)
	_cpp_remote_config.set_defaults(defaults)


func set_defaults_async(defaults: Dictionary) -> Variant:
	if not is_available():
		Log.error(
			"RemoteConfigService: Not available for set_defaults_async",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return {
			"status": "error",
			"code": "SERVICE_UNAVAILABLE",
			"message": "Remote Config not available"
		}

	var request_id: int = _get_next_request_id()
	var request: FirebaseRequest = FirebaseRequest.new(request_id)
	_pending_requests[request_id] = request

	Log.debug(
		"RemoteConfigService: Starting set_defaults_async",
		{"request_id": request_id, "key_count": defaults.size()},
		[Log.TAG_FIREBASE]
	)

	_cpp_remote_config.set_defaults_async(request_id, defaults)

	return await request.await_completion()


func enable_developer_mode() -> void:
	if not is_available():
		Log.error(
			"RemoteConfigService: Not available for enable_developer_mode",
			{},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return

	Log.info(
		"RemoteConfigService: Enabling developer mode (fetch interval = 0)", {}, [Log.TAG_FIREBASE]
	)
	_cpp_remote_config.set_instant_fetching()
	# Enable developer mode flag to bypass GDScript-side throttling
	_developer_mode_enabled = true
	_last_fetch_time_ms = 0


# === Internal Helpers ===


func _get_next_request_id() -> int:
	var id: int = _next_request_id
	_next_request_id += 1
	return id


func _connect_signals() -> void:
	if not is_instance_valid(_cpp_remote_config):
		return

	# Connect C++ signals to complete pending requests
	var err: Error

	err = _cpp_remote_config.fetch_and_activate_completed.connect(_on_fetch_and_activate_completed)
	if err != OK:
		Log.error(
			"RemoteConfigService: Failed to connect fetch_and_activate_completed",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE]
		)

	err = _cpp_remote_config.fetch_completed.connect(_on_fetch_completed)
	if err != OK:
		Log.error(
			"RemoteConfigService: Failed to connect fetch_completed",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE]
		)

	err = _cpp_remote_config.activate_completed.connect(_on_activate_completed)
	if err != OK:
		Log.error(
			"RemoteConfigService: Failed to connect activate_completed",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE]
		)

	err = _cpp_remote_config.set_defaults_completed.connect(_on_set_defaults_completed)
	if err != OK:
		Log.error(
			"RemoteConfigService: Failed to connect set_defaults_completed",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE]
		)

	err = _cpp_remote_config.config_error.connect(_on_config_error)
	if err != OK:
		Log.error(
			"RemoteConfigService: Failed to connect config_error",
			{"error": error_string(err)},
			[Log.TAG_FIREBASE]
		)

	Log.debug(
		"RemoteConfigService: Signals connected", {}, [Log.TAG_FIREBASE, Log.TAG_INITIALIZATION]
	)


func _on_fetch_and_activate_completed(
	request_id: int, success: bool, activated: bool, error_message: String
) -> void:
	Log.debug(
		"RemoteConfigService: fetch_and_activate_completed received",
		{"request_id": request_id, "success": success, "activated": activated},
		[Log.TAG_FIREBASE]
	)

	if not _pending_requests.has(request_id):
		Log.warning(
			"RemoteConfigService: No pending request for ID",
			{"request_id": request_id},
			[Log.TAG_FIREBASE]
		)
		return

	var request: FirebaseRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)

	if success:
		request.complete_with_success({"activated": activated})
	else:
		request.complete_with_error("FETCH_AND_ACTIVATE_FAILED", error_message)


func _on_fetch_completed(request_id: int, success: bool, error_message: String) -> void:
	Log.debug(
		"RemoteConfigService: fetch_completed received",
		{"request_id": request_id, "success": success},
		[Log.TAG_FIREBASE]
	)

	if not _pending_requests.has(request_id):
		Log.warning(
			"RemoteConfigService: No pending request for ID",
			{"request_id": request_id},
			[Log.TAG_FIREBASE]
		)
		return

	var request: FirebaseRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)

	if success:
		request.complete_with_success({})
	else:
		request.complete_with_error("FETCH_FAILED", error_message)


func _on_activate_completed(
	request_id: int, success: bool, activated: bool, error_message: String
) -> void:
	Log.debug(
		"RemoteConfigService: activate_completed received",
		{"request_id": request_id, "success": success, "activated": activated},
		[Log.TAG_FIREBASE]
	)

	if not _pending_requests.has(request_id):
		Log.warning(
			"RemoteConfigService: No pending request for ID",
			{"request_id": request_id},
			[Log.TAG_FIREBASE]
		)
		return

	var request: FirebaseRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)

	if success:
		request.complete_with_success({"activated": activated})
	else:
		request.complete_with_error("ACTIVATE_FAILED", error_message)


func _on_set_defaults_completed(
	request_id: int, success: bool, error_code: int, error_message: String
) -> void:
	Log.debug(
		"RemoteConfigService: set_defaults_completed received",
		{"request_id": request_id, "success": success, "error_code": error_code},
		[Log.TAG_FIREBASE]
	)

	if not _pending_requests.has(request_id):
		Log.warning(
			"RemoteConfigService: No pending request for ID",
			{"request_id": request_id},
			[Log.TAG_FIREBASE]
		)
		return

	var request: FirebaseRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)

	if success:
		request.complete_with_success({})
	else:
		request.complete_with_error("SET_DEFAULTS_FAILED", error_message)


func _on_config_error(error_code: String, error_message: String) -> void:
	Log.error(
		"RemoteConfigService: Config error received",
		{"error_code": error_code, "error_message": error_message},
		[Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	config_error.emit(error_code, error_message)
