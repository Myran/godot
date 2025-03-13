#!/usr/bin/env -S godot --headless --script
# Validation script for tag filtering functionality
extends SceneTree

# Helper function to scan for tag constants, similar to logger_dock.gd's method
func scan_for_tag_constants() -> Array:
	print("  Looking for additional TAG constants...")
	
	var additional_tags = []
	var files_to_check = [
		"res://autoloads/data_source.gd"
	]
	
	for file_path in files_to_check:
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue
			
		var content = file.get_as_text()
		file.close()
		
		# Look for tag constants using regex
		var regex = RegEx.new()
		regex.compile("const\\s+TAG_[A-Za-z0-9_]+\\s*:\\s*String\\s*=\\s*\"([^\"]+)\"")
		
		var matches = regex.search_all(content)
		for match_result in matches:
			if match_result.strings.size() >= 2:
				var tag = match_result.strings[1]
				if not additional_tags.has(tag):
					additional_tags.append(tag)
					print("  Found tag constant:", tag)
	
	return additional_tags

func _init():
	print("\n======= TAG FILTERING VALIDATION TEST =======")
	
	# Load the tag scanner
	var TagScanner = load("res://addons/advanced_logger/tag_scanner.gd")
	if not TagScanner:
		print("❌ Failed to load TagScanner")
		quit(1)
	
	# First, run without excluding any directories
	print("\n1. Scanning with ALL directories included:")
	var exclude_empty: Array[String] = []
	var all_tags = TagScanner.scan_project_for_tags(exclude_empty)
	print("  Found", all_tags.size(), "tags:", str(all_tags))
	
	# Check for test tags
	var found_test_tags = []
	for tag in all_tags:
		if tag.begins_with("test_tag_"):
			found_test_tags.append(tag)
	
	if found_test_tags.size() > 0:
		print("  ✅ Found", found_test_tags.size(), "test tags:", str(found_test_tags))
	else:
		print("  ❌ No test tags found in complete scan")
	
	# Now test with excluding test directories
	print("\n2. Scanning with test directories EXCLUDED:")
	var exclude_dirs: Array[String] = ["res://tests/"]
	var scanner_tags = TagScanner.scan_project_for_tags(exclude_dirs)
	
	# Also manually scan for tag constants like the logger_dock.gd does
	var additional_tags = scan_for_tag_constants()
	
	# Combine the tags (mimicking the behavior in logger_dock.gd)
	var filtered_tags = []
	for tag in scanner_tags:
		filtered_tags.append(tag)
	
	for tag in additional_tags:
		if not filtered_tags.has(tag):
			filtered_tags.append(tag)
	
	print("  Found", filtered_tags.size(), "tags:", str(filtered_tags))
	
	# Check that test tags are now excluded
	var test_tags_after_filter = []
	for tag in filtered_tags:
		if tag.begins_with("test_tag_"):
			test_tags_after_filter.append(tag)
	
	if test_tags_after_filter.size() == 0:
		print("  ✅ No test tags found when excluding test directories")
	else:
		print("  ⚠️ Still found", test_tags_after_filter.size(), 
		      "test tags after excluding test directories:", str(test_tags_after_filter))
	
	# Check what tags were filtered out
	var filtered_out_tags = []
	for tag in all_tags:
		if not filtered_tags.has(tag):
			filtered_out_tags.append(tag)
	
	if filtered_out_tags.size() > 0:
		print("\n3. Tags that were filtered out:")
		print("  ", str(filtered_out_tags))
	else:
		print("\n3. No tags were filtered out")
	
	# Verify data_source.gd tags are still included
	var data_source_tags = ["database", "cache", "firebase", "local_data", "error", "network"]
	var missing_data_source_tags = []
	
	for tag in data_source_tags:
		if not filtered_tags.has(tag):
			missing_data_source_tags.append(tag)
	
	if missing_data_source_tags.size() == 0:
		print("\n4. ✅ All data_source.gd tags are included in the filtered results")
	else:
		print("\n4. ⚠️ Some data_source.gd tags are missing from filtered results:", 
		      str(missing_data_source_tags))
	
	print("\n======= TAG FILTERING VALIDATION COMPLETE =======")
	quit()
