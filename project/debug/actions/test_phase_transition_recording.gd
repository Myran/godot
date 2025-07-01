extends DebugAction

class_name TestPhaseTransitionRecording

# Test for phase transition recording and replay validation


func _init() -> void:
	super("test.phase.transition_recording", _execute_phase_transition_test)
	set_category("Test")
	set_group("Action Recording")
	set_description("Test phase transition recording (draft→prepare)")


func _execute_phase_transition_test() -> DebugAction.Result:
	Log.info(
		"=== Phase Transition Recording Test Started ===", {}, ["debug", "test", "phase_transition"]
	)

	var success: bool = true

	# Test 1: Verify ui.TransitionEvent can be recorded
	success = success and _test_transition_event_recording()

	# Test 2: Test specific draft→prepare transition
	success = success and _test_draft_to_prepare_transition()

	Log.info(
		"=== Phase Transition Recording Test Complete ===",
		{"success": success},
		["debug", "test", "phase_transition"]
	)

	if success:
		return DebugAction.Result.new_success(
			{"phase_transition_test": "All phase transition tests passed"},
			0,
			"phase_transition_test_complete"
		)
	else:
		return DebugAction.Result.new_failure(
			"Phase transition tests failed", "PHASE_TRANSITION_TEST_FAILED"
		)


func _test_transition_event_recording() -> bool:
	Log.info("Testing ui.TransitionEvent recording...", {}, ["debug", "test", "phase_transition"])

	var original: ui.TransitionEvent = ui.TransitionEvent.new(core.GameState.PREPARE)
	var recorded: RecordedAction = RecordedAction.new(original, 1)
	var deserialized: Context.Event = recorded.deserialize_event()

	if not deserialized is ui.TransitionEvent:
		Log.error(
			"TransitionEvent type mismatch",
			{"expected": "ui.TransitionEvent", "actual": deserialized.get_class()},
			["debug", "test", "error"]
		)
		return false

	var result: ui.TransitionEvent = deserialized

	# Verify phase transition properties
	if result.new_state != original.new_state:
		Log.error(
			"TransitionEvent.new_state mismatch",
			{"expected": original.new_state, "actual": result.new_state},
			["debug", "test", "error"]
		)
		return false

	if result.source != original.source:
		Log.error(
			"TransitionEvent.source mismatch",
			{"expected": original.source, "actual": result.source},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"ui.TransitionEvent recording validated",
		{"new_state": result.new_state, "source": result.source},
		["debug", "test", "phase_transition"]
	)
	return true


func _test_draft_to_prepare_transition() -> bool:
	Log.info("Testing draft→prepare phase transition...", {}, ["debug", "test", "phase_transition"])

	# Create the exact transition used in bottom_bar_draft.gd
	var draft_to_prepare: ui.TransitionEvent = ui.TransitionEvent.new(core.GameState.PREPARE)
	var recorded: RecordedAction = RecordedAction.new(draft_to_prepare, 2)
	var deserialized: Context.Event = recorded.deserialize_event()

	if not deserialized is ui.TransitionEvent:
		Log.error(
			"Draft→Prepare transition type mismatch",
			{"expected": "ui.TransitionEvent", "actual": deserialized.get_class()},
			["debug", "test", "error"]
		)
		return false

	var result: ui.TransitionEvent = deserialized

	# Verify this is specifically the draft→prepare transition
	if result.new_state != core.GameState.PREPARE:
		Log.error(
			"Draft→Prepare transition state mismatch",
			{"expected": core.GameState.PREPARE, "actual": result.new_state},
			["debug", "test", "error"]
		)
		return false

	if result.source != core.EventSource.PLAYER:
		Log.error(
			"Draft→Prepare transition source mismatch",
			{"expected": core.EventSource.PLAYER, "actual": result.source},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"Draft→Prepare transition validated",
		{"target_state": "PREPARE", "source": "PLAYER"},
		["debug", "test", "phase_transition"]
	)
	return true
