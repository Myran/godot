#!/usr/bin/env -S godot --headless --script
# Validation script for the Tag Scanner functionality
extends SceneTree

var passed_tests = 0
var total_tests = 0

func _init():
	print("\n========== TAG SCANNER VALIDATION SCRIPT ==========")
	
	# Check if required files exist
	if verify_files():
		# Run tests
		test_scan_functionality()
		
		# Print results
		if passed_tests == total_tests:
			print("\n✅ ALL TESTS PASSED: %d/%d" % [passed_tests, total_tests])
		else:
			print("\n❌ SOME TESTS FAILED: %d/%d passed" % [passed_tests, total_tests])
	else:
		print("\n❌ TEST SKIPPED: Required files not found")
	
	quit()
	
# Verify that required files exist
func verify_files() -> bool:
	print("\n----- Verifying Required Files -----")
	var tag_scanner_path = "res://addons/advanced_logger/tag_scanner.gd"
	var test_file_path = "res://tests/tag_scanner_test.gd"
	
	var file = FileAccess.open(tag_scanner_path, FileAccess.READ)
	var scanner_exists = file != null
	if file != null:
		file.close()
	
	var file2 = FileAccess.open(test_file_path, FileAccess.READ)
	var test_file_exists = file2 != null
	if file2 != null:
		file2.close()
	
	print("  Tag scanner file exists: %s" % scanner_exists)
	print("  Test file exists: %s" % test_file_exists)
	
	return scanner_exists and test_file_exists

# Test the scanner functionality
func test_scan_functionality():
	print("\n----- Testing Tag Scanner Functionality -----")
	
	# Load the LogTagScanner
	var TagScanner = load("res://addons/advanced_logger/tag_scanner.gd")
	if TagScanner == null:
		print("  ❌ Failed to load TagScanner script")
		return
	
	# Test scanning a single file
	var found_tags: Array[String] = []
	TagScanner.scan_file_for_tags("res://tests/tag_scanner_test.gd", found_tags)
	
	print("  Found tags: " + str(found_tags))
	
	# Expected tags from our test file
	var expected_tags = ["ui", "debug", "network", "system", "security", "api", "database", "formatting", "style"]
	
	# Check that each expected tag was found
	var all_found = true
	for tag in expected_tags:
		if not found_tags.has(tag):
			all_found = false
			print("  ❌ Missing expected tag: %s" % tag)
	
	expect_true(all_found, "All expected tags were found")
	expect_true(found_tags.size() >= expected_tags.size(), "Found at least the expected number of tags")
	
	# Test full project scan
	var project_tags = TagScanner.scan_project_for_tags()
	print("  Project scan found %d tags" % project_tags.size())
	expect_true(project_tags.size() > 0, "Project scan found tags")

# Helper functions
func expect_true(condition: bool, message: String):
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  ✓ " + message)
	else:
		print("  ✗ " + message)

func expect_false(condition: bool, message: String):
	expect_true(!condition, message)
