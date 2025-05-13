extends Node

## Helper script to ensure tests exit properly after completion
## Add this to test scripts that don't properly exit

var max_test_time: float = 60.0  # Maximum seconds to allow a test to run


func _ready() -> void:
	# Set a maximum timeout for safety
	get_tree().create_timer(max_test_time).timeout.connect(
		func() -> void:
			Log.warning(
				"Auto-quitting test after timeout", {"max_seconds": max_test_time}, [Log.TAG_TEST]
			)
			get_tree().quit(0)
	)


## Call this method when a test completes successfully
func complete_test() -> void:
	Log.info("Test completed successfully, exiting...", {}, [Log.TAG_TEST])
	get_tree().quit(0)


## Call this method when a test fails
func fail_test(reason: String) -> void:
	Log.error("Test failed: " + reason, {}, [Log.TAG_TEST, Log.TAG_ERROR])
	get_tree().quit(1)
