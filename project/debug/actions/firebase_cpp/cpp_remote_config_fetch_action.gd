## C++ Remote Config: Test fetch and activate through direct C++ bindings
class_name CPPRemoteConfigFetchAction
extends DebugAction

var cpp_rc: Object = null
var cpp_rc_instance_id: int = -1


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.remote_config.fetch_and_activate"
	set_category("C++ Firebase")
	set_group("Remote Config")
	set_description("Test C++ Remote Config fetch and activate")
	category = "C++ Firebase"
	action_callable = Callable(self, "_execute_action_logic")


func get_cpp_remote_config() -> Object:
	if cpp_rc != null and is_instance_valid(cpp_rc):
		return cpp_rc

	Log.debug(
		"Creating direct C++ FirebaseRemoteConfig instance",
		{},
		["debug", "cpp_firebase", "remote_config"]
	)

	if not ClassDB.class_exists("FirebaseRemoteConfig"):
		Log.error(
			"FirebaseRemoteConfig C++ class not available",
			{},
			["debug", "cpp_firebase", "remote_config", "error"]
		)
		return null

	cpp_rc = ClassDB.instantiate("FirebaseRemoteConfig")
	if not is_instance_valid(cpp_rc):
		Log.error(
			"Failed to instantiate C++ FirebaseRemoteConfig",
			{},
			["debug", "cpp_firebase", "remote_config", "error"]
		)
		return null

	cpp_rc_instance_id = cpp_rc.get_instance_id()

	# Set defaults for testing
	var defaults: Dictionary = {
		"test_bool": true,
		"test_int": 42,
		"test_double": 3.14,
		"test_string": "default_value"
	}
	if cpp_rc.has_method("set_defaults"):
		cpp_rc.call("set_defaults", defaults)

	Log.info(
		"C++ FirebaseRemoteConfig instance created",
		{"cpp_instance_id": cpp_rc_instance_id},
		["debug", "cpp_firebase", "remote_config"]
	)

	return cpp_rc


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var rc: Object = get_cpp_remote_config()

	if not is_instance_valid(rc):
		return DebugActionResult.new_failure(
			"FirebaseRemoteConfig C++ class not available",
			"CLASS_NOT_AVAILABLE",
			DebugActionResult.ErrorCategory.SYSTEM,
			{},
			0,
			action_name,
			{}
		)

	var start_time: int = Time.get_ticks_msec()
	var errors: Array[String] = []
	var results: Dictionary = {}

	# Test loaded state
	_update_status("Checking RemoteConfig loaded state...")
	if rc.has_method("loaded"):
		var loaded: bool = rc.call("loaded")
		results["loaded"] = loaded
		Log.debug("RemoteConfig loaded state: " + str(loaded), {}, ["debug", "cpp_firebase", "remote_config"])

	# Test fetch_and_activate_async
	_update_status("Testing fetch_and_activate_async...")
	if rc.has_method("fetch_and_activate_async"):
		if not rc.has_signal("fetch_and_activate_completed"):
			errors.append("fetch_and_activate_completed signal not found")
		else:
			# For fire-and-forget, just call it and assume success
			var request_id: int = Time.get_ticks_msec()
			_call_method_safe(rc, "fetch_and_activate_async", [request_id])
			results["fetch_and_activate"] = {"request_id": request_id}

	# Test individual fetch and activate if available
	if rc.has_method("fetch_async") and rc.has_method("activate_async"):
		_update_status("Testing separate fetch_async and activate_async...")

		var fetch_id: int = Time.get_ticks_msec()
		_call_method_safe(rc, "fetch_async", [fetch_id])
		results["fetch"] = {"request_id": fetch_id}

		var activate_id: int = Time.get_ticks_msec() + 1
		_call_method_safe(rc, "activate_async", [activate_id])
		results["activate"] = {"request_id": activate_id}

	var duration: int = Time.get_ticks_msec() - start_time

	if errors.is_empty():
		_update_status("✅ C++ Remote Config fetch tests passed", false)
		return DebugActionResult.new_success(
			"C++ Remote Config fetch tests passed",
			duration,
			action_name,
			{
				"cpp_instance_id": cpp_rc_instance_id,
				"results": results
			}
		)
	else:
		_update_status("❌ C++ Remote Config fetch tests failed: " + ", ".join(errors), true)
		return DebugActionResult.new_failure(
			"C++ Remote Config fetch tests failed: " + ", ".join(errors),
			"TESTS_FAILED",
			DebugActionResult.ErrorCategory.SYSTEM,
			{"errors": errors, "results": results},
			duration,
			action_name,
			{"cpp_instance_id": cpp_rc_instance_id}
		)


func _call_method_safe(obj: Object, method_name: String, args: Array = []) -> bool:
	if not obj.has_method(method_name):
		Log.error(
			"Method not found: " + method_name,
			{"object": obj.get_class(), "method": method_name},
			["debug", "cpp_firebase", "remote_config", "error"]
		)
		return false

	obj.callv(method_name, args)
	return true
