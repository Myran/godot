extends DebugAction

class_name TestActionRecordingSystem

# Comprehensive test for action recording system
# Tests serialization/deserialization of various Event types used in recording


func _init() -> void:
	super("test.action_recording.system", _execute_recording_test)
	set_category("Test")
	set_group("Action Recording")
	set_description("Comprehensive test of action recording and event serialization")


func _execute_recording_test() -> DebugAction.Result:
	Log.info(
		"=== Action Recording System Test Started ===",
		{},
		["debug", "test", "action_recording", "recording"]
	)

	var success: bool = true

	# Test 1: core.UpgradeEvent (player action)
	success = success and _test_upgrade_event()

	# Test 2: core.RerollDraftEvent (player action)
	success = success and _test_reroll_draft_event()

	# Test 3: core.MoveLineupCardEvent (player action)
	success = success and _test_move_lineup_card_action()

	# Test 4: core.DraftColumnStateEvent (player action) - Both locked and unlocked states
	success = success and _test_draft_column_state_event()

	# Test 5: core.LineupAddCardEvent (player action)
	success = success and _test_lineup_add_card_event()

	# Test 6: core.RemoveBlockFromDraft (player action)
	success = success and _test_remove_block_from_draft_event()

	# Test 8: Round-trip test with ActionRecorder integration
	success = success and _test_action_recorder_integration()

	# Test 9: Performance test with multiple events
	success = success and _test_performance_multiple_events()

	Log.info(
		"=== Action Recording System Test Complete ===",
		{"overall_success": success},
		["debug", "test", "action_recording", "recording"]
	)

	if success:
		return DebugAction.Result.new_success(
			{
				"comprehensive_test": "All action recording tests passed",
				"events_tested":
				[
					"core.UpgradeEvent",
					"core.RerollDraftEvent",
					"core.MoveLineupCardEvent",
					"core.DraftColumnStateEvent",
					"core.LineupAddCardEvent",
					"core.RemoveBlockFromDraft"
				],
				"features_tested":
				["serialization", "deserialization", "ActionRecorder_integration", "performance"]
			},
			0,
			"action_recording_test_complete"
		)
	else:
		return DebugAction.Result.new_failure(
			"Some action recording tests failed", "ACTION_RECORDING_TEST_FAILED"
		)


func _test_context_event() -> bool:
	Log.info(
		"Testing Context.Event serialization...",
		{},
		["debug", "test", "action_recording", "recording"]
	)

	# Create original event
	var original_event: Context.Event = Context.Event.new()
	original_event.source = core.EventSource.PLAYER

	# Test RecordedAction serialization
	var recorded: RecordedAction = RecordedAction.new(original_event, 1)

	if recorded.event_class.is_empty():
		Log.error(
			"Context.Event serialization failed - empty event_class", {}, ["debug", "test", "error"]
		)
		return false

	if recorded.event_data.is_empty():
		Log.error(
			"Context.Event serialization failed - empty serialized data",
			{},
			["debug", "test", "error"]
		)
		return false

	# Test deserialization
	var deserialized_event: Context.Event = recorded.deserialize_event()

	if not deserialized_event:
		Log.error(
			"Context.Event deserialization failed - null result", {}, ["debug", "test", "error"]
		)
		return false

	if deserialized_event.source != original_event.source:
		Log.error(
			"Context.Event round-trip failed - source mismatch",
			{
				"original_source": core.EventSource.keys()[original_event.source],
				"deserialized_source": core.EventSource.keys()[deserialized_event.source]
			},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"Context.Event test passed",
		{
			"event_class": recorded.event_class,
			"serialized_length": str(recorded.event_data).length(),
			"source_preserved": deserialized_event.source == original_event.source
		},
		["debug", "test", "action_recording", "recording"]
	)

	return true


