extends DebugAction

class_name TestEventCategorizationAction


func _init() -> void:
	super("test.event.categorization", _execute_categorization_test)
	set_category("Test")
	set_group("Event System")
	set_description("Test EventSource categorization and get_recording_data() methods")


func _execute_categorization_test() -> DebugAction.Result:
	Log.info("=== TESTING EVENT CATEGORIZATION ===", {}, ["debug", "test", "event_categorization"])

	# Test 1: Create PLAYER event and check categorization
	var player_event: core.RerollDraftEvent = core.RerollDraftEvent.new()
	var player_data: Dictionary = player_event.get_recording_data()

	Log.info(
		"Player event test",
		{
			"source": player_event.source,
			"source_name": core.EventSource.keys()[player_event.source],
			"recording_data": player_data
		},
		["debug", "test", "event_categorization", "player"]
	)

	# Test 2: Create DEBUG_SETUP event and check categorization
	var debug_event: core.EnemyLineupAddCardEvent = core.EnemyLineupAddCardEvent.new(null, 0)
	var debug_data: Dictionary = debug_event.get_recording_data()

	Log.info(
		"Debug event test",
		{
			"source": debug_event.source,
			"source_name": core.EventSource.keys()[debug_event.source],
			"recording_data": debug_data
		},
		["debug", "test", "event_categorization", "debug_setup"]
	)

	# Test 3: Verify ActionRecorder filtering logic
	if ActionRecorder:
		var initial_stats: Dictionary = ActionRecorder.get_recording_stats()

		# Start recording
		ActionRecorder.start_recording()

		# Send player event (should be recorded)
		core.action(player_event)

		# Send debug event (should be filtered out)
		core.action(debug_event)

		# Check recording results
		var final_stats: Dictionary = ActionRecorder.get_recording_stats()

		Log.info(
			"Recording filter test",
			{
				"initial_actions": initial_stats.total_actions,
				"final_actions": final_stats.total_actions,
				"recorded_count": final_stats.total_actions - initial_stats.total_actions,
				"expected_count": 1  # Only player event should be recorded
			},
			["debug", "test", "event_categorization", "filtering"]
		)

		ActionRecorder.stop_recording()

		# Verify correct filtering
		var recorded_count: int = final_stats.total_actions - initial_stats.total_actions
		if recorded_count == 1:
			Log.info(
				"CATEGORIZATION_TEST_PASSED",
				{"recorded_player_events": 1, "filtered_debug_events": 1},
				["test", "event_categorization", "success"]
			)
			return DebugAction.Result.new_success(
				{
					"test": "event_categorization",
					"status": "passed",
					"recorded_events": recorded_count
				},
				0,
				"categorization_test_passed"
			)
		else:
			Log.error(
				"CATEGORIZATION_TEST_FAILED",
				{"expected": 1, "actual": recorded_count},
				["test", "event_categorization", "failed"]
			)
			return DebugAction.Result.new_failure(
				"Event categorization test failed - wrong number of events recorded",
				"CATEGORIZATION_FAILED"
			)
	else:
		Log.error(
			"ActionRecorder not available", {}, ["debug", "test", "event_categorization", "error"]
		)
		return DebugAction.Result.new_failure(
			"ActionRecorder singleton not available", "RECORDER_NOT_AVAILABLE"
		)
