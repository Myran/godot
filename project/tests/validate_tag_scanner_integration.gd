#!/usr/bin/env -S godot --headless --script
# Validation script for the Tag Scanner UI integration in LoggerDock
extends SceneTree

var passed_tests = 0
var total_tests = 0

func _init():
	print("\n========== TAG SCANNER INTEGRATION VALIDATION ==========")
	
	# Check if required files exist
	if verify_files():
		# Run tests
		test_dock_integration()
		
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
	var logger_dock_path = "res://addons/advanced_logger/logger_dock.gd"
	var logger_dock_tscn_path = "res://addons/advanced_logger/logger_dock.tscn"
	
	var file1 = FileAccess.open(tag_scanner_path, FileAccess.READ)
	var scanner_exists = file1 != null
	if file1 != null:
		file1.close()
	
	var file2 = FileAccess.open(logger_dock_path, FileAccess.READ)
	var dock_exists = file2 != null
	if file2 != null:
		file2.close()
	
	var file3 = FileAccess.open(logger_dock_tscn_path, FileAccess.READ)
	var tscn_exists = file3 != null
	if file3 != null:
		file3.close()
	
	print("  Tag scanner file exists: %s" % scanner_exists)
	print("  Logger dock file exists: %s" % dock_exists)
	print("  Logger dock scene exists: %s" % tscn_exists)
	
	return scanner_exists and dock_exists and tscn_exists

# Test the dock integration
func test_dock_integration():
	print("\n----- Testing Dock Integration -----")
	
	# Load the LoggerDock script
	var LoggerDockScript = load("res://addons/advanced_logger/logger_dock.gd")
	if LoggerDockScript == null:
		print("  ❌ Failed to load LoggerDock script")
		return
	
	# Check for ScanTagsButton in the tscn file
	var tscn_file = FileAccess.open("res://addons/advanced_logger/logger_dock.tscn", FileAccess.READ)
	var tscn_content = tscn_file.get_as_text()
	tscn_file.close()
	
	var has_scan_button = tscn_content.find("[node name=\"ScanTagsButton\"") >= 0
	expect_true(has_scan_button, "Logger dock scene contains ScanTagsButton")
	
	# Check for scan tags method in the script
	var dock_script = FileAccess.open("res://addons/advanced_logger/logger_dock.gd", FileAccess.READ)
	var dock_content = dock_script.get_as_text()
	dock_script.close()
	
	var has_scan_method = dock_content.find("func _on_scan_tags") >= 0
	expect_true(has_scan_method, "Logger dock has _on_scan_tags method")
	
	var has_initial_scan = dock_content.find("func _initial_tag_scan") >= 0
	expect_true(has_initial_scan, "Logger dock has _initial_tag_scan method")
	
	var has_button_var = dock_content.find("_scan_tags_button") >= 0
	expect_true(has_button_var, "Logger dock has reference to scan tags button")
	
	var has_button_connection = dock_content.find("_scan_tags_button.pressed.connect") >= 0
	expect_true(has_button_connection, "Logger dock connects to scan tags button")

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
