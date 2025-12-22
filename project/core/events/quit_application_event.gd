class_name QuitApplicationEvent extends core.CoreEvent

## Core quit event that centralizes application termination with proper logging synchronization
##
## This event handles all quit scenarios and ensures Android chunk processing completes
## before application termination. It replaces scattered quit logic throughout the codebase
## with a single, reusable quit mechanism.
##
## Usage:
##   core.action(QuitApplicationEvent.new())


func get_serialization_type_name() -> StringName:
	return &"QuitApplicationEvent"


func _init() -> void:
	source = core.EventSource.SYSTEM_CASCADE


## Execute the quit sequence with graceful logger shutdown
func execute() -> void:
	Log.info(
		"QuitApplicationEvent: Starting application termination sequence",
		{
			"platform": OS.get_name(),
			"timestamp": Time.get_unix_time_from_system(),
			"test_id": DebugAction.get_current_test_id()
		},
		["debug", "quit", "core_event"]
	)

	# iOS-specific handling (Task-290): Do not call quit() on iOS as it appears as a crash
	if OS.get_name() == "iOS":
		_handle_ios_quit()
		return

	# Perform common cleanup (Firebase, ConfigManager, Sentry)
	_perform_common_cleanup()

	# Wait for buffer processing completion before logger shutdown (task-236 fix)
	# This ensures all pending log chunks are processed before we shut down the logger
	if OS.get_name() == "Android" and Log.has_method("wait_for_chunk_processing_complete_signal"):
		# Use signal-based chunk processing wait - waits exactly as long as needed
		await Log.wait_for_chunk_processing_complete_signal()

	# Use logger's encapsulated graceful shutdown - handles all platform-specific logic internally
	await Log.shutdown_gracefully()

	# Wait for logcat buffer flush completion after logger shutdown (task-236 fix)
	# CRITICAL: NO print_rich() calls during chunking - they compete with chunked messages
	# Allow chunking to complete cleanly before emitting final marker
	if OS.get_name() == "Android":
		# Wait 3 seconds for Android logcat buffer to flush to system AND chunking to complete
		# This ensures all previous Log.info() messages and their chunked DEBUG_TEST_SUCCESS entries reach logcat
		await (
			Engine
			. get_main_loop()
			. create_timer(GameConstants.NetworkTiming.ANDROID_LOGCAT_FLUSH_DELAY_SEC)
			. timeout
		)

		# NOW emit the final marker - after all chunking has completed and logcat buffer is stable
		print_rich("[DEBUG_TEST_FLUSH_COMPLETE]")

	# Actual application termination (safe for Android and Desktop)
	Engine.get_main_loop().quit()


func _handle_ios_quit() -> void:
	## iOS-specific quit handling for development/testing (Task-290)
	##
	## iOS does not provide an API for gracefully terminating applications.
	## For development/testing purposes, we use _exit(0) which terminates immediately
	## without running cleanup handlers, ensuring the test framework detects completion.
	##
	## Note: This is ONLY used in development/testing workflows, not in production.
	##
	## IMPORTANT: Simplified to avoid hanging awaits - flush_stdout_on_print=true
	## handles log flushing automatically, so we can quit immediately.

	Log.info(
		"QuitApplicationEvent: iOS development/testing termination",
		{
			"platform": "iOS",
			"action": "development_quit",
			"test_id": DebugAction.get_current_test_id(),
			"note": "Using _exit(0) for immediate termination in development/testing"
		},
		["debug", "quit", "ios", "development"]
	)

	# Perform common cleanup (Firebase, ConfigManager, Sentry)
	_perform_common_cleanup()

	# Log final message before quit
	Log.info(
		"QuitApplicationEvent: iOS development quit - calling Firebase.quit_app()",
		{"platform": "iOS", "termination_method": "_exit(0)", "test_completion": true},
		["debug", "quit", "ios", "development"]
	)

	# Emit flush complete marker for test framework verification
	print_rich("[DEBUG_TEST_FLUSH_COMPLETE]")

	# Development/testing termination using Firebase module quit (Task-290)
	# This calls _exit(0) which bypasses cleanup handlers for immediate termination
	# Since flush_stdout_on_print=true, all logs are already flushed to disk
	# Use ClassDB to instantiate the C++ Firebase class (following project pattern)
	var firebase: Object = ClassDB.instantiate("Firebase")
	firebase.quit_app()


func _perform_common_cleanup() -> void:
	## Common cleanup for all platforms before app termination
	## Called by both main quit path and iOS quit path

	# Firebase cleanup (Task-230) - prevents use-after-free crashes
	_perform_firebase_cleanup()

	# ConfigManager cleanup
	SingletonCleanup.cleanup_config_manager()

	# Close Sentry SDK before shutdown to prevent GLThread crash (task-352)
	# Must happen before logger shutdown since SentryGodotLogger is registered with OS
	if Engine.has_singleton("SentrySDK"):
		var sentry: Object = Engine.get_singleton("SentrySDK")
		if sentry.is_enabled():
			sentry.close()


func _perform_firebase_cleanup() -> void:
	## Enhanced Firebase cleanup as final step before app termination
	## This replaces separate debug action approach (Task-230) with integrated cleanup

	# Perform Firebase cleanup on Android and macOS to prevent use-after-free crashes
	if OS.get_name() != "Android" and OS.get_name() != "macOS":
		Log.debug(
			"QuitApplicationEvent: Skipping Firebase cleanup on non-Android/non-macOS platform",
			{"platform": OS.get_name()},
			["debug", "quit", "firebase"]
		)
		return

	Log.info(
		"QuitApplicationEvent: Performing Firebase cleanup (test isolation & crash prevention)",
		{"platform": OS.get_name()},
		["debug", "quit", "firebase"]
	)

	# Call FirebaseService cleanup method if available (GDScript layer)
	if FirebaseService != null and FirebaseService.has_method("shutdown_firebase_connections"):
		# GDScript doesn't have try-catch, use conditional safety checks
		FirebaseService.shutdown_firebase_connections()
		Log.info(
			"QuitApplicationEvent: FirebaseService cleanup completed successfully",
			{"platform": OS.get_name()},
			["debug", "quit", "firebase"]
		)
	else:
		Log.debug(
			"QuitApplicationEvent: FirebaseService not available or missing cleanup method",
			{"platform": OS.get_name()},
			["debug", "quit", "firebase"]
		)

	# Also call native Firebase cleanup (C++ layer) to prevent use-after-free
	# This is critical for macOS where Firebase callbacks in CallQueue can crash during shutdown
	var firebase: Object = ClassDB.instantiate("Firebase")
	if firebase != null and firebase.has_method("cleanup_firebase"):
		firebase.cleanup_firebase()
		Log.info(
			"QuitApplicationEvent: Native Firebase cleanup completed successfully",
			{"platform": OS.get_name()},
			["debug", "quit", "firebase"]
		)
	else:
		Log.debug(
			"QuitApplicationEvent: Native Firebase cleanup method not available",
			{"platform": OS.get_name()},
			["debug", "quit", "firebase"]
		)
