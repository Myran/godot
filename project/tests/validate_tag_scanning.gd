#!/usr/bin/env -S godot --headless --script
# Validation script for tag scanning functionality
extends SceneTree

func _init():
	print("\n======= TAG SCANNING VALIDATION TEST =======")
	
	# Load required classes
	var TagScanner = load("res://addons/advanced_logger/tag_scanner.gd")
	if not TagScanner:
		print("❌ Failed to load TagScanner class")
		quit(1)
	
	# Get settings from config
	var config = ConfigFile.new()
	if config.load("res://addons/advanced_logger/settings.cfg") != OK:
		print("❌ Failed to load settings.cfg")
		quit(1)
	
	# Get tags from settings
	var available_tags: Array = []
	var active_tags: Array = []
	var ignored_tags: Array = []
	
	if config.has_section_key("logger", "available_tags"):
		available_tags = config.get_value("logger", "available_tags")
	
	if config.has_section_key("logger", "active_tags"):
		active_tags = config.get_value("logger", "active_tags")
	
	if config.has_section_key("logger", "ignored_tags"):
		ignored_tags = config.get_value("logger", "ignored_tags")
	
	print("\nCurrent tags in settings:")
	print("  Available tags:", str(available_tags))
	print("  Active tags:", str(active_tags))
	print("  Ignored tags:", str(ignored_tags))
	
	# Run a fresh tag scan to see what tags are found
	print("\nScanning project for Log tags...")
	var scanned_tags: Array = TagScanner.scan_project_for_tags()
	
	print("\nTags found by scanner:", str(scanned_tags))
	
	# Check for tags that are in the scanner results but not in available tags
	var missing_from_available: Array = []
	for tag in scanned_tags:
		if not tag in available_tags:
			missing_from_available.append(tag)
	
	if missing_from_available.size() > 0:
		print("\n⚠️ Found", missing_from_available.size(), "tags that are detected by scanner but missing from available_tags:")
		print("  ", str(missing_from_available))
	else:
		print("\n✅ All scanned tags are already in available_tags")
	
	# Check for tags that are in available but not in scanner results
	var not_found_by_scanner: Array = []
	for tag in available_tags:
		if not tag in scanned_tags:
			not_found_by_scanner.append(tag)
	
	if not_found_by_scanner.size() > 0:
		print("\n⚠️ Found", not_found_by_scanner.size(), "tags in available_tags that were not detected by scanner:")
		print("  ", str(not_found_by_scanner))
		print("  These may be manually added tags or from files not scanned.")
	else:
		print("\n✅ All available tags were detected by scanner")
	
	# Now let's examine the test files to see what tags they use
	print("\nAnalyzing test files for tags:")
	
	var test_files = [
		"res://tests/tag_scanner_test.gd",
		"res://tests/test_logger.gd"
	]
	
	var all_test_tags: Array = []
	
	for file_path in test_files:
		var file_tags = get_tags_from_file(file_path)
		if file_tags.size() > 0:
			print("  ", file_path.get_file(), ":", str(file_tags))
			for tag in file_tags:
				if not tag in all_test_tags:
					all_test_tags.append(tag)
	
	print("\nAll unique tags found in test files:", str(all_test_tags))
	
	# Check data_source tags
	var data_source_tags = get_tags_from_file("res://autoloads/data_source.gd")
	print("\nTags from data_source.gd:", str(data_source_tags))
	
	print("\nTesting exclusion of test directories...")
	# Test scanning without test directories
	var exclude_dirs: Array[String] = ["res://tests/"]
	var scanned_without_tests = TagScanner.scan_project_for_tags(exclude_dirs)
	print("Tags found when excluding tests:", str(scanned_without_tests))
	
	# Check if test-specific tags were excluded
	var test_specific_tags = ["test_tag_1", "test_tag_2"]
	var test_tags_found = false
	for tag in test_specific_tags:
		if tag in scanned_without_tests:
			test_tags_found = true
			print("⚠️ Test tag", tag, "was found despite test directory exclusion")
	
	if not test_tags_found:
		print("✅ Test tags were successfully excluded when skipping test directories")
	
	print("\n======= TAG SCANNING VALIDATION COMPLETE =======")
	quit()

# Helper function to extract tags from a file
func get_tags_from_file(file_path: String) -> Array:
	var tags: Array = []
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("  ❌ Failed to open file:", file_path)
		return tags
	
	var content = file.get_as_text()
	
	# Look for tag constants
	var tag_regex = RegEx.new()
	tag_regex.compile("const\\s+TAG_[A-Za-z0-9_]+\\s*:\\s*String\\s*=\\s*\"([^\"]+)\"")
	
	var tag_matches = tag_regex.search_all(content)
	for match_result in tag_matches:
		if match_result.strings.size() >= 2:
			var tag = match_result.strings[1]
			if not tag in tags:
				tags.append(tag)
	
	# Also look for direct tags in Log calls
	var log_regex = RegEx.new()
	log_regex.compile("Log\\.(debug|info|warning|error|critical)\\s*\\(.*?\\[([^\\]]+)\\]")
	
	var log_matches = log_regex.search_all(content)
	for match_result in log_matches:
		if match_result.strings.size() >= 3:
			var tags_str = match_result.strings[2]
			var tag_items = tags_str.split(",")
			
			for tag_item in tag_items:
				tag_item = tag_item.strip_edges()
				if tag_item.begins_with("\"") and tag_item.ends_with("\""):
					# Direct string
					var tag = tag_item.substr(1, tag_item.length() - 2)
					if not tag in tags:
						tags.append(tag)
				elif tag_item.begins_with("'") and tag_item.ends_with("'"):
					# Single quoted string
					var tag = tag_item.substr(1, tag_item.length() - 2)
					if not tag in tags:
						tags.append(tag)
				elif tag_item.begins_with("TAG_"):
					# This is a tag constant reference, already handled above
					pass
			
	return tags
