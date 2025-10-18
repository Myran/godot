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

	# Enhanced Firebase cleanup for Android test isolation (Task-230)
	# Perform active Firebase cleanup before logger shutdown
	_perform_firebase_cleanup()

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


func _perform_firebase_cleanup() -> void:
	## Enhanced Firebase cleanup as final step before app termination
	## This replaces separate debug action approach (Task-230) with integrated cleanup

	# Only perform Firebase cleanup on Android where resource accumulation occurs
	if OS.get_name() != "Android":
		Log.debug(
			"QuitApplicationEvent: Skipping Firebase cleanup on non-Android platform",
			{"platform": OS.get_name()},
			["debug", "quit", "firebase"]
		)
		return

	Log.info(
		"QuitApplicationEvent: Performing Firebase cleanup (Android test isolation)",
		{"platform": OS.get_name()},
		["debug", "quit", "firebase"]
	)

	# Call FirebaseService cleanup method if available
	if FirebaseService != null and FirebaseService.has_method("shutdown_firebase_connections"):
		# GDScript doesn't have try-catch, use conditional safety checks
		FirebaseService.shutdown_firebase_connections()
		Log.info(
			"QuitApplicationEvent: Firebase cleanup completed successfully",
			{"platform": OS.get_name()},
			["debug", "quit", "firebase"]
		)
	else:
		Log.debug(
			"QuitApplicationEvent: FirebaseService not available or missing cleanup method",
			{"platform": OS.get_name()},
			["debug", "quit", "firebase"]
		)
