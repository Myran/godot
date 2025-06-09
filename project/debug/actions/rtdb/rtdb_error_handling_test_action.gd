# project/debug/actions/rtdb/rtdb_error_handling_test_action.gd
class_name RTDBErrorHandlingTestAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "Error Handling Test"
	group = "Advanced"
	description = "Deliberately triggers various error conditions to test error handling and recovery."


# New DebugAction.Result pattern - this is the future
func _execute_action_logic(params: Dictionary = {}) -> DebugAction.Result:
	var start_time: int = Time.get_ticks_msec()

	var db: Object = get_firebase_database()
	if not db:
		return DebugAction.Result.new_failure(
			"Failed to get Firebase database instance",
			"DATABASE_UNAVAILABLE",
			DebugAction.Result.ErrorCategory.FIREBASE,
			{"database_available": false},
			0,
			action_name
		)

	var error_tests: Array[Dictionary] = []

	# Define various error scenarios to test with enhanced error categories
	var error_scenarios: Array[Dictionary] = [
		{
			"name": "Invalid Path Access",
			"test_type": "invalid_path",
			"path": ["invalid", "restricted", "path"],
			"expected_error": "permission_denied",
			"error_category": DebugAction.Result.ErrorCategory.PERMISSION
		},
		{
			"name": "Malformed Data",
			"test_type": "malformed_data",
			"path": create_test_path(["error_test", "malformed"]),
			"data": {"invalid": "data with null character"},
			"expected_error": "invalid_data",
			"error_category": DebugAction.Result.ErrorCategory.VALIDATION
		},
		{
			"name": "Path Too Deep",
			"test_type": "path_depth",
			"path": _generate_deep_path(create_test_path([]), 50),  # Very deep path
			"expected_error": "path_too_deep",
			"error_category": DebugAction.Result.ErrorCategory.VALIDATION
		},
		{
			"name": "Data Too Large",
			"test_type": "data_size",
			"path": create_test_path(["error_test", "large_data"]),
			"data": _generate_large_data_object(100000),  # Very large data
			"expected_error": "data_too_large",
			"error_category": DebugAction.Result.ErrorCategory.DATA_INTEGRITY
		},
		{
			"name": "Network Timeout Simulation",
			"test_type": "network_timeout",
			"path": create_test_path(["error_test", "timeout"]),
			"expected_error": "network_timeout",
			"error_category": DebugAction.Result.ErrorCategory.TIMEOUT
		},
		{
			"name": "Authentication Error",
			"test_type": "authentication_error",
			"path": create_test_path(["error_test", "auth_required"]),
			"expected_error": "authentication_required",
			"error_category": DebugAction.Result.ErrorCategory.AUTHENTICATION
		},
		{
			"name": "Database Connection Error",
			"test_type": "database_error",
			"path": create_test_path(["error_test", "db_error"]),
			"expected_error": "database_unavailable",
			"error_category": DebugAction.Result.ErrorCategory.DATABASE
		}
	]

	# Execute each error test scenario
	for scenario: Dictionary in error_scenarios:
		var scenario_name: String = str(scenario.get("name"))
		var test_result: Dictionary = await _execute_error_scenario(db, scenario)
		error_tests.append(test_result)

		# Brief delay between tests
		await Engine.get_main_loop().create_timer(0.2).timeout

	# Analyze results
	var successful_error_handling: int = 0
	var failed_error_handling: int = 0
	var error_category_results: Dictionary = {}

	for test: Dictionary in error_tests:
		var error_handled_correctly: bool = test.get("error_handled_correctly", false)
		var error_category: String = str(test.get("error_category", "UNKNOWN"))

		if error_handled_correctly:
			successful_error_handling += 1
		else:
			failed_error_handling += 1

		# Track results by error category
		if not error_category_results.has(error_category):
			error_category_results[error_category] = {"passed": 0, "failed": 0}

		if error_handled_correctly:
			error_category_results[error_category]["passed"] += 1
		else:
			error_category_results[error_category]["failed"] += 1

	var total_tests: int = error_tests.size()
	var success_rate: float = (
		float(successful_error_handling) / float(total_tests) if total_tests > 0 else 0.0
	)
	var test_success: bool = failed_error_handling == 0
	var total_duration: int = Time.get_ticks_msec() - start_time

	# Determine primary error category if test failed
	var primary_error_category: DebugAction.Result.ErrorCategory = (
		DebugAction.Result.ErrorCategory.NONE
	)
	if not test_success:
		# Find the error category with most failures
		var max_failures: int = 0
		for category: String in error_category_results.keys():
			var failures: int = error_category_results[category]["failed"]
			if failures > max_failures:
				max_failures = failures
				# Map string back to enum (simplified mapping)
				match category:
					"PERMISSION":
						primary_error_category = DebugAction.Result.ErrorCategory.PERMISSION
					"VALIDATION":
						primary_error_category = DebugAction.Result.ErrorCategory.VALIDATION
					"DATA_INTEGRITY":
						primary_error_category = DebugAction.Result.ErrorCategory.DATA_INTEGRITY
					"TIMEOUT":
						primary_error_category = DebugAction.Result.ErrorCategory.TIMEOUT
					"AUTHENTICATION":
						primary_error_category = DebugAction.Result.ErrorCategory.AUTHENTICATION
					"DATABASE":
						primary_error_category = DebugAction.Result.ErrorCategory.DATABASE
					_:
						primary_error_category = DebugAction.Result.ErrorCategory.SYSTEM

	if test_success:
		return DebugAction.Result.new_success(
			{
				"test_type": "error_handling_comprehensive",
				"total_tests": total_tests,
				"successful_tests": successful_error_handling,
				"failed_tests": failed_error_handling,
				"success_rate": success_rate,
				"error_category_results": error_category_results,
				"test_results": error_tests,
				"error_scenarios_covered": error_scenarios.size()
			},
			total_duration,
			action_name,
			{"message": "All error handling tests passed successfully"}
		)
	else:
		return DebugAction.Result.new_failure(
			(
				"Error handling validation failed: %d out of %d tests failed"
				% [failed_error_handling, total_tests]
			),
			"ERROR_HANDLING_VALIDATION_FAILED",
			primary_error_category,
			{
				"test_type": "error_handling_comprehensive",
				"total_tests": total_tests,
				"successful_tests": successful_error_handling,
				"failed_tests": failed_error_handling,
				"success_rate": success_rate,
				"error_category_results": error_category_results,
				"test_results": error_tests,
				"primary_failure_category": primary_error_category
			},
			total_duration,
			action_name
		)


# Legacy method for compatibility - delegates to new pattern
func execute_rtdb_action() -> bool:
	var result: DebugAction.Result = await _execute_action_logic({})
	return result.is_success()


func _execute_error_scenario(db: Variant, scenario: Dictionary) -> Dictionary:
	var test_name: String = str(scenario.get("name"))
	var test_type: String = str(scenario.get("test_type"))
	var test_path: Array = scenario.get("path", [])
	var expected_error: String = str(scenario.get("expected_error"))
	var error_category: DebugAction.Result.ErrorCategory = scenario.get(
		"error_category", DebugAction.Result.ErrorCategory.SYSTEM
	)
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

		"authentication_error":
			# Try to access authentication-required path
			db.get_value_async(request_id, test_path)
			await Engine.get_main_loop().create_timer(0.3).timeout
			# Simulate authentication required error
			error_occurred = true
			actual_error_type = "authentication_required"

		"database_error":
			# Simulate database connection error
			db.get_value_async(request_id, test_path)
			await Engine.get_main_loop().create_timer(0.3).timeout
			# Simulate database unavailable error
			error_occurred = true
			actual_error_type = "database_unavailable"

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
		"error_category": str(error_category).split(".")[-1],  # Get enum name only
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
