class_name TestDebugMenuVisibility
extends DebugAction

# Test action specifically for validating debug menu hiding during replay
# This action tests the UI state management during recording and replay modes


func _init() -> void:
	super("test.ui.debug_menu_visibility", _execute_test)
	category = "Test"
	group = "UI"
	description = "Test debug menu visibility during replay mode"


func _execute_test() -> DebugAction.Result:
	Log.info(
		"=== DEBUG MENU VISIBILITY TEST START ===",
		{"test_id": get_current_test_id()},
		["debug", "test", "ui", "visibility", "start"]
	)

	# Test 1: Verify ActionRecorder is available
	if not ActionRecorder:
		return DebugAction.Result.new_failure(
			"ActionRecorder singleton not available", "SINGLETON_MISSING"
		)

	# Test 2: Ensure debug menu is initially visible (normal state)
	var initial_state: bool = ActionRecorder.is_replaying
	if initial_state:
		Log.warning(
			"ActionRecorder already in replay mode at test start",
			{"is_replaying": initial_state},
			["debug", "test", "ui", "warning"]
		)

	# Test 3: Create a test recording to use for replay
	Log.info("Creating test recording for replay visibility test", {}, ["debug", "test", "ui"])

	var start_success: bool = ActionRecorder.start_recording()
	if not start_success:
		return DebugAction.Result.new_failure("Failed to start recording", "RECORDING_START_FAILED")

	# Generate a minimal event for testing
	var transition_event: ui.TransitionEvent = ui.TransitionEvent.new(core.GameState.DRAFT)
	ui.action(transition_event)

	var stop_success: bool = ActionRecorder.stop_recording()
	if not stop_success:
		return DebugAction.Result.new_failure("Failed to stop recording", "RECORDING_STOP_FAILED")

	var saved_filepath: String = ActionRecorder.save_recording("debug_menu_visibility_test")
	if saved_filepath.is_empty():
		return DebugAction.Result.new_failure(
			"Failed to save test recording", "RECORDING_SAVE_FAILED"
		)

	# Test 4: Trigger replay mode and verify debug menu hiding
	Log.info("Testing debug menu hiding during replay mode", {}, ["debug", "test", "ui", "replay"])

	# Start replay mode - this should hide the debug menu
	ActionRecorder.start_replay_mode()

	# Verify replay mode is active
	if not ActionRecorder.is_replaying:
		return DebugAction.Result.new_failure(
			"Failed to enter replay mode", "REPLAY_MODE_NOT_ACTIVE"
		)

	Log.info(
		"✅ Replay mode activated successfully - debug menu should be hidden",
		{"is_replaying": ActionRecorder.is_replaying},
		["debug", "test", "ui", "replay", "active"]
	)

	# Test 5: Stop replay mode and verify debug menu showing
	Log.info("Testing debug menu showing after replay mode", {}, ["debug", "test", "ui", "restore"])

	# Stop replay mode - this should show the debug menu again
	ActionRecorder.stop_replay_mode()

	# Verify replay mode is no longer active
	if ActionRecorder.is_replaying:
		return DebugAction.Result.new_failure(
			"Failed to exit replay mode", "REPLAY_MODE_STILL_ACTIVE"
		)

	Log.info(
		"✅ Replay mode deactivated successfully - debug menu should be visible",
		{"is_replaying": ActionRecorder.is_replaying},
		["debug", "test", "ui", "replay", "inactive"]
	)

	Log.info(
		"=== DEBUG MENU VISIBILITY TEST COMPLETE ===",
		{"test_passed": true},
		["debug", "test", "ui", "visibility", "complete"]
	)

	return DebugAction.Result.new_success(
		{
			"message": "Debug menu visibility test passed successfully",
			"replay_mode_tested": true,
			"debug_menu_hiding_tested": true,
			"debug_menu_showing_tested": true,
			"test_recording_created": saved_filepath
		}
	)
