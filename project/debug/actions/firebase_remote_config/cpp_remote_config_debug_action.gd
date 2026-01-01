class_name CPPRemoteConfigDebugAction
extends DebugAction

var cpp_rc: Object = null
var cpp_rc_instance_id: int = -1


func _init() -> void:
	super._init()
	category = "C++ Firebase"
	action_callable = Callable(self, "_execute_action_logic")


func get_cpp_remote_config() -> Object:
	if cpp_rc != null and is_instance_valid(cpp_rc):
		return cpp_rc

	Log.debug("Creating direct C++ FirebaseRemoteConfig instance", {}, ["debug", "cpp_firebase", "remote_config"])

	if not ClassDB.class_exists("FirebaseRemoteConfig"):
		Log.error(
			"FirebaseRemoteConfig C++ class not available", {}, ["debug", "cpp_firebase", "remote_config", "error"]
		)
		return null

	cpp_rc = ClassDB.instantiate("FirebaseRemoteConfig")
	if not is_instance_valid(cpp_rc):
		Log.error(
			"Failed to instantiate C++ FirebaseRemoteConfig", {}, ["debug", "cpp_firebase", "remote_config", "error"]
		)
		return null

	cpp_rc_instance_id = cpp_rc.get_instance_id()
	Log.info(
		"C++ FirebaseRemoteConfig instance created",
		{"cpp_instance_id": cpp_rc_instance_id},
		["debug", "cpp_firebase", "remote_config"]
	)
	return cpp_rc


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
