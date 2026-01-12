## C++ Analytics: Test event logging through direct C++ bindings
class_name CPPAnalyticsLogEventAction
extends DebugAction

var cpp_analytics: Object = null
var cpp_analytics_instance_id: int = -1


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.analytics.log_event"
	set_category("C++ Firebase")
	set_group("Analytics")
	set_description("Test C++ Analytics event logging")
	category = "C++ Firebase"
	action_callable = Callable(self, "_execute_action_logic")


func get_cpp_analytics() -> Object:
	if cpp_analytics != null and is_instance_valid(cpp_analytics):
		return cpp_analytics

	Log.debug(
		"Creating direct C++ FirebaseAnalytics instance", {}, ["debug", "cpp_firebase", "analytics"]
	)

	if not ClassDB.class_exists("FirebaseAnalytics"):
		Log.error(
			"FirebaseAnalytics C++ class not available",
			{},
			["debug", "cpp_firebase", "analytics", "error"]
		)
		return null

	cpp_analytics = ClassDB.instantiate("FirebaseAnalytics")
	if not is_instance_valid(cpp_analytics):
		Log.error(
			"Failed to instantiate C++ FirebaseAnalytics",
			{},
			["debug", "cpp_firebase", "analytics", "error"]
		)
		return null

	cpp_analytics_instance_id = cpp_analytics.get_instance_id()

	Log.info(
		"C++ FirebaseAnalytics instance created",
		{"cpp_instance_id": cpp_analytics_instance_id},
		["debug", "cpp_firebase", "analytics"]
	)

	return cpp_analytics


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var analytics: Object = get_cpp_analytics()

	if not is_instance_valid(analytics):
		return DebugActionResult.new_failure(
			"FirebaseAnalytics C++ class not available",
			"CLASS_NOT_AVAILABLE",
			DebugActionResult.ErrorCategory.SYSTEM,
			{},
			0,
			action_name,
			{}
		)

	var start_time: int = Time.get_ticks_msec()
	var errors: Array[String] = []

	# Initialize analytics
	_update_status("Initializing C++ Analytics...")
	if not _call_method_safe(analytics, "initialize"):
		errors.append("initialize failed")

	_update_status("Testing basic log_event...")
	if not _call_method_safe(analytics, "log_event", ["cpp_test_basic_event"]):
		errors.append("log_event basic failed")

	_update_status("Testing log_event with string param...")
	if not _call_method_safe(
		analytics, "log_event_string", ["cpp_test_string_event", "param_name", "test_value"]
	):
		errors.append("log_event_string failed")

	_update_status("Testing log_event with int param...")
	if not _call_method_safe(analytics, "log_event_int", ["cpp_test_int_event", "int_param", 42]):
		errors.append("log_event_int failed")

	_update_status("Testing log_event with double param...")
	if not _call_method_safe(
		analytics, "log_event_double", ["cpp_test_double_event", "double_param", 3.14]
	):
		errors.append("log_event_double failed")

	_update_status("Testing log_event with params...")
	var params: Dictionary = {"string_param": "value", "int_param": 100, "double_param": 2.5}
	if not _call_method_safe(analytics, "log_event_params", ["cpp_test_params_event", params]):
		errors.append("log_event_params failed")

	var duration: int = Time.get_ticks_msec() - start_time

	if errors.is_empty():
		_update_status("✅ C++ Analytics event logging tests passed", false)
		return DebugActionResult.new_success(
			"C++ Analytics event logging tests passed",
			duration,
			action_name,
			{
				"cpp_instance_id": cpp_analytics_instance_id,
				"events_logged": ["basic", "string", "int", "double", "params"]
			}
		)
	else:
		_update_status("❌ C++ Analytics tests failed: " + ", ".join(errors), true)
		return DebugActionResult.new_failure(
			"C++ Analytics event logging tests failed: " + ", ".join(errors),
			"TESTS_FAILED",
			DebugActionResult.ErrorCategory.SYSTEM,
			{"errors": errors},
			duration,
			action_name,
			{"cpp_instance_id": cpp_analytics_instance_id}
		)


func _call_method_safe(obj: Object, method_name: String, args: Array = []) -> bool:
	if not obj.has_method(method_name):
		Log.error(
			"Method not found: " + method_name,
			{"object": obj.get_class(), "method": method_name},
			["debug", "cpp_firebase", "analytics", "error"]
		)
		return false

	var result = obj.callv(method_name, args)

	# For Analytics, fire-and-forget operations return null
	# Success = no crash, method exists and was called
	return true
