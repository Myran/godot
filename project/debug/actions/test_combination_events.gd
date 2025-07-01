class_name TestCombinationEvents
extends DebugAction

# Simple combination events test action
# Tests basic interactions between different event types


func _init() -> void:
	super("test.recording.simple_combination", _execute_simple_combination_test)
	category = "Test"
	group = "Recording"
	description = "Test simple combination of events with state transitions"


func _execute_simple_combination_test() -> DebugAction.Result:
	Log.info(
		"=== SIMPLE COMBINATION EVENTS TEST START ===",
		{"test_id": DebugAction.get_current_test_id()},
		["debug", "test", "recording", "combination", "start"]
	)

	# Simple test: Record a few events in sequence
	var test_result: DebugAction.Result = _test_simple_event_sequence()
	if not test_result.is_success():
		return test_result

	Log.info(
		"=== SIMPLE COMBINATION EVENTS TEST COMPLETE ===",
		{"test_passed": true},
		["debug", "test", "recording", "combination", "complete"]
	)

	return DebugAction.Result.new_success(
		{"message": "Simple combination events test passed successfully", "test_completed": true}
	)


func _test_simple_event_sequence() -> DebugAction.Result:
	Log.info(
		"Testing simple event sequence recording",
		{},
		["debug", "test", "recording", "combination", "simple"]
	)

	# Start recording
	if not ActionRecorder.start_recording():
		return DebugAction.Result.new_failure("Failed to start recording", "RECORDING_START_FAILED")

	# Execute a simple sequence: state transition + reroll + state transition back
	var to_draft: ui.TransitionEvent = ui.TransitionEvent.new(core.GameState.DRAFT)
	ui.action(to_draft)

	var reroll_event: core.RerollDraftEvent = core.RerollDraftEvent.new()
	core.action(reroll_event)

	var to_prepare: ui.TransitionEvent = ui.TransitionEvent.new(core.GameState.PREPARE)
	ui.action(to_prepare)

	# Stop recording
	if not ActionRecorder.stop_recording():
		return DebugAction.Result.new_failure("Failed to stop recording", "RECORDING_STOP_FAILED")

	# Save recording
	var saved_filepath: String = ActionRecorder.save_recording("simple_combination_test")
	if saved_filepath.is_empty():
		return DebugAction.Result.new_failure("Failed to save recording", "RECORDING_SAVE_FAILED")

	# Verify recording stats
	var stats: Dictionary = ActionRecorder.get_recording_stats()
	if stats.get("total_actions", 0) != 3:
		return DebugAction.Result.new_failure(
			"Expected 3 actions, got " + str(stats.get("total_actions", 0)),
			"INCORRECT_ACTION_COUNT"
		)

	Log.info(
		"✅ Simple event sequence test passed",
		{"actions_recorded": stats.total_actions, "filepath": saved_filepath},
		["debug", "test", "recording", "combination"]
	)
	return DebugAction.Result.new_success(
		{
			"message": "Simple event sequence test passed",
			"actions_recorded": stats.total_actions,
			"saved_filepath": saved_filepath
		}
	)
