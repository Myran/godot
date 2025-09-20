class_name BackendPerformanceTestAction
extends BackendFirebaseDebugAction


func _init() -> void:
	super._init()
	action_name = "backend.firebase.performance"
	auto_continue = false  # Sequential execution required for Firebase operations


func _execute_action_logic(_params: Dictionary = {}) -> DebugActionResult:
	var start_time: int = Time.get_ticks_msec()

	var backend: DataBackend = get_firebase_backend_for_testing()
	if not backend:
		return DebugActionResult.new_failure(
			"Failed to get Firebase backend for testing",
			"BACKEND_UNAVAILABLE",
			DebugActionResult.ErrorCategory.FIREBASE,
			{"backend_available": false},
			0,
			action_name
		)

	var performance_tests: Array[Dictionary] = []
	var test_base_path: Array[Variant] = ["backend_tests", "performance"]
	var test_timestamp: String = str(Time.get_ticks_msec())

	var single_path: Array[Variant] = test_base_path + ["single", test_timestamp]
	var single_key: String = "perf_single_" + test_timestamp
	var single_value: String = "Performance test single operation"

	var single_start: int = Time.get_ticks_msec()
	var single_result: Variant = await test_backend_async_pattern(
		"set_data", single_path, single_key, single_value, "Perf: Single Operation"
	)
	var single_duration: int = Time.get_ticks_msec() - single_start

	performance_tests.append(
		{
			"test": "single_operation",
			"success": single_result != null,
			"duration_ms": single_duration,
			"operation": "set_data"
		}
	)

	var sequential_operations: int = 3
	var sequential_durations: Array[int] = []
	var sequential_successes: int = 0

	for i: int in range(sequential_operations):
		var seq_path: Array[Variant] = test_base_path + ["sequential", str(i), test_timestamp]
		var seq_key: String = "perf_seq_" + str(i) + "_" + test_timestamp
		var seq_value: String = "Sequential operation " + str(i)

		var seq_start: int = Time.get_ticks_msec()
		var seq_result: Variant = await test_backend_async_pattern(
			"set_data", seq_path, seq_key, seq_value, "Perf: Sequential " + str(i)
		)
		var seq_duration: int = Time.get_ticks_msec() - seq_start

		sequential_durations.append(seq_duration)
		if seq_result:
			sequential_successes += 1

	var avg_sequential_duration: int = 0
	for duration: int in sequential_durations:
		avg_sequential_duration += duration
	avg_sequential_duration = (
		int(float(avg_sequential_duration) / float(sequential_operations))
		if sequential_operations > 0
		else 0
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

	var overhead_path: Array[Variant] = test_base_path + ["overhead", test_timestamp]
	var overhead_key: String = "perf_overhead_" + test_timestamp
	var overhead_value: String = "RequestSignalHelper overhead test"

	# First set the data so we can reliably get it back for overhead testing
	await test_backend_async_pattern(
		"set_data", overhead_path, overhead_key, overhead_value, "Perf: Overhead Setup"
	)

	var overhead_start: int = Time.get_ticks_msec()
	var overhead_result: Variant = await test_backend_async_pattern(
		"get_data", overhead_path, overhead_key, null, "Perf: Overhead Test"
	)
	var overhead_duration: int = Time.get_ticks_msec() - overhead_start

	performance_tests.append(
		{
			"test": "request_signal_helper_overhead",
			"success": overhead_result != null,
			"duration_ms": overhead_duration,
			"operation": "get_data"
		}
	)

	var total_operations: int = 1 + sequential_operations + 1  # single + sequential + overhead
	var successful_operations: int = (
		(1 if single_result else 0) + sequential_successes + (1 if overhead_result != null else 0)
	)
	var success_rate: float = float(successful_operations) / float(total_operations)

	var single_acceptable: bool = single_duration < 5000  # Should be under 5 seconds
	var avg_acceptable: bool = avg_sequential_duration < 5000  # Average should be under 5 seconds
	var overhead_acceptable: bool = overhead_duration < 10000  # Overhead test can be slower

	var performance_acceptable: bool = single_acceptable and avg_acceptable and overhead_acceptable
	var overall_success: bool = success_rate >= 0.8 and performance_acceptable  # 80% success + acceptable performance

	var total_duration: int = Time.get_ticks_msec() - start_time

	var performance_metrics: Dictionary = {
		"operations_per_second": float(total_operations) / (float(total_duration) / 1000.0),
		"average_latency_ms": float(total_duration) / float(total_operations),
		"single_operation_ms": single_duration,
		"avg_sequential_ms": avg_sequential_duration,
		"overhead_test_ms": overhead_duration,
		"p95_latency_ms":
		_calculate_p95_latency(
			_combine_duration_arrays(sequential_durations, single_duration, overhead_duration)
		),
		"total_operations": total_operations,
		"successful_operations": successful_operations,
		"success_rate": success_rate
	}

	var performance_thresholds: Dictionary = {
		"max_single_operation_ms": 5000,
		"max_avg_sequential_ms": 5000,
		"max_overhead_ms": 10000,
		"min_success_rate": 0.8,
		"max_avg_latency_ms": 6000
	}

	return DebugActionResult.new_performance_result(
		performance_tests,  # Array of performance test results
		overall_success,
		performance_thresholds,
		action_name,
		total_duration,
		{
			"test_type": "backend_performance",
			"backend_type": "firebase_rtdb",
			"performance_metrics": performance_metrics,
			"thresholds_met":
			{
				"single_acceptable": single_acceptable,
				"avg_acceptable": avg_acceptable,
				"overhead_acceptable": overhead_acceptable
			},
			"test_timestamp": test_timestamp
		}
	)


func _calculate_p95_latency(durations: Array[int]) -> int:
	if durations.is_empty():
		return 0

	var sorted_durations: Array[int] = durations.duplicate()
	sorted_durations.sort()

	var p95_index: int = int(float(sorted_durations.size()) * 0.95)
	if p95_index >= sorted_durations.size():
		p95_index = sorted_durations.size() - 1

	return sorted_durations[p95_index]


func _combine_duration_arrays(
	base_durations: Array[int], single_duration: int, overhead_duration: int
) -> Array[int]:
	var combined_durations: Array[int] = base_durations.duplicate()
	combined_durations.append(single_duration)
	combined_durations.append(overhead_duration)
	return combined_durations
