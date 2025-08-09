extends Node

var max_test_time: float = 60.0  # Maximum seconds to allow a test to run


func _ready() -> void:
	get_tree().create_timer(max_test_time).timeout.connect(
		func() -> void:
			Log.warning(
				"Auto-quitting test after timeout", {"max_seconds": max_test_time}, [Log.TAG_TEST]
			)
			get_tree().quit(0)
	)


func complete_test() -> void:
	Log.info("Test completed successfully, exiting...", {}, [Log.TAG_TEST])
	get_tree().quit(0)


func fail_test(reason: String) -> void:
	Log.error("Test failed: " + reason, {}, [Log.TAG_TEST, Log.TAG_ERROR])
	get_tree().quit(1)