func _test_upgrade_event() -> bool:
	Log.info(
		"Testing core.UpgradeEvent serialization...",
		{},
		["debug", "test", "action_recording", "recording"]
	)

	# Create original event with data
	var original_event: core.UpgradeEvent = core.UpgradeEvent.new(5)

	# Test RecordedAction serialization
	var recorded: RecordedAction = RecordedAction.new(original_event, 3)

	if recorded.event_class.is_empty():
		Log.error(
			"core.UpgradeEvent serialization failed - empty event_class",
			{},
			["debug", "test", "error"]
		)
		return false

	# Test deserialization
	var deserialized_event: Context.Event = recorded.deserialize_event()

	if not deserialized_event:
		Log.error(
			"core.UpgradeEvent deserialization failed - null result", {}, ["debug", "test", "error"]
		)
		return false

	if not deserialized_event is core.UpgradeEvent:
		Log.error(
			"core.UpgradeEvent deserialization type mismatch",
			{"actual_type": deserialized_event.get_class()},
			["debug", "test", "error"]
		)
		return false

	var upgrade_event: core.UpgradeEvent = deserialized_event as core.UpgradeEvent
	if upgrade_event.new_level != original_event.new_level:
		Log.error(
			"core.UpgradeEvent round-trip failed - new_level mismatch",
			{
				"original_level": original_event.new_level,
				"deserialized_level": upgrade_event.new_level
			},
			["debug", "test", "error"]
		)
		return false

	if upgrade_event.source != original_event.source:
		Log.error(
			"core.UpgradeEvent round-trip failed - source mismatch",
			{
				"original_source": core.EventSource.keys()[original_event.source],
				"deserialized_source": core.EventSource.keys()[upgrade_event.source]
			},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"core.UpgradeEvent test passed",
		{
			"event_class": recorded.event_class,
			"serialized_length": str(recorded.event_data).length(),
			"new_level_preserved": upgrade_event.new_level == original_event.new_level,
			"source_preserved": upgrade_event.source == original_event.source
		},
		["debug", "test", "action_recording", "recording"]
	)

	return true


func _test_reroll_draft_event() -> bool:
	Log.info(
		"Testing core.RerollDraftEvent serialization...",
		{},
		["debug", "test", "action_recording", "recording"]
	)

	# Create original event
	var original_event: core.RerollDraftEvent = core.RerollDraftEvent.new()

	# Test RecordedAction serialization
	var recorded: RecordedAction = RecordedAction.new(original_event, 4)

	if recorded.event_class.is_empty():
		Log.error(
			"core.RerollDraftEvent serialization failed - empty event_class",
			{},
			["debug", "test", "error"]
		)
		return false

	# Test deserialization
	var deserialized_event: Context.Event = recorded.deserialize_event()

	if not deserialized_event:
		Log.error(
			"core.RerollDraftEvent deserialization failed - null result",
			{},
			["debug", "test", "error"]
		)
		return false

	if not deserialized_event is core.RerollDraftEvent:
		Log.error(
			"core.RerollDraftEvent deserialization type mismatch",
			{"actual_type": deserialized_event.get_class()},
			["debug", "test", "error"]
		)
		return false

	var reroll_event: core.RerollDraftEvent = deserialized_event as core.RerollDraftEvent
	if reroll_event.source != original_event.source:
		Log.error(
			"core.RerollDraftEvent round-trip failed - source mismatch",
			{
				"original_source": core.EventSource.keys()[original_event.source],
				"deserialized_source": core.EventSource.keys()[reroll_event.source]
			},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"core.RerollDraftEvent test passed",
		{
			"event_class": recorded.event_class,
			"serialized_length": str(recorded.event_data).length(),
			"source_preserved": reroll_event.source == original_event.source
		},
		["debug", "test", "action_recording", "recording"]
	)

	return true


