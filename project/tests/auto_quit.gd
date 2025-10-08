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


# CRITICAL FIX: Safe auto-quit mechanisms that prevent race conditions
func _safe_auto_quit_timeout() -> void:
	Log.info(
		"SAFE_AUTO_QUIT_TIMEOUT: Ensuring all actions complete before timeout quit",
		{"timeout_seconds": max_test_time},
		[Log.TAG_TEST, "auto_quit", "safety"]
	)
	_wait_for_actions_and_quit("timeout")


func _safe_auto_quit_complete() -> void:
	Log.info(
		"SAFE_AUTO_QUIT_COMPLETE: Ensuring all actions complete before success quit",
		{},
		[Log.TAG_TEST, "auto_quit", "safety"]
	)
	_wait_for_actions_and_quit("success")


func _safe_auto_quit_fail(reason: String) -> void:
	Log.error(
		"SAFE_AUTO_QUIT_FAIL: Test failed, ensuring safe quit",
		{"failure_reason": reason},
		[Log.TAG_TEST, "auto_quit", "failure"]
	)
	_wait_for_actions_and_quit("failure")


func _wait_for_actions_and_quit(quit_type: String) -> void:
	# ENHANCED: Wait for ALL queued actions, executing actions, AND logger completion
	var main_node: Node = Engine.get_main_loop().current_scene
	var game_node: Game = main_node.get_node_or_null("Game") if main_node else null
	var is_android: bool = OS.get_name() == "Android"
	var max_wait_frames: int = 60  # Prevent infinite wait (1 second at 60fps)
	var action_wait_frames: int = 0
	var logger_wait_time: float = 0.0
	var logger_timeout: float = 5.0  # 5 second timeout for logger completion

	Log.info(
		"AUTO_QUIT_ENHANCED_SAFETY_CHECK: %s quit - comprehensive completion check",
		{
			"quit_type": quit_type,
			"platform": OS.get_name(),
			"game_node_exists": game_node != null,
			"android_detected": is_android
		},
		[Log.TAG_TEST, "auto_quit", "enhanced_safety"]
	)

	# Step 1: Wait for ALL actions to complete (queued + executing)
	if game_node:
		while game_node._idle_action_queue.size() > 0 or game_node._processing_idle_action:
			action_wait_frames += 1
			if action_wait_frames >= max_wait_frames:
				Log.warning(
					"AUTO_QUIT_ACTION_TIMEOUT: Maximum action wait exceeded",
					{
						"action_wait_frames": action_wait_frames,
						"queue_size": game_node._idle_action_queue.size(),
						"processing_idle": game_node._processing_idle_action
					},
					[Log.TAG_TEST, "auto_quit", "timeout", "warning"]
				)
				break
			await Engine.get_main_loop().process_frame

	# Step 2: CRITICAL - Wait for logger completion on Android
	if is_android and Log.has_method("wait_for_chunk_processing_complete_signal"):
		logger_wait_time = Time.get_ticks_msec() / 1000.0

		if Log.has_method("has_pending_android_chunks") and Log.has_pending_android_chunks():
			(
				Log
				. info(
					"AUTO_QUIT_LOGGER_SYNC: Android detected with pending chunks, waiting for logger completion",
					{
						"pending_chunks":
						(
							str(Log.get_android_chunk_count())
							if Log.has_method("get_android_chunk_count")
							else "unknown"
						),
						"logger_wait_start": logger_wait_time
					},
					[Log.TAG_TEST, "auto_quit", "logger_sync", "android"]
				)
			)

			# Use signal-based logger completion (preferred method)
			await Log.wait_for_chunk_processing_complete_signal()

			logger_wait_time = (Time.get_ticks_msec() / 1000.0) - logger_wait_time

			Log.info(
				"AUTO_QUIT_LOGGER_COMPLETE: Android chunk processing completed",
				{
					"logger_wait_time_seconds": logger_wait_time,
					"final_chunk_count":
					(
						str(Log.get_android_chunk_count())
						if Log.has_method("get_android_chunk_count")
						else "unknown"
					),
					"all_chunks_processed": not Log.has_pending_android_chunks()
				},
				[Log.TAG_TEST, "auto_quit", "logger_complete", "android"]
			)
		else:
			Log.info(
				"AUTO_QUIT_LOGGER_NOT_NEEDED: No pending Android chunks, proceeding with quit",
				{"pending_chunks": 0},
				[Log.TAG_TEST, "auto_quit", "logger_sync", "android"]
			)
	elif is_android:
		# Fallback for Android if logger methods not available
		Log.warning(
			"AUTO_QUIT_LOGGER_FALLBACK: Android detected but logger methods not available",
			{"has_pending_check": Log.has_method("has_pending_android_chunks")},
			[Log.TAG_TEST, "auto_quit", "logger_fallback", "warning"]
		)

	(
		Log
		. info(
			"AUTO_QUIT_FULLY_SAFE: All actions AND logger processing completed - proceeding with %s quit",
			{
				"quit_type": quit_type,
				"action_wait_frames": action_wait_frames,
				"logger_wait_time_seconds": logger_wait_time,
				"platform": OS.get_name()
			},
			[Log.TAG_TEST, "auto_quit", "fully_safe"]
		)
	)

	# Step 3: Now completely safe to quit
	if quit_type == "failure":
		get_tree().quit(1)
	else:
		get_tree().quit(0)
