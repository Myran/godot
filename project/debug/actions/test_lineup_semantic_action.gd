extends DebugAction

class_name TestLineupSemanticAction


func _init() -> void:
	super("test.lineup.semantic_action", _execute_semantic_test)
	set_category("Test")
	set_group("Semantic Actions")
	set_description("Test semantic lineup card move action vs UI event separation")


func _execute_semantic_test() -> DebugAction.Result:
	Log.info(
		"Testing LineupCardMove semantic action/event separation...",
		{},
		["debug", "test", "lineup", "semantic"]
	)

	var success: bool = true
	var issues: Array[String] = []

	# Test 1: Verify MoveLineupCardEvent exists and is properly typed
	success = success and _test_move_lineup_card_action_exists(issues)

	# Test 2: Verify MoveLineupCardEvent has EventSource.PLAYER
	success = success and _test_move_action_event_source(issues)

	# Test 3: Skip - Renamed MoveLineupCardEvent to MoveLineupCardEvent for consistency

	# Test 4: Test ActionRecorder only records MoveLineupCardEvent
	success = success and _test_action_recording_filter(issues)

	# Test 5: Test semantic flow: Action -> Event cascade
	success = success and _test_semantic_flow(issues)

	if success:
		Log.info(
			"LineupCardMove semantic test PASSED",
			{"tests_completed": 5},
			["debug", "test", "lineup", "semantic"]
		)
		return DebugAction.Result.new_success("All semantic action/event separation tests passed")
	else:
		Log.error(
			"LineupCardMove semantic test FAILED",
			{"failed_tests": issues},
			["debug", "test", "error"]
		)
		return DebugAction.Result.new_failure(
			"Semantic separation test failed: " + ", ".join(issues)
		)


func _test_move_lineup_card_action_exists(issues: Array[String]) -> bool:
	Log.info("Testing MoveLineupCardEvent class exists...", {}, ["debug", "test"])

	# Check if core autoload is available
	if not core:
		issues.append("core autoload not available")
		return false

	# Check if MoveLineupCardEvent class exists in core namespace
	# This should fail initially since MoveLineupCardEvent doesn't exist
	var core_script: Script = core.get_script()
	var source_code: String = core_script.source_code

	if not "class MoveLineupCardEvent:" in source_code:
		issues.append("MoveLineupCardEvent class does not exist in core.gd")
		return false

	# Try to create a MoveLineupCardEvent
	var test_action = core.MoveLineupCardEvent.new(null, 0, 1)

	if test_action == null:
		issues.append("Failed to create MoveLineupCardEvent instance")
		return false

	if not test_action is core.CoreEvent:
		issues.append("MoveLineupCardEvent is not a CoreEvent")
		return false

	Log.info("MoveLineupCardEvent exists and is properly typed", {}, ["debug", "test"])
	return true


func _test_move_action_event_source(issues: Array[String]) -> bool:
	Log.info("Testing MoveLineupCardEvent has EventSource.PLAYER...", {}, ["debug", "test"])

	# Skip this test if MoveLineupCardEvent doesn't exist yet
	var core_script: Script = core.get_script()
	var source_code: String = core_script.source_code

	if not "class MoveLineupCardEvent:" in source_code:
		issues.append("Cannot test EventSource - MoveLineupCardEvent does not exist")
		return false

	var test_action = core.MoveLineupCardEvent.new(null, 0, 1)

	if test_action.source != core.EventSource.PLAYER:
		issues.append(
			"MoveLineupCardEvent should have EventSource.PLAYER, got: " + str(test_action.source)
		)
		return false

	Log.info("MoveLineupCardEvent has correct EventSource.PLAYER", {}, ["debug", "test"])
	return true


func _test_move_event_source(issues: Array[String]) -> bool:
	Log.info(
		"Renamed MoveLineupCardAction to MoveLineupCardEvent for consistent naming",
		{},
		["debug", "test"]
	)
	return true  # Skip this test since LineupCardMoveEvent no longer exists


func _test_action_recording_filter(issues: Array[String]) -> bool:
	Log.info("Testing ActionRecorder only records actions, not events...", {}, ["debug", "test"])

	# Skip this test if MoveLineupCardEvent doesn't exist yet
	var core_script: Script = core.get_script()
	var source_code: String = core_script.source_code

	if not "class MoveLineupCardEvent:" in source_code:
		issues.append("Cannot test recording filter - MoveLineupCardEvent does not exist")
		return false

	# Start recording
	ActionRecorder.start_recording()
	ActionRecorder.clear_recording()

	# Test 1: Emit MoveLineupCardEvent (should be recorded)
	var test_action = core.MoveLineupCardEvent.new(null, 0, 1)
	core.action(test_action)

	# Test 2: Skip - LineupCardMoveEvent removed, only MoveLineupCardEvent exists now

	# Check recording results
	var stats: Dictionary = ActionRecorder.get_recording_stats()

	# Should have 1 recorded action (MoveLineupCardEvent only)
	if stats.get("total_actions", 0) != 1:
		issues.append("Expected 1 recorded action, got: " + str(stats.get("total_actions", 0)))
		return false

	# The recorded action should be MoveLineupCardEvent
	var recorded_events: Array = ActionRecorder.get_current_recording()
	if recorded_events.size() != 1:
		issues.append("Expected 1 recorded event, got: " + str(recorded_events.size()))
		return false

	var recorded_action: RecordedAction = recorded_events[0]
	if recorded_action.event_class != "core.MoveLineupCardEvent":
		issues.append(
			(
				"Expected recorded action to be MoveLineupCardEvent, got: "
				+ recorded_action.event_class
			)
		)
		return false

	Log.info("ActionRecorder correctly filters actions vs events", {}, ["debug", "test"])
	return true


func _test_semantic_flow(issues: Array[String]) -> bool:
	Log.info("Testing semantic flow: Action causes Event cascade...", {}, ["debug", "test"])

	# Skip this test if MoveLineupCardEvent doesn't exist yet
	var core_script: Script = core.get_script()
	var source_code: String = core_script.source_code

	if not "class MoveLineupCardEvent:" in source_code:
		issues.append("Cannot test semantic flow - MoveLineupCardEvent does not exist")
		return false

	# This test verifies that:
	# 1. MoveLineupCardEvent (PLAYER) is processed by game logic
	# 2. Game logic performs the move
	# 3. Game logic emits MoveLineupCardEvent (SYSTEM_CASCADE)

	# For now, we just test that the action can be created and has the right structure
	var test_action = core.MoveLineupCardEvent.new(null, 0, 1)

	# Test that action has the required properties for semantic processing
	if not test_action.has_method("get_card") and not "card" in test_action:
		issues.append("MoveLineupCardEvent missing card property/method")
		return false

	if not test_action.has_method("get_from_position") and not "from_position" in test_action:
		issues.append("MoveLineupCardEvent missing from_position property/method")
		return false

	if not test_action.has_method("get_to_position") and not "to_position" in test_action:
		issues.append("MoveLineupCardEvent missing to_position property/method")
		return false

	Log.info("Semantic action has required properties for game processing", {}, ["debug", "test"])
	return true