func _test_action_recorder_integration() -> bool:
	Log.info(
		"Testing ActionRecorder integration...",
		{},
		["debug", "test", "action_recording", "recording"]
	)

	# Test direct event recording with ActionRecorder singleton
	var upgrade_event: core.UpgradeEvent = core.UpgradeEvent.new(7)

	# Start recording first
	ActionRecorder.start_recording()

	# Use ActionRecorder singleton directly with correct method name
	var record_success: bool = ActionRecorder.record_action(upgrade_event)

	if not record_success:
		Log.error("ActionRecorder failed to record event", {}, ["debug", "test", "error"])
		ActionRecorder.stop_recording()
		return false

	# Stop recording
	ActionRecorder.stop_recording()

	# Get recording stats to check if we have recordings
	var stats: Dictionary = ActionRecorder.get_recording_stats()
	if stats.total_actions == 0:
		Log.error("No recordings found after recording event", {}, ["debug", "test", "error"])
		return false

	# Access recorded_actions directly since there's no public getter
	var recordings: Array[RecordedAction] = ActionRecorder.recorded_actions

	if recordings.is_empty():
		Log.error("Recorded actions array is empty", {}, ["debug", "test", "error"])
		return false

	# Check the last recording (our test event)
	var last_recording: RecordedAction = recordings[-1]

	# Test deserialization of recorded event
	var deserialized_event: Context.Event = last_recording.deserialize_event()

	if not deserialized_event:
		Log.error("Failed to deserialize event from ActionRecorder", {}, ["debug", "test", "error"])
		return false

	if not deserialized_event is core.UpgradeEvent:
		Log.error(
			"ActionRecorder event type mismatch",
			{"actual_type": deserialized_event.get_class()},
			["debug", "test", "error"]
		)
		return false

	var loaded_upgrade: core.UpgradeEvent = deserialized_event as core.UpgradeEvent
	if loaded_upgrade.new_level != upgrade_event.new_level:
		Log.error(
			"ActionRecorder event data mismatch",
			{"original_level": upgrade_event.new_level, "loaded_level": loaded_upgrade.new_level},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"ActionRecorder integration test passed",
		{
			"total_recordings": recordings.size(),
			"event_preserved": loaded_upgrade.new_level == upgrade_event.new_level,
			"recorder_class": last_recording.event_class
		},
		["debug", "test", "action_recording", "recording"]
	)

	return true


func _test_performance_multiple_events() -> bool:
	Log.info(
		"Testing performance with multiple events...",
		{},
		["debug", "test", "action_recording", "recording"]
	)

	var start_time: int = Time.get_ticks_msec()
	var events_count: int = 50
	var successful_operations: int = 0

	for i: int in events_count:
		# Create different event types
		var event: Context.Event

		match i % 5:
			0:
				event = core.UpgradeEvent.new(i % 10 + 1)
			1:
				event = core.RerollDraftEvent.new()
			2:
				event = core.MoveLineupCardEvent.new(null, i % 5, i % 3)
			3:
				event = core.DraftColumnStateEvent.new(i % 3, (i % 2) == 0)
			_:
				event = core.LineupAddCardEvent.new(null)

		# Test serialization/deserialization
		var recorded: RecordedAction = RecordedAction.new(event, i)

		if recorded.event_data.is_empty():
			Log.error(
				"Performance test failed - serialization failed",
				{"event_index": i, "event_type": event.get_class()},
				["debug", "test", "error"]
			)
			continue

		var deserialized: Context.Event = recorded.deserialize_event()

		if not deserialized:
			Log.error(
				"Performance test failed - deserialization failed",
				{"event_index": i, "event_type": event.get_class()},
				["debug", "test", "error"]
			)
			continue

		successful_operations += 1

	var end_time: int = Time.get_ticks_msec()
	var total_time: int = end_time - start_time

	var success_rate: float = float(successful_operations) / float(events_count)

	Log.info(
		"Performance test completed",
		{
			"total_events": events_count,
			"successful_operations": successful_operations,
			"success_rate": success_rate,
			"total_time_ms": total_time,
			"avg_time_per_event_ms": float(total_time) / float(events_count)
		},
		["debug", "test", "action_recording", "recording", "performance"]
	)

	return success_rate >= 0.98  # 98% success rate required


