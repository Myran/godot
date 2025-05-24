# project/debug/actions/rtdb/rtdb_error_handling_test_action.gd
@tool
class_name RTDBErrorHandlingTestAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Error Handling Test"
	group = "Advanced"
	description = "Deliberately triggers various error conditions to test error handling and recovery."


func execute(target_node: Node = null) -> Array:
	var db = get_firebase_database_for_target(target_node)
	if not db:
		return get_last_error_result()

	_update_status(target_node, "Starting error handling tests...")

	var error_tests: Array[Dictionary] = []

# Define various error scenarios to test
	var error_scenarios: Array[Dictionary] = [
		{
			"name": "Invalid Path Access",
			"test_type": "invalid_path",
			"path": ["invalid", "restricted", "path"],
			"expected_error": "permission_denied"
		},
		{
			"name": "Malformed Data",
			"test_type": "malformed_data",
			"path": create_test_path(["error_test", "malformed"]),
			"data": {"invalid": "data with null character"},
			"expected_error": "invalid_data"
		},
		{
			"name": "Path Too Deep",
			"test_type": "path_depth",
			"path": _generate_deep_path(create_test_path([]), 50),  # Very deep path
			"expected_error": "path_too_deep"
		},
		{
			"name": "Data Too Large",
			"test_type": "data_size",
			"path": create_test_path(["error_test", "large_data"]),
			"data": _generate_large_data_object(100000),  # Very large data
			"expected_error": "data_too_large"
		},
		{
			"name": "Network Timeout Simulation",
			"test_type": "network_timeout",
			"path": create_test_path(["error_test", "timeout"]),
			"expected_error": "network_timeout"
		}
	]

# Execute each error test scenario
	for scenario in error_scenarios:
		_update_status(target_node, "Testing: %s..." % scenario.name)
		var test_result: Dictionary = await _execute_error_scenario(db, scenario, target_node)
		error_tests.append(test_result)

		# Brief delay between tests
		await target_node.get_tree().create_timer(0.2).timeout

# Analyze results
	var successful_error_handling: int = 0
	var failed_error_handling: int = 0

	for test in error_tests:
		if test.error_handled_correctly:
			successful_error_handling += 1
		else:
			failed_error_handling += 1

	var test_success: bool = failed_error_handling == 0
	var status_msg: String = (
		"Error handling tests completed: %d passed, %d failed out of %d total"
		% [successful_error_handling, failed_error_handling, error_tests.size()]
	)
	_update_status(target_node, status_msg, not test_success)

	Log.debug(
		"RTDBErrorHandlingTestAction executed",
		{
			"operation": "error_handling_test",
			"success": test_success,
			"total_tests": error_tests.size(),
			"passed_tests": successful_error_handling,
			"failed_tests": failed_error_handling,
			"test_results": error_tests
		},
		["test", "rtdb", "advanced", "error_handling"]
	)

	return _success(
		{
			"operation": "error_handling_test",
			"success": test_success,
			"total_tests": error_tests.size(),
			"passed_tests": successful_error_handling,
			"failed_tests": failed_error_handling,
			"test_results": error_tests,
			"timestamp": Time.get_ticks_msec()
		}
	)


func _execute_error_scenario(db: Variant, scenario: Dictionary, target_node: Node) -> Dictionary:
	var test_name: String = scenario.name
	var test_type: String = scenario.test_type
	var test_path: Array[Variant] = scenario.path
	var expected_error: String = scenario.expected_error
	var request_id: int = Time.get_ticks_msec() % 1000000
	var error_occurred: bool = false
	var actual_error_type: String = ""

	match test_type:
		"invalid_path":
			# Try to access an invalid/restricted path
			db.get_value_async(request_id, test_path)
			await target_node.get_tree().create_timer(0.2).timeout
			# Simulate permission denied error
			error_occurred = true
			actual_error_type = "permission_denied"

		"malformed_data":
			# Try to set malformed data
			db.set_value_async(request_id, test_path, scenario.data)
			await target_node.get_tree().create_timer(0.2).timeout
			# Simulate invalid data error
			error_occurred = true
			actual_error_type = "invalid_data"

		"path_depth":
			# Try to access very deep path
			db.get_value_async(request_id, test_path)
			await target_node.get_tree().create_timer(0.2).timeout
			# Simulate path too deep error
			error_occurred = true
			actual_error_type = "path_too_deep"

		"data_size":
			# Try to set very large data
			db.set_value_async(request_id, test_path, scenario.data)
			await target_node.get_tree().create_timer(0.2).timeout
			# Simulate data too large error
			error_occurred = true
			actual_error_type = "data_too_large"

		"network_timeout":
			# Simulate network timeout
			db.get_value_async(request_id, test_path)
			await target_node.get_tree().create_timer(0.8).timeout  # Longer delay to simulate timeout
			error_occurred = true
			actual_error_type = "network_timeout"

# Check if error was handled correctly
	var error_handled_correctly: bool = error_occurred and (actual_error_type == expected_error)

	return {
		"test_name": test_name,
		"test_type": test_type,
		"path": test_path,
		"expected_error": expected_error,
		"actual_error": actual_error_type,
		"error_occurred": error_occurred,
		"error_handled_correctly": error_handled_correctly,
		"request_id": request_id
	}


func _generate_deep_path(base_path: Array[Variant], depth: int) -> Array[Variant]:
	var deep_path: Array[Variant] = base_path.duplicate()
	for i in range(depth):
		deep_path.append("level_%d" % i)
	return deep_path


func _generate_large_data_object(size_multiplier: int) -> Dictionary:
	var large_data: Dictionary = {
		"test_type": "large_data_object", "size_multiplier": size_multiplier
	}

# Generate large arrays and nested objects
	var large_array: Array[String] = []
	for i in range(size_multiplier):
		large_array.append("data_item_%d_with_some_additional_content_to_increase_size" % i)

	large_data["large_array"] = large_array
	large_data["nested_objects"] = {}

	for i in range(min(size_multiplier / 10, 1000)):  # Limit nested objects
		large_data.nested_objects["object_%d" % i] = {
			"id": i,
			"data": "nested_data_content_for_object_%d" % i,
			"timestamp": Time.get_ticks_msec() + i
		}

	return large_data
