## C++ Analytics: Test configuration methods (collection enabled, reset, timeout)
class_name CPPAnalyticsConfigAction
extends DebugAction

var cpp_analytics: Object = null
var cpp_analytics_instance_id: int = -1


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.analytics.config"
	set_category("C++ Firebase")
	set_group("Analytics")
	set_description("Test C++ Analytics configuration methods")
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

	_update_status("Testing set_analytics_collection_enabled (true)...")
	if not _call_method_safe(analytics, "set_analytics_collection_enabled", [true]):
		errors.append("set_analytics_collection_enabled true failed")

	_update_status("Testing set_analytics_collection_enabled (false)...")
	if not _call_method_safe(analytics, "set_analytics_collection_enabled", [false]):
		errors.append("set_analytics_collection_enabled false failed")

	# Re-enable for other tests
	_update_status("Re-enabling collection...")
	_call_method_safe(analytics, "set_analytics_collection_enabled", [true])

	_update_status("Testing set_session_timeout_duration...")
	if not _call_method_safe(analytics, "set_session_timeout_duration", [1800000]):
		errors.append("set_session_timeout_duration failed")

	_update_status("Testing reset_analytics_data...")
	if not _call_method_safe(analytics, "reset_analytics_data"):
		errors.append("reset_analytics_data failed")

	var duration: int = Time.get_ticks_msec() - start_time

	if errors.is_empty():
		_update_status("✅ C++ Analytics configuration tests passed", false)
		return DebugActionResult.new_success(
			"C++ Analytics configuration tests passed",
			duration,
			action_name,
			{
				"cpp_instance_id": cpp_analytics_instance_id,
				"tested_methods":
				[
					"set_analytics_collection_enabled",
					"set_session_timeout_duration",
					"reset_analytics_data"
				]
			}
		)
	else:
		_update_status("❌ C++ Analytics configuration tests failed: " + ", ".join(errors), true)
		return DebugActionResult.new_failure(
			"C++ Analytics configuration tests failed: " + ", ".join(errors),
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

	obj.callv(method_name, args)
	return true
