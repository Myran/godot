class_name SentryIntegrationTestAction
extends DebugAction

func _init() -> void:
	super._init()
	action_name = "sentry.test_sdk_functionality"
	category = "Sentry Debug"
	action_callable = Callable(self, "execute_sdk_test")
	auto_continue = true

func execute_sdk_test() -> bool:
	var result: DebugActionResult = await _execute_action_logic({})
	return result.is_success()

func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	Log.info(
		"TRACE: Sentry SDK integration test started",
		{"action": action_name},
		["debug", "sentry", "trace"]
	)

	_update_status("Testing Sentry SDK integration...")

	var test_results = {
		"sentrysdk_class_available": false,
		"sentrysdk_singleton_accessible": false,
		"sentry_init_method_works": false,
		"sentry_capture_message_works": false
	}

	# Test 1: Check if SentrySDK class is available
	test_results.sentrysdk_class_available = ClassDB.class_exists("SentrySDK")

	# Test 2: Check if SentrySDK singleton is accessible
	if test_results.sentrysdk_class_available:
		# Try to access the SentrySDK singleton
		var sentry_sdk = Engine.get_singleton("SentrySDK")
		test_results.sentrysdk_singleton_accessible = sentry_sdk != null

		# Test 3: Try calling init method
		if test_results.sentrysdk_singleton_accessible:
			# Test actual Sentry functionality - let it fail if not working

			# Test 3: Try init method (will fail if API is wrong)
			sentry_sdk.init(func(options: SentryOptions) -> void:
				options.dsn = "https://test@test.ingest.sentry.io/123456"
				options.debug = true
				options.environment = "test"
			)
			test_results.sentry_init_method_works = true

			# Test 4: Try configure method
			sentry_sdk.capture_message("Test message from GameTwo")
			test_results.sentry_capture_message_works = true

	# Log test results for debugging
	Log.info(
		"Sentry SDK integration test results",
		test_results,
		["debug", "sentry", "trace"]
	)

	var all_tests_passed = (
		test_results.sentrysdk_class_available and
		test_results.sentrysdk_singleton_accessible and
		test_results.sentry_init_method_works and
		test_results.sentry_capture_message_works
	)

	# Generate test success marker if all tests pass
	var test_metadata: Dictionary = DebugConfigReader.get_test_metadata()
	var config_test_id: String = test_metadata.get("test_id", "")
	if config_test_id != "" and all_tests_passed:
		DebugAction._log_test_success(action_name, category, group, 0, test_results)

	if all_tests_passed:
		_update_status("✅ Sentry SDK integration test PASSED")
		return DebugActionResult.new_success(
			test_results,
			0,
			action_name
		)

	_update_status("❌ Sentry SDK integration test FAILED", true)
	return DebugActionResult.new_failure(
		"Sentry SDK integration test failed - some functionality not working",
		"INTEGRATION_FAILED",
		DebugActionResult.ErrorCategory.VALIDATION,
		test_results,
		0,
		action_name
	)


# Helper methods for integration test analysis
func _get_implementation_notes(conditions: Dictionary) -> Array[String]:
	var notes: Array[String] = []

	if not conditions.sentrysdk_class_available:
		notes.append("❌ MISSING: SentrySDK class not available - GDExtension not loaded properly")

	if not conditions.sentrysdk_singleton_accessible:
		notes.append("❌ MISSING: SentrySDK singleton not accessible - GDExtension registration failed")

	if not conditions.sentry_init_method_works:
		notes.append("❌ FAILED: SentrySDK.init() method not working")

	if not conditions.sentry_capture_message_works:
		notes.append("❌ FAILED: SentrySDK.capture_message() method not working")

	if notes.is_empty():
		notes.append("✅ All Sentry SDK integration tests passed - Sentry is fully functional")

	return notes