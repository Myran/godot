class_name RTDBPathValidationAction
extends RTDBDebugAction


func _init() -> void:
	super._init()  # Call parent to set category = "RTDB"
	action_name = "rtdb.testing.path_validation"
	group = "Path Operations"
	description = "Validates accessibility and structure of various RTDB paths."


func execute_rtdb_action() -> bool:
	_update_status("Executing " + action_name + "...")

	var db: Object = get_firebase_database()
	if not db:
		var error_result: Array = get_last_error_result()
		return false

	_update_status("Validating various RTDB paths...")

	var validation_results: Array[Dictionary] = []

	var test_paths: Array[Dictionary] = [
		{
			"name": "Valid Nested Path",
			"path": create_test_path(["path_validation", "valid_path"]),
			"should_exist": true
		},
		{
			"name": "Non-existent Path",
			"path": create_test_path(["path_validation", "non_existent"]),
			"should_exist": false
		},
		{
			"name": "Deep Nested Path",
			"path": create_test_path(["path_validation", "deep", "nested", "structure", "test"]),
			"should_exist": true
		},
		{"name": "Root Access Path", "path": ["debug_tests"], "should_exist": true}
	]

	for test_case: Dictionary in test_paths:
		var test_path: Array = test_case["path"]
		var test_name: String = test_case["name"]
		var should_exist: bool = test_case["should_exist"]
		if should_exist:
			var test_data: Dictionary = {
				"timestamp": Time.get_ticks_msec(), "path_name": test_name, "validation_test": true
			}
			var result: bool = await execute_simple_operation(
				"set_value_async", test_path, test_data, "Path Setup: " + test_name
			)

	await Engine.get_main_loop().create_timer(0.3).timeout

	for test_case: Dictionary in test_paths:
		var path_result: Dictionary = await _validate_single_path(db, test_case)
		validation_results.append(path_result)

	var successful_validations: int = 0
	var failed_validations: int = 0

	for result: Dictionary in validation_results:
		if result.validation_success:
			successful_validations += 1
		else:
			failed_validations += 1

	var status_msg: String = (
		"Path validation complete: %d successful, %d failed out of %d total"
		% [successful_validations, failed_validations, validation_results.size()]
	)
	_update_status(status_msg)

	Log.debug(
		"RTDBPathValidationAction executed successfully",
		{
			"operation": "path_validation",
			"total_paths": validation_results.size(),
			"successful": successful_validations,
			"failed": failed_validations,
			"results": validation_results
		},
		["test", "rtdb", "path_operations"]
	)

	return true


func _validate_single_path(_db: Variant, test_case: Dictionary) -> Dictionary:
	var path: Array[Variant] = test_case.path
	var path_name: String = test_case.name
	var should_exist: bool = test_case.should_exist

	var result: bool = await execute_simple_operation(
		"get_value_async", path, null, "Path Validation: " + path_name
	)

	await Engine.get_main_loop().create_timer(0.2).timeout

	var path_accessible: bool = result
	var validation_success: bool = path_accessible == should_exist

	return {
		"path_name": path_name,
		"path": path,
		"expected_to_exist": should_exist,
		"actually_accessible": path_accessible,
		"validation_success": validation_success
	}
