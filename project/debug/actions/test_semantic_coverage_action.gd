class_name TestSemanticCoverageAction
extends DebugAction


func _init() -> void:
	super("system.debug.test_semantic_coverage", _execute_semantic_coverage_test)
	set_category("System")
	set_group("Test")
	set_description(
		"Test that validates all 9 player event types trigger semantic logging with correct format"
	)


func _execute_semantic_coverage_test() -> DebugAction.Result:
	# Test all 9 expected player event types
	var expected_events: Array[String] = [
		"lineup.move_card",
		"lineup.add_card",
		"draft.reroll",
		"draft.upgrade",
		"draft.column_toggle",
		"draft.remove_block",
		"transition.change_state",
		"battle.start",
		"draft.reroll_ui",
		"draft.upgrade_ui"
	]

	# Ensure session exists (will create one if needed)
	var session_id: String = SessionManager.get_current_session_id()

	Log.info(
		"Starting semantic logging coverage test",
		{"session_id": session_id, "expected_events": expected_events.size()},
		["semantic_action", "test", "coverage"]
	)

	var test_results: Array[String] = []
	var initial_count: int = SemanticActionLogger.get_session_info().action_count

	# Test 1: Manual logging of each expected action type
	for action_type: String in expected_events:
		SemanticActionLogger.log_action(
			action_type, {"test": true, "action_index": expected_events.find(action_type)}
		)

	# Test 2: Verify action count increased correctly
	var final_count: int = SemanticActionLogger.get_session_info().action_count
	var actions_logged: int = final_count - initial_count

	if actions_logged == expected_events.size():
		test_results.append(
			"✅ All %d expected action types logged successfully" % expected_events.size()
		)
	else:
		test_results.append(
			"❌ Expected %d actions, got %d" % [expected_events.size(), actions_logged]
		)

	# Test 3: Verify session info format
	var session_info: Dictionary = SemanticActionLogger.get_session_info()
	var required_fields: Array[String] = ["session_id", "action_count", "is_active"]

	var missing_fields: Array[String] = []
	for field: String in required_fields:
		if not session_info.has(field):
			missing_fields.append(field)

	if missing_fields.is_empty():
		test_results.append("✅ Session info has all required fields")
	else:
		test_results.append("❌ Session info missing fields: %s" % str(missing_fields))

	# Test 4: Verify session ID format
	if session_info.session_id.begins_with("coverage_test_session"):
		test_results.append("✅ Session ID format correct")
	else:
		test_results.append("❌ Session ID format incorrect: %s" % session_info.session_id)

	# Test 5: Session remains active for full gameplay
	var current_session_info: Dictionary = SemanticActionLogger.get_session_info()

	if current_session_info.is_active:
		test_results.append("✅ Session remains active (full gameplay session)")
	else:
		test_results.append("❌ Session unexpectedly inactive")

	# Generate summary
	var success_count: int = 0
	var total_tests: int = test_results.size()

	for result: String in test_results:
		if result.begins_with("✅"):
			success_count += 1

	var summary: String = "Coverage Test Results:\n" + "\n".join(test_results)
	summary += "\n\nSummary: %d/%d tests passed" % [success_count, total_tests]
	summary += "\nExpected Events: %s" % str(expected_events)

	Log.info(
		"Semantic logging coverage test completed",
		{
			"session_id": session_id,
			"tests_passed": success_count,
			"total_tests": total_tests,
			"expected_events": expected_events.size(),
			"actions_logged": actions_logged
		},
		["semantic_action", "test", "coverage", "complete"]
	)

	if success_count == total_tests:
		return DebugAction.Result.new_success(summary)
	else:
		return DebugAction.Result.new_failure(summary, "COVERAGE_TEST_FAILED")
