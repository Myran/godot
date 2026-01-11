## C++ Remote Config: Test getting values of different types through direct C++ bindings
class_name CPPRemoteConfigGetValuesAction
extends DebugAction

var cpp_rc: Object = null
var cpp_rc_instance_id: int = -1


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.remote_config.get_values"
	set_category("C++ Firebase")
	set_group("Remote Config")
	set_description("Test C++ Remote Config get value methods")
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

	# Set defaults for testing
	var defaults: Dictionary = {
		"test_bool": true,
		"test_int": 42,
		"test_double": 3.14,
		"test_string": "default_value"
	}
	if rc.has_method("set_defaults"):
		rc.call("set_defaults", defaults)

	_update_status("Testing get_boolean...")
	if rc.has_method("get_boolean"):
		var bool_val: Variant = rc.call("get_boolean", "test_bool")
		results["get_boolean"] = bool_val
		Log.debug("get_boolean result: " + str(bool_val), {}, ["debug", "cpp_firebase", "remote_config"])
	else:
		errors.append("get_boolean method not found")

	_update_status("Testing get_int...")
	if rc.has_method("get_int"):
		var int_val: Variant = rc.call("get_int", "test_int")
		results["get_int"] = int_val
		Log.debug("get_int result: " + str(int_val), {}, ["debug", "cpp_firebase", "remote_config"])
	else:
		errors.append("get_int method not found")

	_update_status("Testing get_double...")
	if rc.has_method("get_double"):
		var double_val: Variant = rc.call("get_double", "test_double")
		results["get_double"] = double_val
		Log.debug("get_double result: " + str(double_val), {}, ["debug", "cpp_firebase", "remote_config"])
	else:
		errors.append("get_double method not found")

	_update_status("Testing get_string...")
	if rc.has_method("get_string"):
		var string_val: Variant = rc.call("get_string", "test_string")
		results["get_string"] = string_val
		Log.debug("get_string result: " + str(string_val), {}, ["debug", "cpp_firebase", "remote_config"])
	else:
		errors.append("get_string method not found")

	_update_status("Testing get_keys...")
	if rc.has_method("get_keys"):
		var keys: Variant = rc.call("get_keys")
		results["get_keys"] = keys
		Log.debug("get_keys result: " + str(keys), {}, ["debug", "cpp_firebase", "remote_config"])
	else:
		errors.append("get_keys method not found")

	_update_status("Testing get_keys_by_prefix...")
	if rc.has_method("get_keys_by_prefix"):
		var prefixed_keys: Variant = rc.call("get_keys_by_prefix", "test_")
		results["get_keys_by_prefix"] = prefixed_keys
		Log.debug("get_keys_by_prefix result: " + str(prefixed_keys), {}, ["debug", "cpp_firebase", "remote_config"])

	# Test get_json and get_value_info if available
	_update_status("Testing get_json...")
	if rc.has_method("get_json"):
		var json_val: Variant = rc.call("get_json", "test_string")
		results["get_json"] = json_val
		Log.debug("get_json result: " + str(json_val), {}, ["debug", "cpp_firebase", "remote_config"])

	_update_status("Testing get_value_info...")
	if rc.has_method("get_value_info"):
		var info: Variant = rc.call("get_value_info", "test_string")
		results["get_value_info"] = info
		Log.debug("get_value_info result: " + str(info), {}, ["debug", "cpp_firebase", "remote_config"])

	_update_status("Testing get_fetch_info...")
	if rc.has_method("get_fetch_info"):
		var fetch_info: Variant = rc.call("get_fetch_info")
		results["get_fetch_info"] = fetch_info
		Log.debug("get_fetch_info result: " + str(fetch_info), {}, ["debug", "cpp_firebase", "remote_config"])

	var duration: int = Time.get_ticks_msec() - start_time

	if errors.is_empty():
		_update_status("✅ C++ Remote Config get_values tests passed", false)
		return DebugActionResult.new_success(
			"C++ Remote Config get_values tests passed",
			duration,
			action_name,
			{
				"cpp_instance_id": cpp_rc_instance_id,
				"results": results
			}
		)
	else:
		_update_status("❌ C++ Remote Config get_values tests failed: " + ", ".join(errors), true)
		return DebugActionResult.new_failure(
			"C++ Remote Config get_values tests failed: " + ", ".join(errors),
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
