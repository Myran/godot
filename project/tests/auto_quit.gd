extends Node

var max_test_time: float = 60.0  # Maximum seconds to allow a test to run


func _ready() -> void:
	get_tree().create_timer(max_test_time).timeout.connect(
		func() -> void:
			Log.warning(
				"Auto-quitting test after timeout", {"max_seconds": max_test_time}, [Log.TAG_TEST]
			)
			_safe_auto_quit_timeout()
	)


func complete_test() -> void:
	Log.info("Test completed successfully, exiting...", {}, [Log.TAG_TEST])
	_safe_auto_quit_complete()


func fail_test(reason: String) -> void:
	Log.error("Test failed: " + reason, {}, [Log.TAG_TEST, Log.TAG_ERROR])
	_safe_auto_quit_fail(reason)


# CRITICAL: Safe auto-quit - waits ONLY for logger completion
# Uses print() instead of Log.* to avoid circular dependency
func _safe_auto_quit_timeout() -> void:
	print("[AUTO_QUIT] Timeout quit - waiting for logger completion")
	_wait_for_logger_and_quit("timeout")


func _safe_auto_quit_complete() -> void:
	print("[AUTO_QUIT] Success quit - waiting for logger completion")
	_wait_for_logger_and_quit("success")


func _safe_auto_quit_fail(reason: String) -> void:
	print("[AUTO_QUIT] Failure quit - waiting for logger completion: ", reason)
	_wait_for_logger_and_quit("failure")


func _wait_for_logger_and_quit(quit_type: String) -> void:
	# ONLY wait for logger - no action queue checks, no Log.* calls
	var is_android: bool = OS.get_name() == "Android"

	print("[AUTO_QUIT] Platform: ", OS.get_name(), " | Quit type: ", quit_type)

	# Wait for logger completion on Android
	if is_android and Log.has_method("wait_for_chunk_processing_complete_signal"):
		if Log.has_method("has_pending_android_chunks") and Log.has_pending_android_chunks():
			var pending_count: int = (
				Log.get_android_chunk_count() if Log.has_method("get_android_chunk_count") else 0
			)
			print(
				"[AUTO_QUIT] Android detected with ", pending_count, " pending chunks - waiting..."
			)

			# Wait for logger signal-based completion
			await Log.wait_for_chunk_processing_complete_signal()

			print("[AUTO_QUIT] Logger chunk processing completed")
		else:
			print("[AUTO_QUIT] No pending Android chunks - proceeding immediately")
	elif is_android:
		print("[AUTO_QUIT] Android detected but logger methods unavailable - proceeding anyway")
	else:
		print("[AUTO_QUIT] Desktop platform - no logger wait needed")

	print_rich("[AUTO_QUIT] Logger sync complete - executing quit")

	# Wait 1 second to allow print buffer to flush to logcat
	# This prevents the final marker from being dropped due to buffer overflow
	await get_tree().create_timer(1.0).timeout

	# Emit final marker for test framework to detect flush completion
	# This marker appears AFTER all logger chunks are processed and flushed
	# Use print_rich() which goes through same mechanism as Log system (works on Android)
	print_rich("[DEBUG_TEST_FLUSH_COMPLETE]")

	# Wait another 1 second for the marker print to flush before quitting
	# Quitting immediately would prevent the marker from reaching logcat
	await get_tree().create_timer(1.0).timeout

	# Now safe to quit
	if quit_type == "failure":
		get_tree().quit(1)
	else:
		get_tree().quit(0)
