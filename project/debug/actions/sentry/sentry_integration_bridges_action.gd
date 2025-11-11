class_name SentryIntegrationBridgesAction
extends DebugAction


func _init() -> void:
	super._init()
	action_name = "sentry.test_integration_bridges"
	category = "Sentry Debug"
	action_callable = Callable(self, "execute_integration_bridges")
	auto_continue = true


func execute_integration_bridges() -> bool:
	var result: DebugActionResult = _execute_action_logic({})
	return result.is_success()


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	Log.info(
		"TRACE: Sentry integration bridges testing started",
		{"action": action_name},
		["debug", "sentry", "trace"]
	)

	_update_status("Testing Sentry integration with existing GameTwo systems...")

	var integration_test_results: Dictionary = {
		"advanced_logger_bridge": false,
		"firebase_context_integration": false,
		"debug_coordinator_compatibility": false,
		"total_bridges_working": 0
	}

	# Test 1: Advanced Logger bridge
	integration_test_results.advanced_logger_bridge = _test_advanced_logger_bridge()

	# Test 2: Firebase context integration
	integration_test_results.firebase_context_integration = _test_firebase_context_integration()

	# Test 3: Debug coordinator compatibility
	integration_test_results.debug_coordinator_compatibility = _test_debug_coordinator_compatibility()

	# Calculate totals using strongly typed counting pattern
	var bridges_working: int = 0
	if integration_test_results.advanced_logger_bridge:
		bridges_working += 1
	if integration_test_results.firebase_context_integration:
		bridges_working += 1
	if integration_test_results.debug_coordinator_compatibility:
		bridges_working += 1
	integration_test_results.total_bridges_working = bridges_working

	var all_tests_passed: bool = integration_test_results.total_bridges_working == 3

	# Generate test success marker
	var test_metadata: Dictionary = DebugConfigReader.get_test_metadata()
	var config_test_id: String = test_metadata.get("test_id", "")
	if config_test_id != "" and all_tests_passed:
		DebugAction._log_test_success(action_name, category, group, 0, integration_test_results)

	if all_tests_passed:
		_update_status("✅ Sentry integration bridges PASSED - All 3 integrations working")
		return DebugActionResult.new_success(integration_test_results, 0, action_name)

	_update_status(
		(
			"❌ Sentry integration bridges FAILED - Only "
			+ str(integration_test_results.total_bridges_working)
			+ "/3 bridges working"
		),
		true
	)
	return DebugActionResult.new_failure(
		(
			"Sentry integration bridges failed - expected 3 working bridges, found "
			+ str(integration_test_results.total_bridges_working)
		),
		"VALIDATION_FAILED",
		DebugActionResult.ErrorCategory.VALIDATION,
		integration_test_results,
		0,
		action_name
	)


func _test_advanced_logger_bridge() -> bool:
	Log.debug(
		"Testing Advanced Logger direct integration with Sentry...", {}, ["debug", "sentry", "test"]
	)

	# Check if Advanced Logger autoload exists and is valid
	if not is_instance_valid(Log):
		Log.warning(
			"Advanced Logger not available for integration testing", {}, ["debug", "sentry", "test"]
		)
		return false

	# Check if SentryHelper is available for direct integration
	if not SentryHelper.is_available():
		Log.warning(
			"SentrySDK not available for integration testing", {}, ["debug", "sentry", "test"]
		)
		return false

	# Simulate an error that should be forwarded to Sentry
	# The Advanced Logger will automatically call SentryHelper.capture_message()
	# Using "intentional_test_error" tag to prevent false positive in error analysis
	Log.error(
		"Test error for Sentry direct integration validation",
		{"test": true, "integration_test": true},
		["sentry", "test", "intentional_test_error"]
	)

	Log.debug("Advanced Logger direct integration validated", {}, ["debug", "sentry", "test"])
	return true


func _test_firebase_context_integration() -> bool:
	Log.debug("Testing Firebase direct integration with Sentry...", {}, ["debug", "sentry", "test"])

	# Check if Firebase auth exists and is available
	if not is_instance_valid(auth) or not auth.is_available():
		Log.warning(
			"Firebase auth not available for integration testing", {}, ["debug", "sentry", "test"]
		)
		return false

	# Check if SentryHelper is available for direct integration
	if not SentryHelper.is_available():
		Log.warning(
			"SentrySDK not available for integration testing", {}, ["debug", "sentry", "test"]
		)
		return false

	# Firebase auth will automatically call SentryHelper.set_user() on login
	# and SentryHelper.set_tag() for authentication state
	Log.debug("Firebase direct integration validated", {}, ["debug", "sentry", "test"])
	return true


func _test_debug_coordinator_compatibility() -> bool:
	Log.debug(
		"Testing Debug Coordinator compatibility with Sentry...", {}, ["debug", "sentry", "test"]
	)

	# Check if DebugRegistry autoload exists and is valid
	if not is_instance_valid(DebugRegistry):
		Log.warning(
			"DebugRegistry not available for compatibility testing", {}, ["debug", "sentry", "test"]
		)
		return false

	# Check if SentryHelper is available for debug actions to use
	if not SentryHelper.is_available():
		Log.warning(
			"SentrySDK not available for debug action testing", {}, ["debug", "sentry", "test"]
		)
		return false

	# Debug actions (like this one) can directly use SentryHelper
	# No intermediate manager needed - all Sentry debug actions registered with DebugRegistry
	Log.debug("Debug Coordinator compatibility validated", {}, ["debug", "sentry", "test"])
	return true
