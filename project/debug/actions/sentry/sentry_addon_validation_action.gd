class_name SentryAddonValidationAction
extends DebugAction


func _init() -> void:
	super._init()
	action_name = "sentry.validate_gdextension_loading"
	category = "Sentry Debug"
	action_callable = Callable(self, "execute_gdextension_validation")
	auto_continue = true


func execute_gdextension_validation() -> bool:
	var result: DebugActionResult = _execute_action_logic({})
	return result.is_success()


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	Log.info(
		"TRACE: Sentry GDExtension validation started",
		{"action": action_name},
		["debug", "sentry", "trace"]
	)

	_update_status("Validating Sentry GDExtension loading...")

	var test_results: Dictionary = {
		"sentry_gdextension_exists": false,
		"sentry_native_binaries_exist": false,
		"sentry_sdk_class_available": false
	}

	# Test 1: Check GDExtension file exists
	test_results.sentry_gdextension_exists = FileAccess.file_exists(
		"res://addons/sentry/sentry.gdextension"
	)

	# Test 2: Check native libraries exist for current platform
	var current_platform: String = OS.get_name()
	if current_platform == "macOS":
		test_results.sentry_native_binaries_exist = (
			FileAccess.file_exists("res://addons/sentry/bin/macos/Sentry.framework/Sentry")
			and (
				FileAccess
				. file_exists(
					"res://addons/sentry/bin/macos/libsentry.macos.debug.framework/libsentry.macos.debug"
				)
			)
		)
	elif current_platform == "Android":
		# Check multiple possible paths for Android binaries
		var debug_path: String = "res://addons/sentry/bin/android/libsentry.android.debug.arm64.so"
		var release_path: String = "res://addons/sentry/bin/android/libsentry.android.release.arm64.so"

		# Debug: Log the paths we're checking
		Log.info(
			"Android GDExtension path validation",
			{
				"debug_path": debug_path,
				"debug_exists": FileAccess.file_exists(debug_path),
				"release_path": release_path,
				"release_exists": FileAccess.file_exists(release_path)
			},
			["debug", "sentry", "trace"]
		)

		test_results.sentry_native_binaries_exist = (
			FileAccess.file_exists(debug_path) or FileAccess.file_exists(release_path)
		)
	elif current_platform == "iOS":
		test_results.sentry_native_binaries_exist = (
			FileAccess.file_exists("res://addons/sentry/bin/ios/libsentry.ios.debug.xcframework")
			or FileAccess.file_exists(
				"res://addons/sentry/bin/ios/libsentry.ios.release.xcframework"
			)
		)
	elif current_platform == "Windows":
		var debug_path: String = "res://addons/sentry/bin/windows/x86_64/libsentry.windows.debug.x86_64.dll"
		var release_path: String = "res://addons/sentry/bin/windows/x86_64/libsentry.windows.release.x86_64.dll"

		Log.info(
			"Windows GDExtension path validation",
			{
				"debug_path": debug_path,
				"debug_exists": FileAccess.file_exists(debug_path),
				"release_path": release_path,
				"release_exists": FileAccess.file_exists(release_path)
			},
			["debug", "sentry", "trace"]
		)

		test_results.sentry_native_binaries_exist = (
			FileAccess.file_exists(debug_path) or FileAccess.file_exists(release_path)
		)

	# Test 3: Check if SentrySDK global class is available (will be tested in integration test)
	# This requires the game to actually run, so we'll check in a separate test
	test_results.sentry_sdk_class_available = ClassDB.class_exists("SentrySDK")

	# Enhanced validation: If SentrySDK is available, GDExtension must be working
	# On Android/Windows, file access patterns may differ, so prioritize functional validation
	if current_platform in ["Android", "Windows"] and test_results.sentry_sdk_class_available:
		# If SentrySDK class exists and is accessible, GDExtension must be loaded
		# This is a more reliable indicator than file path checks on Android
		test_results.native_binaries_functional = true
		Log.info(
			current_platform + " functional validation: SentrySDK available implies GDExtension loaded",
			{"sentrysdk_available": test_results.sentry_sdk_class_available, "platform": current_platform},
			["debug", "sentry", "trace"]
		)

	# Log test results for debugging
	Log.info("GDExtension validation test results", test_results, ["debug", "sentry", "trace"])

	# Updated validation logic for platform-specific behaviors
	var all_tests_passed: bool = (
		test_results.sentry_gdextension_exists
		and (
			test_results.sentry_native_binaries_exist
			or (
				test_results.native_binaries_functional
				if test_results.has("native_binaries_functional")
				else false
			)
		)
		and test_results.sentry_sdk_class_available
	)

	# Generate test success marker if all tests pass
	var test_metadata: Dictionary = DebugConfigReader.get_test_metadata()
	var config_test_id: String = test_metadata.get("test_id", "")
	if config_test_id != "" and all_tests_passed:
		DebugAction._log_test_success(action_name, category, group, 0, test_results)

	if all_tests_passed:
		_update_status("✅ Sentry GDExtension validation PASSED")
		return DebugActionResult.new_success(test_results, 0, action_name)

	_update_status("❌ Sentry GDExtension validation FAILED", true)
	return DebugActionResult.new_failure(
		"Sentry GDExtension validation failed - missing components",
		"VALIDATION_FAILED",
		DebugActionResult.ErrorCategory.VALIDATION,
		test_results,
		0,
		action_name
	)


# Helper methods for GDExtension validation
func _get_implementation_notes(conditions: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var current_platform: String = OS.get_name()

	if not conditions.sentry_gdextension_exists:
		(
			notes
			. append(
				"❌ MISSING: res://addons/sentry/sentry.gdextension - Sentry GDExtension manifest not found"
			)
		)

	if not conditions.sentry_native_binaries_exist:
		notes.append(
			(
				"❌ MISSING: Native libraries not found for "
				+ current_platform
				+ " - Run 'just sentry-build-desktop' to build"
			)
		)

	if notes.is_empty():
		notes.append(
			"✅ All GDExtension validation conditions satisfied - Sentry SDK ready for testing"
		)

	return notes
