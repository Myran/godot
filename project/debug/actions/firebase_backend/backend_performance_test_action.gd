# project/debug/actions/firebase_backend/backend_performance_test_action.gd
class_name BackendPerformanceTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "Backend Performance Test"


func execute_backend_action() -> bool:
	_update_status("Testing Firebase Backend performance...")

	var backend = get_firebase_backend_for_testing()
	if not backend:
		return false

	var performance_tests = []
	var test_base_path = ["backend_tests", "performance"]
	var test_timestamp = str(Time.get_ticks_msec())

	# Performance Test 1: Single operation timing
	_update_status("Measuring single operation performance...")
	var single_path = test_base_path + ["single", test_timestamp]
	var single_key = "perf_single_" + test_timestamp
	var single_value = "Performance test single operation"

	var single_start = Time.get_ticks_msec()
	var single_result = await test_backend_async_pattern(
		"set_data", single_path, single_key, single_value, "Perf: Single Operation"
	)
	var single_duration = Time.get_ticks_msec() - single_start

	performance_tests.append(
		{
			"test": "single_operation",
			"success": single_result,
			"duration_ms": single_duration,
			"operation": "set_data"
		}
	)

	# Performance Test 2: Rapid sequential operations
	_update_status("Measuring sequential operations performance...")
	var sequential_operations = 3
	var sequential_durations = []
	var sequential_successes = 0

	for i in range(sequential_operations):
		var seq_path = test_base_path + ["sequential", str(i), test_timestamp]
		var seq_key = "perf_seq_" + str(i) + "_" + test_timestamp
		var seq_value = "Sequential operation " + str(i)

		var seq_start = Time.get_ticks_msec()
		var seq_result = await test_backend_async_pattern(
			"set_data", seq_path, seq_key, seq_value, "Perf: Sequential " + str(i)
		)
		var seq_duration = Time.get_ticks_msec() - seq_start

		sequential_durations.append(seq_duration)
		if seq_result:
			sequential_successes += 1

		# Small delay between operations
		await Engine.get_main_loop().create_timer(0.1).timeout

	var avg_sequential_duration = 0
	for duration in sequential_durations:
		avg_sequential_duration += duration
	avg_sequential_duration = (
		avg_sequential_duration / sequential_operations if sequential_operations > 0 else 0
	)

	performance_tests.append(
		{
			"test": "sequential_operations",
			"total_operations": sequential_operations,
			"successful_operations": sequential_successes,
			"individual_durations": sequential_durations,
			"avg_duration_ms": avg_sequential_duration
		}
	)

	# Performance Test 3: RequestSignalHelper overhead measurement
	_update_status("Measuring RequestSignalHelper overhead...")
	var overhead_path = test_base_path + ["overhead", test_timestamp]
	var overhead_key = "perf_overhead_" + test_timestamp
	var overhead_value = "RequestSignalHelper overhead test"

	var overhead_start = Time.get_ticks_msec()
	var overhead_result = await test_backend_async_pattern(
		"get_data", overhead_path, overhead_key, null, "Perf: Overhead Test"
	)
	var overhead_duration = Time.get_ticks_msec() - overhead_start

	performance_tests.append(
		{
			"test": "request_signal_helper_overhead",
			"success": overhead_result != null,
			"duration_ms": overhead_duration,
			"operation": "get_data"
		}
	)

	# Analyze performance results
	var total_operations = 1 + sequential_operations + 1  # single + sequential + overhead
	var successful_operations = (
		(1 if single_result else 0) + sequential_successes + (1 if overhead_result != null else 0)
	)
	var success_rate = float(successful_operations) / float(total_operations)

	# Performance thresholds (compared to C++ baseline of 1455-3336ms)
	var single_acceptable = single_duration < 5000  # Should be under 5 seconds
	var avg_acceptable = avg_sequential_duration < 5000  # Average should be under 5 seconds
	var overhead_acceptable = overhead_duration < 10000  # Overhead test can be slower

	var performance_acceptable = single_acceptable and avg_acceptable and overhead_acceptable
	var overall_success = success_rate >= 0.8 and performance_acceptable  # 80% success + acceptable performance

	var test_results = {
		"total_operations": total_operations,
		"successful_operations": successful_operations,
		"success_rate": success_rate,
		"performance_acceptable": performance_acceptable,
		"performance_details":
		{
			"single_operation_ms": single_duration,
			"avg_sequential_ms": avg_sequential_duration,
			"overhead_test_ms": overhead_duration,
			"single_acceptable": single_acceptable,
			"avg_acceptable": avg_acceptable,
			"overhead_acceptable": overhead_acceptable
		},
		"performance_tests": performance_tests,
		"backend_performance_validation": overall_success
	}

	if overall_success:
		_update_status("Performance test PASSED (avg: " + str(avg_sequential_duration) + "ms)")
		Log.info(
			"Backend performance validation successful", test_results, ["debug", "backend_firebase"]
		)
	else:
		_update_status(
			"Performance test FAILED (avg: " + str(avg_sequential_duration) + "ms)", true
		)
		Log.error(
			"Backend performance validation failed",
			test_results,
			["debug", "backend_firebase", "error"]
		)

	return overall_success
