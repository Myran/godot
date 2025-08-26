class_name TestSemanticLoggingAction
extends DebugAction


func _init() -> void:
	super("system.debug.test_semantic_logging", _execute_semantic_logging_test)
	set_category("System")
	set_group("Debug")
	set_description(
		"Test the semantic action logging system by starting a session and logging sample actions"
	)


func _execute_semantic_logging_test() -> DebugActionResult:
	var session_id: String = SessionManager.get_current_session_id()

	Log.info(
		"Using current semantic logging session",
		{"session_id": session_id},
		["semantic_action", "test"]
	)

	SemanticActionLogger.log_action(
		"test.manual_action", {"test_parameter": "test_value", "number_parameter": 42}
	)

	SemanticActionLogger.log_action("test.another_action", {"action_type": "verification"})

	var session_info: Dictionary = SemanticActionLogger.get_session_info()

	Log.info(
		"Semantic logging test completed",
		{"session_info": session_info, "actions_logged": session_info.action_count},
		["semantic_action", "test"]
	)

	return DebugActionResult.new_success(
		(
			"Semantic logging test completed successfully. Session ID: %s, Actions logged: %d"
			% [session_id, session_info.action_count]
		)
	)
