## Steam Authentication Service (Task-404)
##
## Provides Steam authentication integration with Firebase using custom tokens.
##
## Architecture:
## 1. Client gets Steam session ticket via Steamworks SDK
## 2. Ticket sent to backend Cloud Function for verification
## 3. Backend validates ticket with Steam Web API
## 4. Backend returns Firebase custom token
## 5. Client signs in to Firebase with custom token
##
## Note: This service requires the GodotSteam GDExtension to be integrated.
## See: https://github.com/GodotSteam/GodotSteam
##
## For now, this service provides graceful handling when Steam is not available.

class_name SteamAuthService
extends RefCounted

## Steam-specific logging tags (not in core logger to avoid logger.gd changes)
const TAG_STEAM: String = "steam"
const TAG_STEAM_INIT: String = "steam.init"
const TAG_STEAM_AUTH: String = "steam.auth"
const TAG_STEAM_TICKET: String = "steam.ticket"

const STEAM_WEB_API_URL: String = "https://api.steampowered.com/ISteamUserAuth/AuthenticateUserTicket/v1/"

enum SteamInitResult {
	OK = 0,
	FAILED = 1,
	NO_STEAM_CLIENT = 2,
	VERSION_MISMATCH = 3,
}

signal steam_auth_completed(steam_id: String, firebase_uid: String)
signal steam_auth_failed(error_code: String, error_message: String)
signal custom_token_received(custom_token: String)

var _steam_available: bool = false
var _steam_initialized: bool = false
var _auth_service: AuthService
var _pending_request_id: int = 0
var _backend_url: String = ""


## Initialize the Steam auth service
## backend_url: Optional Cloud Function URL for ticket verification
## Returns: SteamInitResult status code
func initialize(backend_url: String = "") -> int:
	_backend_url = backend_url

	# Check if GodotSteam GDExtension is available
	if not ClassDB.class_exists("Steam"):
		(
			Log
			. info(
				"SteamAuthService: GodotSteam GDExtension not available - Steam auth will be skipped gracefully",
				{},
				[Log.TAG_FIREBASE, TAG_STEAM, "info"]
			)
		)
		return SteamInitResult.NO_STEAM_CLIENT

	_steam_available = true

	# Attempt to initialize Steam
	var steam_init_result: int = _initialize_steam()

	if steam_init_result == SteamInitResult.OK:
		_steam_initialized = true
		Log.info(
			"SteamAuthService: Steam initialized successfully",
			{},
			[Log.TAG_FIREBASE, TAG_STEAM, "info"]
		)
	else:
		_steam_initialized = false
		Log.warning(
			"SteamAuthService: Steam initialization failed with code %d" % steam_init_result,
			{"code": steam_init_result},
			[TAG_STEAM, Log.TAG_WARNING]
		)

	return steam_init_result


## Initialize Steam via GodotSteam GDExtension
## Returns: SteamInitResult status code
func _initialize_steam() -> int:
	if not _steam_available:
		return SteamInitResult.NO_STEAM_CLIENT

	# Call Steam.steamInit() via GDExtension
	# This is a placeholder - actual implementation requires GodotSteam integration
	var result: int = SteamInitResult.FAILED

	# TODO: Replace with actual GodotSteam call when GDExtension is integrated:
	# if Steam.steamInit():
	# 	result = SteamInitResult.OK
	# else:
	# 	match Steam.getSteamInitResult():
	# 		Steam.STEAM_INIT_RESULT_OK: result = SteamInitResult.OK
	# 		Steam.STEAM_INIT_NO_CLIENT: result = SteamInitResult.NO_STEAM_CLIENT
	# 		Steam.STEAM_INIT_VERSION_MISMATCH: result = SteamInitResult.VERSION_MISMATCH
	# 		_: result = SteamInitResult.FAILED

	Log.warning(
		"SteamAuthService: Steam.steamInit() not yet implemented - requires GodotSteam GDExtension",
		{},
		[TAG_STEAM, Log.TAG_WARNING]
	)

	return result


## Check if Steam is available and initialized
func is_available() -> bool:
	return _steam_available and _steam_initialized


## Check if Steam client is running
func is_steam_running() -> bool:
	if not _steam_available:
		return false

	# TODO: Replace with actual GodotSteam call:
	# return Steam.isSteamRunning()
	Log.warning(
		"SteamAuthService: Steam.isSteamRunning() not yet implemented",
		{},
		[TAG_STEAM, Log.TAG_WARNING]
	)
	return false


## Get the current user's Steam ID (64-bit)
## Returns: Steam ID as String, or empty string if not available
func get_steam_id() -> String:
	if not is_available():
		return ""

	# TODO: Replace with actual GodotSteam call:
	# return str(Steam.getSteamID())
	Log.warning(
		"SteamAuthService: Steam.getSteamID() not yet implemented", {}, [TAG_STEAM, Log.TAG_WARNING]
	)
	return ""


## Get the user's Steam persona name
## Returns: Display name, or empty string if not available
func get_persona_name() -> String:
	if not is_available():
		return ""

	# TODO: Replace with actual GodotSteam call:
	# return Steam.getPersonaName()
	Log.warning(
		"SteamAuthService: Steam.getPersonaName() not yet implemented",
		{},
		[TAG_STEAM, Log.TAG_WARNING]
	)
	return ""


