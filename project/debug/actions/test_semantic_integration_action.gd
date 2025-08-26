class_name TestSemanticIntegrationAction
extends DebugAction


func _init() -> void:
	super("system.debug.test_semantic_integration", _execute_semantic_integration_test)
	set_category("System")
	set_group("Test")
	set_description(
		"Integration test that verifies semantic logging works with actual player events"
	)


func _execute_semantic_integration_test() -> DebugActionResult:
	var session_id: String = SessionManager.get_current_session_id()
	var initial_count: int = SemanticActionLogger.get_session_info().action_count

	Log.info(
		"Starting semantic logging integration test",
		{"session_id": session_id, "initial_count": initial_count},
		["semantic_action", "test", "integration"]
	)

	var test_results: Array[String] = []

	var session_info: Dictionary = SemanticActionLogger.get_session_info()
	if session_info.is_active:
		test_results.append("✅ Session is active after start")
	else:
		test_results.append("❌ Session not active after start")

	SemanticActionLogger.log_action("test.integration_action_1", {"test": true})
	SemanticActionLogger.log_action("test.integration_action_2", {"value": 42})
	SemanticActionLogger.log_action("test.integration_action_3", {"data": "test"})

	var final_session_info: Dictionary = SemanticActionLogger.get_session_info()
	var actions_logged: int = final_session_info.action_count - initial_count

	if actions_logged == 3:
		test_results.append("✅ Correct number of actions logged (3)")
	else:
		test_results.append("❌ Expected 3 actions, got %d" % actions_logged)

	if final_session_info.session_id == session_id:
		test_results.append("✅ Session ID remained consistent")
	else:
		test_results.append("❌ Session ID changed during test")

	var current_session_info: Dictionary = SemanticActionLogger.get_session_info()

	if current_session_info.is_active:
		test_results.append("✅ Session remains active (full gameplay session)")
	else:
		test_results.append("❌ Session unexpectedly inactive")

	var success_count: int = 0
	var total_tests: int = test_results.size()

	for result: String in test_results:
		if result.begins_with("✅"):
			success_count += 1

	var summary: String = "Integration Test Results:\n" + "\n".join(test_results)
	summary += "\n\nSummary: %d/%d tests passed" % [success_count, total_tests]

	Log.info(
		"Semantic logging integration test completed",
		{
			"session_id": session_id,
			"tests_passed": success_count,
			"total_tests": total_tests,
			"actions_logged": actions_logged
		},
		["semantic_action", "test", "integration", "complete"]
	)

	if success_count == total_tests:
		return DebugActionResult.new_success(summary)
	return DebugActionResult.new_failure(summary, "INTEGRATION_TEST_FAILED")
