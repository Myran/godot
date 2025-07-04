class_name TestSemanticIntegrationAction
extends DebugAction


func _init() -> void:
	super("system.debug.test_semantic_integration", _execute_semantic_integration_test)
	set_category("System")
	set_group("Test")
	set_description(
		"Integration test that verifies semantic logging works with actual player events"
	)


func _execute_semantic_integration_test() -> DebugAction.Result:
	# Start a test session
	var session_id: String = SemanticActionLogger.start_session("integration_test_session")
	var initial_count: int = SemanticActionLogger.get_session_info().action_count

	Log.info(
		"Starting semantic logging integration test",
		{"session_id": session_id, "initial_count": initial_count},
		["semantic_action", "test", "integration"]
	)

	var test_results: Array[String] = []

	# Test 1: Verify session is active
	var session_info: Dictionary = SemanticActionLogger.get_session_info()
	if session_info.is_active:
		test_results.append("✅ Session is active after start")
	else:
		test_results.append("❌ Session not active after start")

	# Test 2: Log sample semantic actions and verify count
	SemanticActionLogger.log_action("test.integration_action_1", {"test": true})
	SemanticActionLogger.log_action("test.integration_action_2", {"value": 42})
	SemanticActionLogger.log_action("test.integration_action_3", {"data": "test"})

	# Test 3: Verify action count increased correctly
	var final_session_info: Dictionary = SemanticActionLogger.get_session_info()
	var actions_logged: int = final_session_info.action_count - initial_count

	if actions_logged == 3:
		test_results.append("✅ Correct number of actions logged (3)")
	else:
		test_results.append("❌ Expected 3 actions, got %d" % actions_logged)

	# Test 4: Verify session consistency
	if final_session_info.session_id == session_id:
		test_results.append("✅ Session ID remained consistent")
	else:
		test_results.append("❌ Session ID changed during test")

	# Test 5: Test session end
	SemanticActionLogger.end_session()
	var ended_session_info: Dictionary = SemanticActionLogger.get_session_info()

	if not ended_session_info.is_active:
		test_results.append("✅ Session properly ended")
	else:
		test_results.append("❌ Session still active after end")

	# Generate test summary
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
		return DebugAction.Result.new_success(summary)
	else:
		return DebugAction.Result.new_failure(summary, "INTEGRATION_TEST_FAILED")
