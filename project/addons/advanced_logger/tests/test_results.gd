@tool
extends Node
## Test results collector and reporter
##
## Attach this to any test to capture and summarize results.
## Can be used to generate a detailed report for comparing
## before/after refactoring.

var _test_name: String = ""
var _test_results: Array[Dictionary] = []
var _start_time: int = 0
var _end_time: int = 0

func start_test(test_name: String) -> void:
	_test_name = test_name
	_test_results = []
	_start_time = Time.get_ticks_msec()
	print("\n=== Starting Test: %s ===" % test_name)

func end_test() -> void:
	_end_time = Time.get_ticks_msec()
	var duration_ms = _end_time - _start_time
	
	var passed = 0
	var failed = 0
	
	for result in _test_results:
		if result.passed:
			passed += 1
		else:
			failed += 1
	
	print("\n=== Test Completed: %s ===" % _test_name)
	print("Duration: %.2f seconds" % (duration_ms / 1000.0))
	print("Results: %d passed, %d failed (of %d total)" % [passed, failed, _test_results.size()])
	
	# Save results to file if specified
	if _test_name != "":
		save_results_to_file()

func record_result(description: String, passed: bool, details: String = "") -> void:
	var result = {
		"description": description,
		"passed": passed,
		"details": details
	}
	
	_test_results.append(result)
	print("- %s: %s %s" % [description, passed, "✓" if passed else "✗"])
	if details != "":
		print("  Details: %s" % details)

func save_results_to_file() -> void:
	var file_name = "res://addons/advanced_logger/tests/results/%s_%s.txt" % [
		_test_name.to_lower().replace(" ", "_"),
		Time.get_datetime_string_from_system(false, true).replace(":", "-")
	]
	
	# Create results directory if it doesn't exist
	var dir = DirAccess.open("res://addons/advanced_logger/tests/")
	if dir && !dir.dir_exists("results"):
		dir.make_dir("results")
	
	var file = FileAccess.open(file_name, FileAccess.WRITE)
	if file:
		file.store_line("# Test Results: %s" % _test_name)
		file.store_line("Date: %s" % Time.get_datetime_string_from_system())
		file.store_line("Duration: %.2f seconds\n" % ((_end_time - _start_time) / 1000.0))
		
		# Count results
		var passed = 0
		var failed = 0
		for result in _test_results:
			if result.passed:
				passed += 1
			else:
				failed += 1
		
		file.store_line("Summary: %d passed, %d failed (of %d total)\n" % [passed, failed, _test_results.size()])
		
		# Write detailed results
		file.store_line("## Detailed Results\n")
		for result in _test_results:
			file.store_line("- %s: %s" % [
				result.description,
				"PASSED" if result.passed else "FAILED"
			])
			if result.details != "":
				file.store_line("  Details: %s" % result.details)
		
		file.close()
		print("Test results saved to: %s" % file_name)
	else:
		push_error("Failed to save test results to file: %s" % file_name)

# Static utility function to compare test results before and after refactoring
static func compare_results(before_file: String, after_file: String) -> Dictionary:
	var before_results = _load_results_from_file(before_file)
	var after_results = _load_results_from_file(after_file)
	
	var comparison = {
		"before_passed": 0,
		"before_failed": 0,
		"after_passed": 0,
		"after_failed": 0,
		"improved": [],
		"regressed": [],
		"unchanged": []
	}
	
	# Count results
	for result in before_results:
		if result.passed:
			comparison.before_passed += 1
		else:
			comparison.before_failed += 1
	
	for result in after_results:
		if result.passed:
			comparison.after_passed += 1
		else:
			comparison.after_failed += 1
	
	# Compare individual tests
	var before_dict = {}
	for result in before_results:
		before_dict[result.description] = result.passed
	
	for result in after_results:
		var desc = result.description
		if before_dict.has(desc):
			var before_passed = before_dict[desc]
			var after_passed = result.passed
			
			if before_passed == false && after_passed == true:
				comparison.improved.append(desc)
			elif before_passed == true && after_passed == false:
				comparison.regressed.append(desc)
			else:
				comparison.unchanged.append(desc)
		else:
			# New test, not in "before" results
			if result.passed:
				comparison.after_passed += 1
			else:
				comparison.after_failed += 1
	
	return comparison

# Helper to load results from file
static func _load_results_from_file(file_path: String) -> Array:
	var results = []
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file:
		var line = file.get_line()
		while !file.eof_reached():
			if line.begins_with("- "):
				var parts = line.substr(2).split(":", true, 1)
				if parts.size() >= 2:
					var description = parts[0].strip_edges()
					var passed = "PASSED" in parts[1]
					
					results.append({
						"description": description,
						"passed": passed,
						"details": ""
					})
			
			line = file.get_line()
		
		file.close()
	
	return results
