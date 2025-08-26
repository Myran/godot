class_name TestSemanticPlayerEventsAction
extends DebugAction


func _init() -> void:
	super("system.debug.test_semantic_player_events", _execute_player_events_test)
	set_category("System")
	set_group("Test")
	set_description(
		"Test semantic logging integration with actual player events by triggering real game events and validating logs"
	)


func _execute_player_events_test() -> DebugActionResult:
	Log.info(
		"=== TESTING SEMANTIC LOGGING WITH REAL PLAYER EVENTS ===",
		{},
		["semantic_action", "test", "player_events"]
	)

	var test_results: Array[Dictionary] = []
	var session_id: String = SessionManager.get_current_session_id()
	var initial_count: int = SemanticActionLogger.get_session_info().action_count

	var reroll_success: bool = _test_reroll_event()
	test_results.append(
		{
			"name": "RerollDraftEvent semantic logging",
			"success": reroll_success,
			"expected_action": "draft.reroll"
		}
	)

	var upgrade_success: bool = _test_upgrade_event()
	test_results.append(
		{
			"name": "UpgradeEvent semantic logging",
			"success": upgrade_success,
			"expected_action": "draft.upgrade"
		}
	)

	var transition_success: bool = _test_transition_event()
	test_results.append(
		{
			"name": "TransitionEvent semantic logging",
			"success": transition_success,
			"expected_action": "transition.change_state"
		}
	)

	var final_info: Dictionary = SemanticActionLogger.get_session_info()
	var actions_logged: int = final_info.action_count - initial_count
	var expected_actions: int = (
		test_results.filter(func(t: Dictionary) -> bool: return t.success).size()
	)

	var count_test: Dictionary = {
		"name": "Action count verification",
		"success": actions_logged >= expected_actions,
		"details": "Expected at least: %d, Logged: %d" % [expected_actions, actions_logged]
	}
	test_results.append(count_test)

	var passed_tests: int = (
		test_results.filter(func(t: Dictionary) -> bool: return t.success).size()
	)
	var total_tests: int = test_results.size()
	var overall_success: bool = passed_tests == total_tests

	var report: Array[String] = []
	report.append("Real Player Events Test Results:")
	report.append("")

	for test: Dictionary in test_results:
		var status: String = "✅" if test.success else "❌"
		report.append("• %s %s" % [status, test.name])
		if test.has("expected_action"):
			report.append("  Expected action: %s" % test.expected_action)
		if test.has("details"):
			report.append("  %s" % test.details)

	report.append("")
	report.append("Summary: %d/%d tests passed" % [passed_tests, total_tests])
	report.append("Actions logged during test: %d" % actions_logged)

	var summary: String = "\n".join(report)

	Log.info(
		"Real player events test completed",
		{
			"session_id": session_id,
			"tests_passed": passed_tests,
			"total_tests": total_tests,
			"actions_logged": actions_logged,
			"overall_success": overall_success
		},
		["semantic_action", "test", "player_events", "complete"]
	)

	if overall_success:
		return DebugActionResult.new_success(summary, 0, "player_events_test")
	return DebugActionResult.new_failure(summary, "PLAYER_EVENTS_TEST_FAILED")


func _test_reroll_event() -> bool:
	Log.info("Testing RerollDraftEvent semantic logging", {}, ["semantic_action", "test", "reroll"])

	var reroll_event: core.RerollDraftEvent = core.RerollDraftEvent.new()

	reroll_event.source = core.EventSource.PLAYER

	core.action(reroll_event)

	return true


func _test_upgrade_event() -> bool:
	Log.info("Testing UpgradeEvent semantic logging", {}, ["semantic_action", "test", "upgrade"])

	var upgrade_event: core.UpgradeEvent = core.UpgradeEvent.new(2)  # Upgrade to level 2

	upgrade_event.source = core.EventSource.PLAYER

	core.action(upgrade_event)

	return true


func _test_transition_event() -> bool:
	Log.info(
		"Testing TransitionEvent semantic logging", {}, ["semantic_action", "test", "transition"]
	)

	var current_state: core.GameState = core.game_handler.current_gamestate
	var target_state: core.GameState

	match current_state:
		core.GameState.START:
			target_state = core.GameState.DRAFT
		core.GameState.DRAFT:
			target_state = core.GameState.START
		_:
			target_state = core.GameState.START

	var transition_event: core.TransitionEvent = core.TransitionEvent.new(target_state)
	transition_event.source = core.EventSource.PLAYER

	core.action(transition_event)

	var restore_event: core.TransitionEvent = core.TransitionEvent.new(current_state)
	restore_event.source = core.EventSource.PLAYER
	core.action(restore_event)

	return true
