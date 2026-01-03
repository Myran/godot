class_name CPPAuthDebugAction
extends DebugAction

var cpp_auth: Object = null
var cpp_auth_instance_id: int = -1


func _init() -> void:
	super._init()
	category = "C++ Firebase Auth"
	action_callable = Callable(self, "_execute_action_logic")


func get_cpp_firebase_auth() -> Object:
	if cpp_auth != null and is_instance_valid(cpp_auth):
		return cpp_auth

	Log.debug("Creating direct C++ Firebase Auth instance", {}, ["debug", "cpp_auth"])

	if not ClassDB.class_exists("FirebaseAuth"):
		Log.error("FirebaseAuth C++ class not available", {}, ["debug", "cpp_auth", "error"])
		return null

	cpp_auth = ClassDB.instantiate("FirebaseAuth")
	if not is_instance_valid(cpp_auth):
		Log.error("Failed to instantiate C++ FirebaseAuth", {}, ["debug", "cpp_auth", "error"])
		return null

	cpp_auth_instance_id = cpp_auth.get_instance_id()
	Log.info(
		"C++ Firebase Auth instance created",
		{"cpp_instance_id": cpp_auth_instance_id},
		["debug", "cpp_auth"]
	)
	return cpp_auth


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
