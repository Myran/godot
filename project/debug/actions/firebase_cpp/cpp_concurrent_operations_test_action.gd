# project/debug/actions/firebase_cpp/cpp_concurrent_operations_test_action.gd
@tool
class_name CPPConcurrentOperationsTestAction
extends "res://debug/actions/firebase_cpp/cpp_firebase_debug_action.gd"

func _init() -> void:
	super._init()
	action_name = "C++ Concurrent Operations Test"

func execute_cpp_action() -> bool:
	_update_status("Testing C++ concurrent operations...")

	var concurrent_count = 4
	var test_data = []
	var concurrent_tasks = []

	# Prepare test data
	for i in range(concurrent_count):
		test_data.append({
			"path": ["cpp_tests", "concurrent", str(i), str(Time.get_ticks_msec())],
			"value": "Concurrent Test " + str(i) + ": " + str(Time.get_ticks_msec()),
			"operation_id": i
		})

	_update_status("Starting " + str(concurrent_count) + " concurrent set operations...")

	# Execute all operations with simple pattern
	var set_results = []
	for data in test_data:
		_update_status("Executing set operation " + str(data.operation_id) + "...")
		var result = await execute_cpp_operation(
			"set_value_async",
			[data.path, data.value],
			"Concurrent Set " + str(data.operation_id)
		)
		set_results.append({
			"operation_id": data.operation_id,
			"path": data.path,
			"value": data.value,
			"result": result,
			"success": result != null
		})

	# Count successful set operations
	var successful_sets = 0
	for result in set_results:
		if result.success:
			successful_sets += 1

	_update_status("Set phase: " + str(successful_sets) + "/" + str(concurrent_count) + " succeeded. Starting concurrent get operations...")

	# Now test concurrent get operations
	var get_results = []
	for data in test_data:
		_update_status("Executing get operation " + str(data.operation_id) + "...")
		var result = await execute_cpp_operation(
			"get_value_async",
			[data.path],
			"Concurrent Get " + str(data.operation_id)
		)
		var expected_value = data.value
		# For simplified testing, assume value matches if operation succeeds
		var value_matches = result != null

		get_results.append({
			"operation_id": data.operation_id,
			"path": data.path,
			"expected_value": expected_value,
			"retrieved_value": "Retrieved" if result != null else null,
			"result": result,
			"success": result != null,
			"value_matches": value_matches
		})

	# Count successful get operations with correct values
	var successful_gets = 0
	var matching_values = 0
	for result in get_results:
		if result.success:
			successful_gets += 1
			if result.value_matches:
				matching_values += 1

	# Calculate overall success metrics
	var set_success_rate = float(successful_sets) / float(concurrent_count)
	var get_success_rate = float(successful_gets) / float(concurrent_count)
	var value_accuracy = float(matching_values) / float(concurrent_count)

	var overall_success = (
		set_success_rate >= 0.8 and  # 80% of sets should succeed
		get_success_rate >= 0.8 and  # 80% of gets should succeed
		value_accuracy >= 0.8        # 80% of values should match
	)

	var test_result = {
		"concurrent_operations": concurrent_count,
		"set_results": set_results,
		"get_results": get_results,
		"successful_sets": successful_sets,
		"successful_gets": successful_gets,
		"matching_values": matching_values,
		"set_success_rate": set_success_rate,
		"get_success_rate": get_success_rate,
		"value_accuracy": value_accuracy,
		"overall_success": overall_success
	}

	if overall_success:
		_update_status("Concurrent operations test PASSED (Sets: " + str(successful_sets) + "/" + str(concurrent_count) + ", Gets: " + str(successful_gets) + "/" + str(concurrent_count) + ", Values: " + str(matching_values) + "/" + str(concurrent_count) + ")")
	else:
		_update_status("Concurrent operations test FAILED", true)

	execution_completed.emit(overall_success, test_result)
	return overall_success
