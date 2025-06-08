# project/debug/actions/firebase_backend/backend_timer_manager_test_action.gd
class_name BackendTimerManagerTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "Backend Timer Manager Test"


func execute_backend_action() -> bool:
	_update_status("Testing Firebase Backend timer management...")

	var backend = get_firebase_backend_for_testing()
	if not backend:
		return false

	# Test 1: Normal operation within timeout
	_update_status("Testing normal timeout handling...")
	var test_path = ["backend_tests", "timer_manager", "normal"]
	var test_key = "timer_test_" + str(Time.get_ticks_msec())
	var test_value = "Timer Test: " + str(Time.get_ticks_msec())

	var start_time = Time.get_ticks_msec()
	var normal_result = await test_backend_async_pattern(
		"set_data", test_path, test_key, test_value, "Timer Normal"
	)
	var normal_duration = Time.get_ticks_msec() - start_time

	# Test 2: Multiple rapid requests (stress test RequestSignalHelper)
	_update_status("Testing rapid request handling...")
	var rapid_requests = 3
	var rapid_success = 0
	var total_rapid_duration = 0

	for i in range(rapid_requests):
		var rapid_path = ["backend_tests", "timer_manager", "rapid", str(i)]
		var rapid_key = "rapid_" + str(i) + "_" + str(Time.get_ticks_msec())
		var rapid_value = "Rapid Test " + str(i)

		start_time = Time.get_ticks_msec()
		var rapid_result = await test_backend_async_pattern(
			"set_data", rapid_path, rapid_key, rapid_value, "Rapid " + str(i)
		)
		var rapid_duration = Time.get_ticks_msec() - start_time

		if rapid_result:
			rapid_success += 1
		total_rapid_duration += rapid_duration

		# Small delay between requests
		await Engine.get_main_loop().create_timer(0.05).timeout

	var rapid_success_rate = float(rapid_success) / float(rapid_requests)
	var avg_rapid_duration = total_rapid_duration / rapid_requests

	# Evaluate results
	var normal_ok = normal_result and normal_duration < 5000  # Under 5 seconds
	var rapid_ok = rapid_success_rate >= 0.8  # 80% success rate
	var overall_success = normal_ok and rapid_ok

	var test_results = {
		"normal_test":
		{"success": normal_result, "duration_ms": normal_duration, "within_timeout": normal_ok},
		"rapid_test":
		{
			"successful_requests": rapid_success,
			"total_requests": rapid_requests,
			"success_rate": rapid_success_rate,
			"avg_duration_ms": avg_rapid_duration,
			"passed": rapid_ok
		},
		"timer_manager_validation": overall_success
	}

	if overall_success:
		_update_status("Timer Manager test PASSED")
		Log.info(
			"Backend TimerManager validation successful",
			test_results,
			["debug", "backend_firebase"]
		)
	else:
		_update_status("Timer Manager test FAILED", true)
		Log.error(
			"Backend TimerManager validation failed",
			test_results,
			["debug", "backend_firebase", "error"]
		)

	return overall_success
