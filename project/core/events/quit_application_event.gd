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


## Execute the quit sequence with proper async logging synchronization
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

	# Platform-specific logging synchronization
	if OS.get_name() == "Android":
		Log.info(
			"Android platform detected - waiting for chunk processing completion",
			{
				"chunks_pending":
				Log.get_android_chunk_count() if Log.has_method("get_android_chunk_count") else -1,
				"platform": "Android"
			},
			["debug", "android", "chunk_processing", "quit"]
		)

		# Wait for Android chunk processing to complete
		# Double await pattern handles race condition where chunks are added after first signal
		if Log.has_method("wait_for_chunk_processing_complete_signal"):
			await Log.wait_for_chunk_processing_complete_signal()
			await Log.wait_for_chunk_processing_complete_signal()

			Log.info(
				"Android chunk processing completed - proceeding with quit",
				{"platform": "Android", "chunks_processed": true},
				["debug", "android", "chunk_processing", "quit"]
			)
		else:
			Log.warning(
				"Android chunk processing signal method not available - proceeding with quit",
				{"platform": "Android", "signal_method_available": false},
				["debug", "android", "chunk_processing", "quit"]
			)
	else:
		Log.info(
			"Desktop platform detected - no chunk processing wait required",
			{"platform": OS.get_name()},
			["debug", "desktop", "quit"]
		)

	# Final logging before quit
	Log.info(
		"QuitApplicationEvent: All synchronization complete - executing quit",
		{
			"platform": OS.get_name(),
			"final_timestamp": Time.get_unix_time_from_system(),
			"logging_synchronized": true
		},
		["debug", "quit", "final"]
	)

	# Actual application termination
	Engine.get_main_loop().quit()
