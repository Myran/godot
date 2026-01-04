class_name BackendAuthDebugAction
extends DebugAction

## Base class for Firebase Auth Service (AuthService) debug actions.
## Tests the production auth layer that the game actually uses.
## Complements cpp_auth_debug_action which tests C++ layer directly.
##
## NSRunLoop pumping is handled internally by AuthService - tests just call and validate.

var auth_service: AuthService = null
var firebase_service: FirebaseService = null


func _init() -> void:
	super._init()
	category = "Backend Firebase Auth"
	action_callable = Callable(self, "_execute_action_logic")
	auto_continue = false  # AuthService operations are async


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		auth_service = null
		firebase_service = null


## Get the AuthService instance for testing
func _get_auth_service() -> AuthService:
	if auth_service != null:
		return auth_service

	# Get FirebaseService autoload (Godot autoloads become global variables)
	# Note: Use direct autoload check, not Engine.has_singleton
	if not FirebaseService:
		Log.error("FirebaseService autoload not available", {}, ["debug", "backend_auth", "error"])
		return null

	firebase_service = FirebaseService
	if not is_instance_valid(firebase_service):
		Log.error("FirebaseService autoload not valid", {}, ["debug", "backend_auth", "error"])
		return null

	# Get AuthService from FirebaseService
	auth_service = firebase_service.get_auth()
	if auth_service == null:
		Log.error(
			"AuthService not available from FirebaseService", {}, ["debug", "backend_auth", "error"]
		)
		return null

	if not auth_service.is_available():
		Log.error(
			"AuthService.is_available() returned false", {}, ["debug", "backend_auth", "error"]
		)
		return null

	Log.info("BackendAuthService obtained for testing", {}, ["debug", "backend_auth"])
	return auth_service


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	push_error("_execute_action_logic() not implemented in " + get_script().get_path())
	_update_status("ERROR: _execute_action_logic() not implemented", true)
	return DebugActionResult.new_failure(
		str("_execute_action_logic() not implemented in " + get_script().get_path()),
		"NOT_IMPLEMENTED",
		DebugActionResult.ErrorCategory.SYSTEM,
		{"error": "missing_implementation"},
		0,
		action_name,
		{}
	)
