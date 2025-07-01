extends DebugAction

class_name TestBasicActionSerialization

# Basic test for action recording and event serialization


func _init() -> void:
	super("test.basic.action_serialization", _execute_basic_test)
	set_category("Test")
	set_group("Action Recording")
	set_description("Basic action recording and event serialization test")


func _execute_basic_test() -> DebugAction.Result:
	Log.info(
		"=== Comprehensive Action Serialization Test Started ===",
		{},
		["debug", "test", "action_recording"]
	)

	var success: bool = true

	# Test all player action event types registered in RefSerializer
	# Core events
	success = success and _test_upgrade_event()
	success = success and _test_reroll_draft_event()
	success = success and _test_move_lineup_event()
	success = success and _test_draft_column_event()
	success = success and _test_lineup_add_card_event()
	success = success and _test_remove_block_event()

	# UI events
	success = success and _test_transition_event()
	success = success and _test_ui_reroll_event()
	success = success and _test_ui_upgrade_event()

	Log.info(
		"=== Comprehensive Action Serialization Test Complete ===",
		{"success": success, "total_event_types": 9},
		["debug", "test", "action_recording"]
	)

	if success:
		return DebugAction.Result.new_success(
			{"comprehensive_serialization_test": "All 9 player action event types passed"},
			0,
			"comprehensive_serialization_test_complete"
		)
	else:
		return DebugAction.Result.new_failure(
			"Comprehensive serialization tests failed", "COMPREHENSIVE_SERIALIZATION_TEST_FAILED"
		)


func _test_upgrade_event() -> bool:
	Log.info(
		"Testing core.UpgradeEvent serialization...", {}, ["debug", "test", "action_recording"]
	)

	var original: core.UpgradeEvent = core.UpgradeEvent.new(42)
	var recorded: RecordedAction = RecordedAction.new(original, 1)
	var deserialized: Context.Event = recorded.deserialize_event()

	if not deserialized is core.UpgradeEvent:
		Log.error(
			"UpgradeEvent type mismatch",
			{"expected": "core.UpgradeEvent", "actual": deserialized.get_class()},
			["debug", "test", "error"]
		)
		return false

	var result: core.UpgradeEvent = deserialized

	# Check ALL properties
	if result.new_level != original.new_level:
		Log.error(
			"UpgradeEvent.new_level mismatch",
			{"expected": original.new_level, "actual": result.new_level},
			["debug", "test", "error"]
		)
		return false

	if result.source != original.source:
		Log.error(
			"UpgradeEvent.source mismatch",
			{"expected": original.source, "actual": result.source},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"UpgradeEvent all properties validated",
		{"new_level": result.new_level, "source": result.source},
		["debug", "test", "action_recording"]
	)
	return true


func _test_move_lineup_event() -> bool:
	Log.info(
		"Testing core.MoveLineupCardEvent serialization...",
		{},
		["debug", "test", "action_recording"]
	)

	var original: core.MoveLineupCardEvent = core.MoveLineupCardEvent.new(null, 3, 7)
	var recorded: RecordedAction = RecordedAction.new(original, 2)
	var deserialized: Context.Event = recorded.deserialize_event()

	if not deserialized is core.MoveLineupCardEvent:
		Log.error(
			"MoveLineupCardEvent type mismatch",
			{"expected": "core.MoveLineupCardEvent", "actual": deserialized.get_class()},
			["debug", "test", "error"]
		)
		return false

	var result: core.MoveLineupCardEvent = deserialized

	# Check ALL properties including null handling
	if result.card != original.card:  # Both should be null
		Log.error(
			"MoveLineupCardEvent.card mismatch",
			{"expected_null": original.card == null, "actual_null": result.card == null},
			["debug", "test", "error"]
		)
		return false

	if result.from_position != original.from_position:
		Log.error(
			"MoveLineupCardEvent.from_position mismatch",
			{"expected": original.from_position, "actual": result.from_position},
			["debug", "test", "error"]
		)
		return false

	if result.to_position != original.to_position:
		Log.error(
			"MoveLineupCardEvent.to_position mismatch",
			{"expected": original.to_position, "actual": result.to_position},
			["debug", "test", "error"]
		)
		return false

	if result.source != original.source:
		Log.error(
			"MoveLineupCardEvent.source mismatch",
			{"expected": original.source, "actual": result.source},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"MoveLineupCardEvent all properties validated",
		{"from": result.from_position, "to": result.to_position, "card_null": result.card == null},
		["debug", "test", "action_recording"]
	)
	return true


