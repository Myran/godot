class_name DelayAction
extends DebugAction


func _init() -> void:
	super._init()
	action_name = "system.debug.delay_2s"


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	_update_status("Starting 2-second delay for test isolation...")

	var start_time: int = Time.get_ticks_msec()
	var delay_ms: int = 2000  # 2 seconds

	await Engine.get_main_loop().create_timer(delay_ms / 1000.0).timeout

	var actual_duration: int = Time.get_ticks_msec() - start_time

	var metadata: Dictionary = TestUtils.make_metadata(
		"delay_action",
		{
			"requested_delay_ms": delay_ms,
			"actual_duration_ms": actual_duration,
			"purpose": "test_isolation"
		}
	)

	_update_status("✅ Delay completed - Test isolation ready")
	return TestUtils.make_success_result(
		"Delay completed successfully", actual_duration, action_name, metadata
	)
