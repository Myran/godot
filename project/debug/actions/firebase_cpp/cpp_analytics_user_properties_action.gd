## C++ Analytics: Test user ID and user properties through direct C++ bindings
class_name CPPAnalyticsUserPropertiesAction
extends DebugAction

var cpp_analytics: Object = null
var cpp_analytics_instance_id: int = -1


func _init() -> void:
	super._init()
	action_name = "cpp.firebase.analytics.user_properties"
	set_category("C++ Firebase")
	set_group("Analytics")
	set_description("Test C++ Analytics user ID and user properties")
	category = "C++ Firebase"
	action_callable = Callable(self, "_execute_action_logic")


func get_cpp_analytics() -> Object:
	if cpp_analytics != null and is_instance_valid(cpp_analytics):
		return cpp_analytics

	Log.debug(
		"Creating direct C++ FirebaseAnalytics instance",
		{},
		["debug", "cpp_firebase", "analytics"]
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

	_update_status("Testing set_user_id...")
	if not _call_method_safe(analytics, "set_user_id", ["cpp_test_user_123"]):
		errors.append("set_user_id failed")

	_update_status("Testing set_user_property...")
	if not _call_method_safe(
		analytics, "set_user_property", ["test_account_type", "premium"]
	):
		errors.append("set_user_property failed")

	# Verify user_id was set (is_initialized should return true after set_user_id)
	_update_status("Verifying initialization state...")
	var is_initialized: bool = analytics.call("is_initialized")
	if not is_initialized:
		errors.append("is_initialized check failed after set_user_id")

	var duration: int = Time.get_ticks_msec() - start_time

	if errors.is_empty():
		_update_status("✅ C++ Analytics user properties tests passed", false)
		return DebugActionResult.new_success(
			"C++ Analytics user properties tests passed",
			duration,
			action_name,
			{
				"cpp_instance_id": cpp_analytics_instance_id,
				"is_initialized": is_initialized,
				"user_id": "cpp_test_user_123"
			}
		)
	else:
		_update_status("❌ C++ Analytics user properties tests failed: " + ", ".join(errors), true)
		return DebugActionResult.new_failure(
			"C++ Analytics user properties tests failed: " + ", ".join(errors),
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
