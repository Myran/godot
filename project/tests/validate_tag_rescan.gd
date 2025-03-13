#!/usr/bin/env -S godot --headless --script
# Validation script to test the tag scanning and update functionality
extends SceneTree

func _init():
	print("\n======= TAG RESCAN TEST =======")
	
	# Load required classes
	var TagScanner = load("res://addons/advanced_logger/tag_scanner.gd")
	var LoggerDock = load("res://addons/advanced_logger/logger_dock.gd")
	
	if not TagScanner or not LoggerDock:
		print("❌ Failed to load required classes")
		quit(1)
	
	# Get current settings
	var config = ConfigFile.new()
	if config.load("res://addons/advanced_logger/settings.cfg") != OK:
		print("❌ Failed to load settings.cfg")
		quit(1)
	
	# Get current available tags
	var available_tags_before = []
	if config.has_section_key("logger", "available_tags"):
		available_tags_before = config.get_value("logger", "available_tags")
	
	print("Available tags before rescan:", str(available_tags_before))
	
	# Create the dock instance
	var dock_instance = LoggerDock.new()
	get_root().add_child(dock_instance)
	
	print("\nInstantiated LoggerDock, running tag scan...")
	
	# First, run a scan excluding test tags (normal usage)
	var scan_tags_method = dock_instance.get("_on_scan_tags")
	if scan_tags_method and scan_tags_method.is_valid():
		scan_tags_method.call(false)  # false = exclude test tags
		print("✅ Completed scan excluding test tags")
	else:
		print("❌ Failed to call _on_scan_tags method")
	
	# Now run a scan including test tags (for tests and complete scanning)
	if scan_tags_method and scan_tags_method.is_valid():
		scan_tags_method.call(true)  # true = include test tags
		print("✅ Completed scan including test tags")
	else:
		print("❌ Failed to call _on_scan_tags method")
	
	# Load the updated settings
	config = ConfigFile.new()
	if config.load("res://addons/advanced_logger/settings.cfg") != OK:
		print("❌ Failed to load updated settings.cfg")
		quit(1)
	
	# Get updated available tags
	var available_tags_after = []
	if config.has_section_key("logger", "available_tags"):
		available_tags_after = config.get_value("logger", "available_tags")
	
	print("\nAvailable tags after rescan:", str(available_tags_after))
	
	# Check if test tags were included (they should be since we ran with include_test_tags=true)
	var test_tags_found = []
	for tag in available_tags_after:
		if tag.begins_with("test_tag_"):
			test_tags_found.append(tag)
	
	if test_tags_found.size() > 0:
		print("✅ Test tags were properly included when requested:", str(test_tags_found))
	else:
		print("⚠️ No test tags found, even though we ran with include_test_tags=true")
	
	# Check for new tags that were added
	var added_tags = []
	for tag in available_tags_after:
		if not tag in available_tags_before:
			added_tags.append(tag)
	
	if added_tags.size() > 0:
		print("\n✅ Added", added_tags.size(), "new tags:", str(added_tags))
	else:
		print("\nℹ️ No new tags were added")
	
	# Check if our data_source.gd specific tags are now included
	var data_source_tags = ["cache", "firebase", "local_data", "error"]
	var missing_tags = []
	
	for tag in data_source_tags:
		if not tag in available_tags_after:
			missing_tags.append(tag)
	
	if missing_tags.size() > 0:
		print("\n⚠️ Still missing tags from data_source.gd:", str(missing_tags))
	else:
		print("\n✅ All data_source.gd tags are now included!")
	
	# Clean up
	get_root().remove_child(dock_instance)
	dock_instance.queue_free()
	
	print("\n======= TAG RESCAN TEST COMPLETE =======")
	quit()
