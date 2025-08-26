class_name RestartGameAction extends DebugAction


func _init() -> void:
	super("system.game.restart", _execute_restart)
	set_category("System")
	set_group("Game")
	set_description("Restart the current game scene cleanly")


func _execute_restart() -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	Log.info("User requested game restart via debug action", {}, [Log.TAG_DEBUG, Log.TAG_SYSTEM])

	# Trigger restart through the central event system
	DebugManager.action(DebugManager.DebugEventType.EVENT_RESTART_GAME)

	var duration: int = Time.get_ticks_msec() - start_time

	# Return success - the restart will happen through the main game system
	return DebugActionResult.new_success(
		{
			"message": "Game restart initiated",
			"restart_triggered": true,
			"system": "central_event_bus"
		},
		duration
	)