func _test_move_lineup_card_action() -> bool:
	Log.info(
		"Testing core.MoveLineupCardEvent serialization...",
		{},
		["debug", "test", "action_recording", "recording"]
	)

	# Create a mock card for testing (using null since we only test serialization)
	var original_action: core.MoveLineupCardEvent = core.MoveLineupCardEvent.new(null, 2, 5)

	# Test RecordedAction serialization
	var recorded: RecordedAction = RecordedAction.new(original_action, 6)

	if recorded.event_class.is_empty():
		Log.error(
			"core.MoveLineupCardEvent serialization failed - empty event_class",
			{},
			["debug", "test", "error"]
		)
		return false

	# Test deserialization
	var deserialized_action: Context.Event = recorded.deserialize_event()

	if not deserialized_action:
		Log.error(
			"core.MoveLineupCardEvent deserialization failed - null result",
			{},
			["debug", "test", "error"]
		)
		return false

	if not deserialized_action is core.MoveLineupCardEvent:
		Log.error(
			"core.MoveLineupCardEvent deserialization type mismatch",
			{"actual_type": deserialized_action.get_class()},
			["debug", "test", "error"]
		)
		return false

	var move_action: core.MoveLineupCardEvent = deserialized_action as core.MoveLineupCardEvent
	if (
		move_action.source != original_action.source
		or move_action.from_position != original_action.from_position
		or move_action.to_position != original_action.to_position
	):
		Log.error(
			"core.MoveLineupCardEvent round-trip failed - data mismatch",
			{
				"original_source": core.EventSource.keys()[original_action.source],
				"deserialized_source": core.EventSource.keys()[move_action.source],
				"original_from": original_action.from_position,
				"deserialized_from": move_action.from_position,
				"original_to": original_action.to_position,
				"deserialized_to": move_action.to_position
			},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"core.MoveLineupCardEvent test passed",
		{
			"event_class": recorded.event_class,
			"serialized_length": str(recorded.event_data).length(),
			"from_position": move_action.from_position,
			"to_position": move_action.to_position,
			"source": core.EventSource.keys()[move_action.source]
		},
		["debug", "test", "action_recording", "recording"]
	)

	return true


func _test_draft_column_state_event() -> bool:
	Log.info(
		"Testing core.DraftColumnStateEvent serialization...",
		{},
		["debug", "test", "action_recording", "recording"]
	)

	# Test both locked and unlocked states
	var test_cases: Array = [
		{"column": 2, "is_locked": true, "description": "locked state"},
		{"column": 4, "is_locked": false, "description": "unlocked state"}
	]

	for case: Dictionary in test_cases:
		var case_description: String = case.get("description", "")
		var column: int = case.get("column", 0)
		var is_locked: bool = case.get("is_locked", false)
		var test_message: String = "Testing DraftColumnStateEvent " + case_description

		Log.info(
			test_message,
			{"column": column, "is_locked": is_locked},
			["debug", "test", "action_recording", "recording"]
		)

		# Create original event
		var original_event: core.DraftColumnStateEvent = core.DraftColumnStateEvent.new(
			column, is_locked
		)

		# Test RecordedAction serialization
		var timestamp: int = column + 10
		var recorded: RecordedAction = RecordedAction.new(original_event, timestamp)

		if recorded.event_class.is_empty():
			Log.error(
				"core.DraftColumnStateEvent serialization failed - empty event_class",
				{"test_case": case.description},
				["debug", "test", "error"]
			)
			return false

		if recorded.event_data.is_empty():
			Log.error(
				"core.DraftColumnStateEvent serialization failed - empty serialized data",
				{"test_case": case.description},
				["debug", "test", "error"]
			)
			return false

		# Test deserialization
		var deserialized_event: Context.Event = recorded.deserialize_event()

		if not deserialized_event:
			Log.error(
				"core.DraftColumnStateEvent deserialization failed - null result",
				{"test_case": case.description},
				["debug", "test", "error"]
			)
			return false

		if not deserialized_event is core.DraftColumnStateEvent:
			Log.error(
				"core.DraftColumnStateEvent deserialization type mismatch",
				{"test_case": case.description, "actual_type": deserialized_event.get_class()},
				["debug", "test", "error"]
			)
			return false

		var state_event: core.DraftColumnStateEvent = (
			deserialized_event as core.DraftColumnStateEvent
		)

		# Verify all properties match
		if (
			state_event.source != original_event.source
			or state_event.col != original_event.col
			or state_event.is_locked != original_event.is_locked
		):
			Log.error(
				"core.DraftColumnStateEvent round-trip failed - data mismatch",
				{
					"test_case": case.description,
					"original_source": core.EventSource.keys()[original_event.source],
					"deserialized_source": core.EventSource.keys()[state_event.source],
					"original_col": original_event.col,
					"deserialized_col": state_event.col,
					"original_is_locked": original_event.is_locked,
					"deserialized_is_locked": state_event.is_locked
				},
				["debug", "test", "error"]
			)
			return false

		Log.info(
			"core.DraftColumnStateEvent test case passed",
			{
				"test_case": case.description,
				"event_class": recorded.event_class,
				"serialized_length": str(recorded.event_data).length(),
				"column": state_event.col,
				"is_locked": state_event.is_locked,
				"source": core.EventSource.keys()[state_event.source]
			},
			["debug", "test", "action_recording", "recording"]
		)

	Log.info(
		"core.DraftColumnStateEvent test completed - both states verified",
		{},
		["debug", "test", "action_recording", "recording"]
	)

	return true


