# test_tag_capitalization.gd
@tool
extends Node

# This script tests the tag capitalization feature in the LoggerDock
# It can be run from the editor or from the command line

# Reference to the LoggerDock class
const LoggerDockClass = preload("res://addons/advanced_logger/logger_dock.gd")

func _ready():
	print("Starting Tag Capitalization Test")
	run_tests()
	
func run_tests():
	test_format_tag_for_display()
	test_tag_display_vs_storage()
	print("Tag Capitalization Test Complete")
	
# Test the _format_tag_for_display method
func test_format_tag_for_display():
	var dock = LoggerDockClass.new()
	var test_cases = [
		"network",
		"database", 
		"cache",
		"error",
		"mixed_CASE_tag",
		"",  # Testing empty string
		"a",  # Testing single character
		"already_Capitalized"
	]
	
	var all_passed = true
	for test_case in test_cases:
		var formatted = dock._format_tag_for_display(test_case)
		var expected = test_case.is_empty() ? "" : test_case.substr(0, 1).capitalize() + test_case.substr(1)
		var passed = formatted == expected
		all_passed = all_passed and passed
		print("Test case: '%s' -> '%s' | Expected: '%s' | %s" % 
			[test_case, formatted, expected, "PASSED" if passed else "FAILED"])
	
	print("format_tag_for_display test: %s" % ("PASSED" if all_passed else "FAILED"))

# Test that tag display is capitalized but internal storage remains untouched
func test_tag_display_vs_storage():
	var dock = LoggerDockClass.new()
	
	# Mock the necessary UI components
	dock._available_tags_list = ItemList.new()
	dock._tags_list = ItemList.new()
	dock._ignored_tags_list = ItemList.new()
	
	# Set up test tags
	dock._available_tags = ["test_tag", "another_tag"]
	dock._active_tags = ["active_tag"]
	dock._ignored_tags = ["ignored_tag"]
	
	# Refresh the lists
	dock._refresh_tags_lists()
	
	# Check available tags
	var available_display = dock._available_tags_list.get_item_text(0)
	var available_stored = dock._available_tags_list.get_item_metadata(0)
	
	# Check active tags
	var active_display = dock._tags_list.get_item_text(0)
	var active_stored = dock._tags_list.get_item_metadata(0)
	
	# Check ignored tags
	var ignored_display = dock._ignored_tags_list.get_item_text(0)
	var ignored_stored = dock._ignored_tags_list.get_item_metadata(0)
	
	# Verify results
	print("\nDisplay vs Storage Test Results:")
	print("Available Tag - Display: '%s' | Storage: '%s' | %s" % 
		[available_display, available_stored, "PASSED" if available_display == "Test_tag" and available_stored == "test_tag" else "FAILED"])
	
	print("Active Tag - Display: '%s' | Storage: '%s' | %s" % 
		[active_display, active_stored, "PASSED" if active_display == "Active_tag" and active_stored == "active_tag" else "FAILED"])
	
	print("Ignored Tag - Display: '%s' | Storage: '%s' | %s" % 
		[ignored_display, ignored_stored, "PASSED" if ignored_display == "Ignored_tag" and ignored_stored == "ignored_tag" else "FAILED"])