## Get Steam authentication session ticket
## Returns: PackedByteArray containing the ticket, or empty array on failure
func get_auth_session_ticket() -> PackedByteArray:
	if not is_available():
		Log.error(
			"SteamAuthService: Cannot get auth ticket - Steam not available",
			{},
			[TAG_STEAM, Log.TAG_ERROR]
		)
		steam_auth_failed.emit("steam_not_available", "Steam is not available on this platform")
		return PackedByteArray()

	# TODO: Replace with actual GodotSteam call:
	# var ticket_data: PackedByteArray = Steam.getAuthSessionTicket()
	# return ticket_data

	Log.warning(
		"SteamAuthService: Steam.getAuthSessionTicket() not yet implemented",
		{},
		[TAG_STEAM, Log.TAG_WARNING]
	)
	return PackedByteArray()


## Authenticate with Steam and Firebase
## Returns: Dictionary with "success" bool and "error" string on failure
func authenticate_with_steam() -> Dictionary:
	# Check availability first
	if not is_available():
		var error: String = "Steam not available - GDExtension not integrated"
		Log.error("SteamAuthService: %s" % error, {}, [TAG_STEAM, Log.TAG_ERROR])
		steam_auth_failed.emit("steam_not_available", error)
		return {"success": false, "error": error}

	if not is_steam_running():
		var error: String = "Steam client is not running"
		Log.error("SteamAuthService: %s" % error, {}, [TAG_STEAM, Log.TAG_ERROR])
		steam_auth_failed.emit("steam_not_running", error)
		return {"success": false, "error": error}

	# Get Steam session ticket
	var ticket: PackedByteArray = get_auth_session_ticket()
	# Note: get_auth_session_ticket emits its own signal if Steam not available
	if ticket.is_empty():
		# Signal already emitted by get_auth_session_ticket
		return {"success": false, "error": "Failed to get Steam auth ticket"}

	var steam_id: String = get_steam_id()
	var persona_name: String = get_persona_name()

	# If backend URL is configured, send ticket for verification
	if not _backend_url.is_empty():
		return await _verify_ticket_with_backend(ticket, steam_id, persona_name)

	# Otherwise, return the ticket for manual processing
	return {
		"success": true,
		"steam_id": steam_id,
		"ticket": ticket,
		"note": "Backend verification required - provide ticket to Steam verification endpoint"
	}


## Verify Steam ticket with backend Cloud Function
## Returns: Dictionary with "success" bool and "custom_token" on success
func _verify_ticket_with_backend(
	ticket: PackedByteArray, steam_id: String, persona_name: String
) -> Dictionary:
	var http: HTTPRequest = HTTPRequest.new()
	http.set_timeout_seconds(30.0)

	# Ticket needs to be hex-encoded for transport
	var ticket_hex: String = bytes_to_hex(ticket)

	var body: Dictionary = {
		"ticket": ticket_hex, "steam_id": steam_id, "persona_name": persona_name
	}

	var headers: PackedStringArray = ["Content-Type: application/json"]

	var json: JSON = JSON.new()
	var stringify_result = json.stringify(body)
	if stringify_result != OK:
		return {"success": false, "error": "Failed to serialize request body"}

	Log.info(
		"SteamAuthService: Sending ticket to backend for verification",
		{"backend_url": _backend_url, "steam_id": steam_id},
		[TAG_STEAM, Log.TAG_NETWORK]
	)

	# TODO: Implement HTTP request to backend
	# For now, return pending status
	Log.warning(
		"SteamAuthService: Backend HTTP request not yet implemented",
		{},
		[TAG_STEAM, Log.TAG_WARNING]
	)

	return {
		"success": false,
		"error": "backend_http_not_implemented",
		"note": "HTTP request to backend needs implementation"
	}


## Sign in to Firebase with a custom token (from backend)
## custom_token: Firebase custom token from Steam verification
## Returns: Dictionary with "success" bool and "uid" on success
func sign_in_with_custom_token(custom_token: String) -> Dictionary:
	if custom_token.is_empty():
		return {"success": false, "error": "Custom token is empty"}

	# Get AuthService instance from FirebaseService singleton
	if not _auth_service:
		if not ClassDB.class_exists("FirebaseService"):
			return {"success": false, "error": "FirebaseService not available"}

		_auth_service = FirebaseService.get_auth()

	if not _auth_service:
		return {"success": false, "error": "AuthService not available"}

	# Sign in with custom token
	var result: Variant = await _auth_service.sign_in_with_custom_token(custom_token)

	if result is Dictionary and result.get("success", false):
		var uid: String = result.get("uid", "")
		Log.info(
			"SteamAuthService: Successfully signed in with Steam",
			{"uid": uid},
			[TAG_STEAM, Log.TAG_FIREBASE]
		)
		steam_auth_completed.emit(get_steam_id(), uid)
		return result

	var error: String = (
		result.get("error", "Unknown error") if result is Dictionary else "Invalid result type"
	)
	Log.error(
		"SteamAuthService: Failed to sign in with custom token",
		{"error": error},
		[TAG_STEAM, Log.TAG_FIREBASE, Log.TAG_ERROR]
	)
	steam_auth_failed.emit("firebase_sign_in_failed", error)
	return {"success": false, "error": error}


## Convert bytes to hex string
func bytes_to_hex(bytes: PackedByteArray) -> String:
	var hex: String = ""
	for byte in bytes:
		hex += "%02X" % byte
	return hex


## Convert hex string to bytes
func hex_to_bytes(hex: String) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	var i: int = 0
	while i < hex.length():
		var byte_str: String = hex.substr(i, 2)
		bytes.append(byte_str.hex_to_int())
		i += 2
	return bytes


## Shutdown Steam integration
func shutdown() -> void:
	if _steam_initialized:
		# TODO: Call Steam.shutdown() when GDExtension is integrated
		_steam_initialized = false
		Log.info("SteamAuthService: Steam shutdown", {}, [TAG_STEAM, Log.TAG_INFO])