func _test_lineup_add_card_event() -> bool:
	Log.info(
		"Testing core.LineupAddCardEvent serialization...",
		{},
		["debug", "test", "action_recording", "recording"]
	)

	# Create a mock card for testing (using null since we only test serialization)
	var original_event: core.LineupAddCardEvent = core.LineupAddCardEvent.new(null)

	# Test RecordedAction serialization
	var recorded: RecordedAction = RecordedAction.new(original_event, 9)

	if recorded.event_class.is_empty():
		Log.error(
			"core.LineupAddCardEvent serialization failed - empty event_class",
			{},
			["debug", "test", "error"]
		)
		return false

	# Test deserialization
	var deserialized_event: Context.Event = recorded.deserialize_event()

	if not deserialized_event:
		Log.error(
			"core.LineupAddCardEvent deserialization failed - null result",
			{},
			["debug", "test", "error"]
		)
		return false

	if not deserialized_event is core.LineupAddCardEvent:
		Log.error(
			"core.LineupAddCardEvent deserialization type mismatch",
			{"actual_type": deserialized_event.get_class()},
			["debug", "test", "error"]
		)
		return false

	var lineup_event: core.LineupAddCardEvent = deserialized_event as core.LineupAddCardEvent
	if lineup_event.source != original_event.source:
		Log.error(
			"core.LineupAddCardEvent round-trip failed - source mismatch",
			{
				"original_source": core.EventSource.keys()[original_event.source],
				"deserialized_source": core.EventSource.keys()[lineup_event.source]
			},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"core.LineupAddCardEvent test passed",
		{
			"event_class": recorded.event_class,
			"serialized_length": str(recorded.event_data).length(),
			"source": core.EventSource.keys()[lineup_event.source]
		},
		["debug", "test", "action_recording", "recording"]
	)

	return true


func _test_remove_block_from_draft_event() -> bool:
	Log.info(
		"Testing core.RemoveBlockFromDraft serialization...",
		{},
		["debug", "test", "action_recording", "recording"]
	)

	# Create event with null block and destroy_block = true for testing
	var original_event: core.RemoveBlockFromDraft = core.RemoveBlockFromDraft.new(null, true)

	# Test RecordedAction serialization
	var recorded: RecordedAction = RecordedAction.new(original_event, 10)

	if recorded.event_class.is_empty():
		Log.error(
			"core.RemoveBlockFromDraft serialization failed - empty event_class",
			{},
			["debug", "test", "error"]
		)
		return false

	# Test deserialization
	var deserialized_event: Context.Event = recorded.deserialize_event()

	if not deserialized_event:
		Log.error(
			"core.RemoveBlockFromDraft deserialization failed - null result",
			{},
			["debug", "test", "error"]
		)
		return false

	if not deserialized_event is core.RemoveBlockFromDraft:
		Log.error(
			"core.RemoveBlockFromDraft deserialization type mismatch",
			{"actual_type": deserialized_event.get_class()},
			["debug", "test", "error"]
		)
		return false

	var remove_event: core.RemoveBlockFromDraft = deserialized_event as core.RemoveBlockFromDraft
	if (
		remove_event.source != original_event.source
		or remove_event.destroy_block != original_event.destroy_block
	):
		Log.error(
			"core.RemoveBlockFromDraft round-trip failed - data mismatch",
			{
				"original_source": core.EventSource.keys()[original_event.source],
				"deserialized_source": core.EventSource.keys()[remove_event.source],
				"original_destroy": original_event.destroy_block,
				"deserialized_destroy": remove_event.destroy_block
			},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"core.RemoveBlockFromDraft test passed",
		{
			"event_class": recorded.event_class,
			"serialized_length": str(recorded.event_data).length(),
			"destroy_block": remove_event.destroy_block,
			"source": core.EventSource.keys()[remove_event.source]
		},
		["debug", "test", "action_recording", "recording"]
	)

	return true
