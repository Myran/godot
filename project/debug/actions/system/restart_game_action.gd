class_name RestartGameAction extends DebugAction


func _init() -> void:
	super("system.game.restart", _execute_restart)
	set_category("System")
	set_group("Game")
	set_description("Restart the current game scene cleanly")


func _execute_restart() -> DebugActionResult:
	# Use timing helper for the restart operation
	var restart_op: Dictionary = await TestUtils.time_operation(
		"system_restart_game",
		func() -> bool:
			Log.info(
				"User requested game restart via debug action", {}, [Log.TAG_DEBUG, Log.TAG_SYSTEM]
			)

			# Trigger restart through the central event system
			DebugManager.action(DebugManager.DebugEventType.EVENT_RESTART_GAME)

			return true
	)

	var total_duration: int = TestUtils.get_duration_ms(restart_op)

	# Return success - the restart will happen through the main game system
	return TestUtils.make_success_result(
		"Game restart initiated successfully",
		total_duration,
		action_name,
		TestUtils.make_metadata(
			TestConstants.TEST_TYPES.SYSTEM_RESTART_GAME,
			{"restart_triggered": true, "system": "central_event_bus"}
		)
	)
