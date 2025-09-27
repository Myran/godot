class_name QuitApplicationEvent extends core.CoreEvent

## Core quit event that centralizes application termination with proper logging synchronization
##
## This event handles all quit scenarios and ensures Android chunk processing completes
## before application termination. It replaces scattered quit logic throughout the codebase
## with a single, reusable quit mechanism.
##
## Usage:
##   core.action(QuitApplicationEvent.new())


func get_serialization_type_name() -> StringName:
	return &"QuitApplicationEvent"


func _init() -> void:
	source = core.EventSource.SYSTEM_CASCADE


## Execute the quit sequence with graceful logger shutdown
func execute() -> void:
	Log.info(
		"QuitApplicationEvent: Starting application termination sequence",
		{
			"platform": OS.get_name(),
			"timestamp": Time.get_unix_time_from_system(),
			"test_id": DebugAction.get_current_test_id()
		},
		["debug", "quit", "core_event"]
	)

	# Use logger's encapsulated graceful shutdown - handles all platform-specific logic internally
	await Log.shutdown_gracefully()

	# Final logging before quit
	Log.info(
		"QuitApplicationEvent: Logger shutdown complete - executing quit",
		{
			"platform": OS.get_name(),
			"final_timestamp": Time.get_unix_time_from_system(),
			"logging_synchronized": true
		},
		["debug", "quit", "final"]
	)

	# Actual application termination
	Engine.get_main_loop().quit()
