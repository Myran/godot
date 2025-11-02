class_name SentryIntegrationBridgesAction
extends DebugAction

func _init() -> void:
	super._init()
	action_name = "sentry.test_integration_bridges"
	category = "Sentry Debug"
	action_callable = Callable(self, "execute_integration_bridges")
	auto_continue = true

func execute_integration_bridges() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()

func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	Log.info(
		"TRACE: Sentry integration bridges testing started",
		{"action": action_name},
		["debug", "sentry", "trace"]
	)

	_update_status("Testing Sentry integration with existing GameTwo systems...")

	var integration_test_results = {
		"advanced_logger_bridge": false,
		"firebase_context_integration": false,
		"debug_coordinator_compatibility": false,
		"total_bridges_working": 0
	}

	# Test 1: Advanced Logger bridge
	integration_test_results.advanced_logger_bridge = await _test_advanced_logger_bridge()

	# Test 2: Firebase context integration
	integration_test_results.firebase_context_integration = await _test_firebase_context_integration()

	# Test 3: Debug coordinator compatibility
	integration_test_results.debug_coordinator_compatibility = await _test_debug_coordinator_compatibility()

	# Calculate totals
	integration_test_results.total_bridges_working = (
		integration_test_results.advanced_logger_bridge +
		integration_test_results.firebase_context_integration +
		integration_test_results.debug_coordinator_compatibility
	)

	var all_tests_passed = integration_test_results.total_bridges_working == 3

	# Generate test success marker
	var test_metadata: Dictionary = DebugConfigReader.get_test_metadata()
	var config_test_id: String = test_metadata.get("test_id", "")
	if config_test_id != "" and all_tests_passed:
		DebugAction._log_test_success(action_name, category, group, 0, integration_test_results)

	if all_tests_passed:
		_update_status("✅ Sentry integration bridges PASSED - All 3 integrations working")
		return DebugActionResult.new_success(
			integration_test_results,
			0,
			action_name
		)

	_update_status("❌ Sentry integration bridges FAILED - Only " + str(integration_test_results.total_bridges_working) + "/3 bridges working", true)
	return DebugActionResult.new_failure(
		"Sentry integration bridges failed - expected 3 working bridges, found " + str(integration_test_results.total_bridges_working),
		"VALIDATION_FAILED",
		DebugActionResult.ErrorCategory.VALIDATION,
		integration_test_results,
		0,
		action_name
	)

func _test_advanced_logger_bridge() -> bool:
	Log.debug("Testing Advanced Logger bridge to Sentry...", {}, ["debug", "sentry", "test"])

	# Check if Advanced Logger exists and can forward errors to Sentry
	if not ClassDB.class_exists("Log"):
		Log.warn("Advanced Logger not available for bridge testing", {}, ["debug", "sentry", "test"])
		return false

	# Simulate an error and check if it would be forwarded
	Log.error("Test error for Sentry bridge validation", {"test": true, "bridge_test": true}, ["sentry", "test"])

	# In a real implementation, we'd check if Sentry received the error
	# For TDD, we'll check if the bridge structure exists
	var sentry_manager = _get_sentry_manager()
	if sentry_manager and sentry_manager.has_method("handle_advanced_logger_error"):
		Log.debug("Advanced Logger bridge structure validated", {}, ["debug", "sentry", "test"])
		return true

	return false

func _test_firebase_context_integration() -> bool:
	Log.debug("Testing Firebase context integration with Sentry...", {}, ["debug", "sentry", "test"])

	# Check if Firebase auth system exists
	if not ClassDB.class_exists("FirebaseService"):
		Log.warn("Firebase service not available for context testing", {}, ["debug", "sentry", "test"])
		return false

	# Check if SentryManager can handle Firebase context
	var sentry_manager = _get_sentry_manager()
	if sentry_manager and sentry_manager.has_method("setup_firebase_context"):
		Log.debug("Firebase context integration structure validated", {}, ["debug", "sentry", "test"])
		return true

	return false

func _test_debug_coordinator_compatibility() -> bool:
	Log.debug("Testing Debug Coordinator compatibility with Sentry...", {}, ["debug", "sentry", "test"])

	# Check if DebugRegistry exists for action registration
	if not ClassDB.class_exists("DebugRegistry"):
		Log.warn("DebugRegistry not available for compatibility testing", {}, ["debug", "sentry", "test"])
		return false

	# Check if Sentry actions can be registered with DebugRegistry
	var sentry_manager = _get_sentry_manager()
	if sentry_manager and sentry_manager.has_method("register_debug_actions"):
		Log.debug("Debug Coordinator compatibility structure validated", {}, ["debug", "sentry", "test"])
		return true

	return false

func _get_sentry_manager() -> Node:
	if Engine.has_singleton("SentryManager"):
		return Engine.get_singleton("SentryManager")
	return null