func _test_draft_column_event() -> bool:
	Log.info(
		"Testing core.DraftColumnStateEvent serialization...",
		{},
		["debug", "test", "action_recording"]
	)

	var original: core.DraftColumnStateEvent = core.DraftColumnStateEvent.new(2, true)
	var recorded: RecordedAction = RecordedAction.new(original, 3)
	var deserialized: Context.Event = recorded.deserialize_event()

	if not deserialized is core.DraftColumnStateEvent:
		Log.error(
			"DraftColumnStateEvent type mismatch",
			{"expected": "core.DraftColumnStateEvent", "actual": deserialized.get_class()},
			["debug", "test", "error"]
		)
		return false

	var result: core.DraftColumnStateEvent = deserialized

	# Check ALL properties including boolean
	if result.col != original.col:
		Log.error(
			"DraftColumnStateEvent.col mismatch",
			{"expected": original.col, "actual": result.col},
			["debug", "test", "error"]
		)
		return false

	if result.is_locked != original.is_locked:
		Log.error(
			"DraftColumnStateEvent.is_locked mismatch",
			{"expected": original.is_locked, "actual": result.is_locked},
			["debug", "test", "error"]
		)
		return false

	if result.source != original.source:
		Log.error(
			"DraftColumnStateEvent.source mismatch",
			{"expected": original.source, "actual": result.source},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"DraftColumnStateEvent all properties validated",
		{"col": result.col, "is_locked": result.is_locked},
		["debug", "test", "action_recording"]
	)
	return true


func _test_transition_event() -> bool:
	Log.info(
		"Testing ui.TransitionEvent serialization...", {}, ["debug", "test", "action_recording"]
	)

	var original: ui.TransitionEvent = ui.TransitionEvent.new(core.GameState.BATTLE)
	var recorded: RecordedAction = RecordedAction.new(original, 4)
	var deserialized: Context.Event = recorded.deserialize_event()

	if not deserialized is ui.TransitionEvent:
		Log.error(
			"TransitionEvent type mismatch",
			{"expected": "ui.TransitionEvent", "actual": deserialized.get_class()},
			["debug", "test", "error"]
		)
		return false

	var result: ui.TransitionEvent = deserialized

	# Check ALL properties including enum
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
		"TransitionEvent all properties validated",
		{"new_state": result.new_state, "source": result.source},
		["debug", "test", "action_recording"]
	)
	return true


func _test_reroll_draft_event() -> bool:
	Log.info(
		"Testing core.RerollDraftEvent serialization...", {}, ["debug", "test", "action_recording"]
	)

	var original: core.RerollDraftEvent = core.RerollDraftEvent.new()
	var recorded: RecordedAction = RecordedAction.new(original, 5)
	var deserialized: Context.Event = recorded.deserialize_event()

	if not deserialized is core.RerollDraftEvent:
		Log.error(
			"RerollDraftEvent type mismatch",
			{"expected": "core.RerollDraftEvent", "actual": deserialized.get_class()},
			["debug", "test", "error"]
		)
		return false

	var result: core.RerollDraftEvent = deserialized

	# Check ALL properties
	if result.source != original.source:
		Log.error(
			"RerollDraftEvent.source mismatch",
			{"expected": original.source, "actual": result.source},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"RerollDraftEvent all properties validated",
		{"source": result.source},
		["debug", "test", "action_recording"]
	)
	return true


