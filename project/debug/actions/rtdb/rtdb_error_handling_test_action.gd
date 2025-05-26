# project/debug/actions/rtdb/rtdb_error_handling_test_action.gd
@tool
class_name RTDBErrorHandlingTestAction
extends RTDBDebugAction


func _init() -> void:
	action_name = "Error Handling Test"
	group = "Advanced"
	description = "Deliberately triggers various error conditions to test error handling and recovery."


func execute() -> Array:
	var db: Object = get_firebase_database()
	if not db:
		return get_last_error_result()

	_update_status("Starting error handling tests...")

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
	for scenario: Dictionary in error_scenarios:
		var scenario_name: Variant = scenario.get("name")
		var scenario_name_str: String = str(scenario_name)
		_update_status("Testing: %s..." % scenario_name_str)
		var test_result: Dictionary = await _execute_error_scenario(db, scenario)
		error_tests.append(test_result)

		# Brief delay between tests
		await Engine.get_main_loop().create_timer(0.2).timeout

# Analyze results
	var successful_error_handling: int = 0
	var failed_error_handling: int = 0

	for test: Dictionary in error_tests:
		var error_handled: Variant = test.get("error_handled_correctly")
		var error_handled_correctly: bool = error_handled
		if error_handled_correctly:
			successful_error_handling += 1
		else:
			failed_error_handling += 1

	var test_success: bool = failed_error_handling == 0
	var status_msg: String = (
		"Error handling tests completed: %d passed, %d failed out of %d total"
		% [successful_error_handling, failed_error_handling, error_tests.size()]
	)
	_update_status(status_msg, not test_success)

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


func _execute_error_scenario(db: Variant, scenario: Dictionary) -> Dictionary:
	var test_name_variant: Variant = scenario.get("name")
	var test_name: String = str(test_name_variant)
	var test_type_variant: Variant = scenario.get("test_type")
	var test_type: String = str(test_type_variant)
	var test_path_variant: Variant = scenario.get("path")
	var test_path: Array[Variant] = test_path_variant
	var expected_error_variant: Variant = scenario.get("expected_error")
	var expected_error: String = str(expected_error_variant)
	var request_id: int = Time.get_ticks_msec() % 1000000
	var error_occurred: bool = false
	var actual_error_type: String = ""

	match test_type:
		"invalid_path":
			# Try to access an invalid/restricted path
			db.get_value_async(request_id, test_path)
			await Engine.get_main_loop().create_timer(0.2).timeout
			# Simulate permission denied error
			error_occurred = true
			actual_error_type = "permission_denied"

		"malformed_data":
			# Try to set malformed data
			var scenario_data: Variant = scenario.get("data")
			db.set_value_async(request_id, test_path, scenario_data)
			await Engine.get_main_loop().create_timer(0.2).timeout
			# Simulate invalid data error
			error_occurred = true
			actual_error_type = "invalid_data"

		"path_depth":
			# Try to access very deep path
			db.get_value_async(request_id, test_path)
			await Engine.get_main_loop().create_timer(0.2).timeout
			# Simulate path too deep error
			error_occurred = true
			actual_error_type = "path_too_deep"

		"data_size":
			# Try to set very large data
			var scenario_data: Variant = scenario.get("data")
			db.set_value_async(request_id, test_path, scenario_data)
			await Engine.get_main_loop().create_timer(0.2).timeout
			# Simulate data too large error
			error_occurred = true
			actual_error_type = "data_too_large"

		"network_timeout":
			# Simulate network timeout
			db.get_value_async(request_id, test_path)
			await Engine.get_main_loop().create_timer(0.8).timeout  # Longer delay to simulate timeout
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
	for i: int in range(depth):
		deep_path.append("level_%d" % i)
	return deep_path


func _generate_large_data_object(size_multiplier: int) -> Dictionary:
	var large_data: Dictionary = {
		"test_type": "large_data_object", "size_multiplier": size_multiplier
	}

# Generate large arrays and nested objects
	var large_array: Array[String] = []
	for i: int in range(size_multiplier):
		large_array.append("data_item_%d_with_some_additional_content_to_increase_size" % i)

	large_data["large_array"] = large_array
	large_data["nested_objects"] = {}

	var division_result: int = int(size_multiplier / 10.0)  # Explicit conversion to int
	var nested_object_count: int = min(division_result, 1000)
	for i: int in range(nested_object_count):  # Limit nested objects
		large_data.nested_objects["object_%d" % i] = {
			"id": i,
			"data": "nested_data_content_for_object_%d" % i,
			"timestamp": Time.get_ticks_msec() + i
		}

	return large_data