func _test_lineup_add_card_event() -> bool:
	Log.info(
		"Testing core.LineupAddCardEvent serialization...",
		{},
		["debug", "test", "action_recording"]
	)

	var original: core.LineupAddCardEvent = core.LineupAddCardEvent.new()
	var recorded: RecordedAction = RecordedAction.new(original, 6)
	var deserialized: Context.Event = recorded.deserialize_event()

	if not deserialized is core.LineupAddCardEvent:
		Log.error(
			"LineupAddCardEvent type mismatch",
			{"expected": "core.LineupAddCardEvent", "actual": deserialized.get_class()},
			["debug", "test", "error"]
		)
		return false

	var result: core.LineupAddCardEvent = deserialized

	# Check ALL properties including null handling
	if result.card != original.card:  # Both should be null
		Log.error(
			"LineupAddCardEvent.card mismatch",
			{"expected_null": original.card == null, "actual_null": result.card == null},
			["debug", "test", "error"]
		)
		return false

	if result.source != original.source:
		Log.error(
			"LineupAddCardEvent.source mismatch",
			{"expected": original.source, "actual": result.source},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"LineupAddCardEvent all properties validated",
		{"card_null": result.card == null},
		["debug", "test", "action_recording"]
	)
	return true


func _test_remove_block_event() -> bool:
	Log.info(
		"Testing core.RemoveBlockFromDraft serialization...",
		{},
		["debug", "test", "action_recording"]
	)

	var original: core.RemoveBlockFromDraft = core.RemoveBlockFromDraft.new()
	var recorded: RecordedAction = RecordedAction.new(original, 7)
	var deserialized: Context.Event = recorded.deserialize_event()

	if not deserialized is core.RemoveBlockFromDraft:
		Log.error(
			"RemoveBlockFromDraft type mismatch",
			{"expected": "core.RemoveBlockFromDraft", "actual": deserialized.get_class()},
			["debug", "test", "error"]
		)
		return false

	var result: core.RemoveBlockFromDraft = deserialized

	# Check ALL properties
	if result.block != original.block:  # Both should be null
		Log.error(
			"RemoveBlockFromDraft.block mismatch",
			{"expected_null": original.block == null, "actual_null": result.block == null},
			["debug", "test", "error"]
		)
		return false

	if result.destroy_block != original.destroy_block:
		Log.error(
			"RemoveBlockFromDraft.destroy_block mismatch",
			{"expected": original.destroy_block, "actual": result.destroy_block},
			["debug", "test", "error"]
		)
		return false

	if result.source != original.source:
		Log.error(
			"RemoveBlockFromDraft.source mismatch",
			{"expected": original.source, "actual": result.source},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"RemoveBlockFromDraft all properties validated",
		{"block_null": result.block == null, "destroy_block": result.destroy_block},
		["debug", "test", "action_recording"]
	)
	return true


func _test_ui_reroll_event() -> bool:
	Log.info("Testing ui.RerollEvent serialization...", {}, ["debug", "test", "action_recording"])

	var original: ui.RerollEvent = ui.RerollEvent.new()
	var recorded: RecordedAction = RecordedAction.new(original, 8)
	var deserialized: Context.Event = recorded.deserialize_event()

	if not deserialized is ui.RerollEvent:
		Log.error(
			"ui.RerollEvent type mismatch",
			{"expected": "ui.RerollEvent", "actual": deserialized.get_class()},
			["debug", "test", "error"]
		)
		return false

	var result: ui.RerollEvent = deserialized

	# Check ALL properties
	if result.source != original.source:
		Log.error(
			"ui.RerollEvent.source mismatch",
			{"expected": original.source, "actual": result.source},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"ui.RerollEvent all properties validated",
		{"source": result.source},
		["debug", "test", "action_recording"]
	)
	return true


func _test_ui_upgrade_event() -> bool:
	Log.info("Testing ui.UpgradeEvent serialization...", {}, ["debug", "test", "action_recording"])

	var original: ui.UpgradeEvent = ui.UpgradeEvent.new()
	var recorded: RecordedAction = RecordedAction.new(original, 9)
	var deserialized: Context.Event = recorded.deserialize_event()

	if not deserialized is ui.UpgradeEvent:
		Log.error(
			"ui.UpgradeEvent type mismatch",
			{"expected": "ui.UpgradeEvent", "actual": deserialized.get_class()},
			["debug", "test", "error"]
		)
		return false

	var result: ui.UpgradeEvent = deserialized

	# Check ALL properties
	if result.source != original.source:
		Log.error(
			"ui.UpgradeEvent.source mismatch",
			{"expected": original.source, "actual": result.source},
			["debug", "test", "error"]
		)
		return false

	Log.info(
		"ui.UpgradeEvent all properties validated",
		{"source": result.source},
		["debug", "test", "action_recording"]
	)
	return true
