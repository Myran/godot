@tool
class_name LogTagScanner
extends RefCounted
## Utility for scanning project files to find Log tags

# Preload dependencies
const TagManager = preload("res://addons/advanced_logger/utils/tag_manager.gd")
const ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")

## Scans the project for Log method calls and extracts tags
##
## Parameters:
## - exclude_dirs: Array of directory paths to exclude from scanning (e.g. ["res://tests/"])
##
## Returns an array of unique tags found
static func scan_project_for_tags(exclude_dirs: Array[String] = []) -> Array[String]:
	var found_tags: Array[String] = []

	# Add level tags first - use exact constants from Logger
	var Logger = load("res://addons/advanced_logger/core/logger.gd")

	# Check if Logger loaded successfully
	if ALogger:
		found_tags.append(ALogger.TAG_LEVEL_DEBUG)
		found_tags.append(ALogger.TAG_LEVEL_INFO)
		found_tags.append(ALogger.TAG_LEVEL_WARNING)
		found_tags.append(ALogger.TAG_LEVEL_ERROR)
		found_tags.append(ALogger.TAG_LEVEL_CRITICAL)
	else:
		# Fallback if Logger can't be loaded
		var config = ConfigManager.get_instance()
		if config.get_show_editor_debug():
			print_rich("[color=#ea6962]WARNING: Could not load Logger class, using hardcoded level tags[/color]")
		found_tags.append("level:debug")
		found_tags.append("level:info")
		found_tags.append("level:warning")
		found_tags.append("level:error")
		found_tags.append("level:critical")

	# Extract all TAG_* constants from Logger class
	var logger_tags := extract_tag_constants_from_logger()
	found_tags.append_array(logger_tags)

	# Start scanning from the project root to find tag usage
	scan_directory("res://", found_tags, exclude_dirs)

	# Ensure unique tags
	found_tags = get_unique_tags(found_tags)

	# Return unique tags sorted alphabetically using TagManager
	return TagManager.sort_tags(found_tags)

## Extracts all TAG_* constants directly from the Logger class
static func extract_tag_constants_from_logger() -> Array[String]:
	var logger_tags: Array[String] = []
	var logger_path := "res://addons/advanced_logger/core/logger.gd"

	var file := FileAccess.open(logger_path, FileAccess.READ)
	if not file:
		push_warning("Failed to open Logger class: " + logger_path)
		return logger_tags

	var content := file.get_as_text()
	file.close()

	# Find TAG_* constants and their values using regex
	var regex := RegEx.new()
	regex.compile("const\\s+TAG_[A-Za-z0-9_]+\\s*:\\s*String\\s*=\\s*\"([^\"]+)\"")

	var matches := regex.search_all(content)
	for match_result in matches:
		if match_result.strings.size() >= 2:
			var tag := match_result.strings[1]
			if TagManager.is_valid_tag(tag):
				logger_tags.append(tag)

	return logger_tags

## Helper to ensure we have a unique tag list with filtered invalid tags
static func get_unique_tags(tags: Array[String]) -> Array[String]:
	# Filter out category names that might cause confusion
	var filtered_tags: Array[String] = []
	var category_names = ["available", "active", "ignored"]

	for tag in tags:
		# Skip category names
		if category_names.has(tag.to_lower()):
			var config = ConfigManager.get_instance()
			if config.get_show_editor_debug():
				print_rich("[color=#d8a657]WARNING: Skipping category name '%s' found during tag scanning[/color]" % tag)
			continue

		# Skip other potentially problematic tags
		if tag.length() < 3:  # Too short to be meaningful
			var config = ConfigManager.get_instance()
			if config.get_show_editor_debug():
				print_rich("[color=#d8a657]WARNING: Skipping too short tag '%s'[/color]" % tag)
			continue

		filtered_tags.append(tag)

	# Delegate to TagManager to ensure consistency
	return TagManager.merge_tags([filtered_tags])

## Recursively scans a directory for .gd files
##
## Parameters:
## - path: Directory path to scan
## - found_tags: Array to store found tags
## - exclude_dirs: Array of directory paths to exclude
static func scan_directory(path: String, found_tags: Array[String], exclude_dirs: Array[String] = []) -> void:
	# Skip this directory if it's in the exclude list
	for exclude in exclude_dirs:
		# Normalize the exclude path (remove trailing slash if present)
		var normalized_exclude = exclude
		if normalized_exclude.ends_with("/"):
			normalized_exclude = normalized_exclude.substr(0, normalized_exclude.length() - 1)

		# Check if the current path matches or is under the exclude path
		if path == normalized_exclude or path.begins_with(normalized_exclude + "/"):
			# Skip this directory
			return

	var dir := DirAccess.open(path)
	if not dir:
		push_warning("Failed to access directory: " + path)
		return

	# List all entries in the directory
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		var full_path := path.path_join(file_name)

		# Skip hidden files or directories
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		if dir.current_is_dir():
			# Recursively scan subdirectories (passing along excluded dirs)
			scan_directory(full_path, found_tags, exclude_dirs)
		elif file_name.ends_with(".gd"):
			# Process GDScript files
			scan_file_for_tags(full_path, found_tags)

		file_name = dir.get_next()

	dir.list_dir_end()

## Scans a GDScript file for Log calls and extracts tags
static func scan_file_for_tags(file_path: String, found_tags: Array[String]) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("Failed to open file: " + file_path)
		return

	# Read the file content
	var content := file.get_as_text()

	# Pattern 1: Look for direct string tags in Log method calls
	# Match different patterns of Log method calls:
	# 1. Log.method("message", {}, ["tag1", "tag2"])
	# 2. Log.method("message", tags = ["tag1", "tag2"])
	var regex := RegEx.new()
	regex.compile("Log\\.(debug|info|warning|error|critical)\\s*\\(.*?(?:\\{.*?\\}\\s*,\\s*)?\\[([^\\]]+)\\]|Log\\.(debug|info|warning|error|critical)\\s*\\(.*?tags\\s*=\\s*\\[([^\\]]+)\\]")

	var matches := regex.search_all(content)
	for match_result in matches:
		var tags_str := ""
		if match_result.strings.size() >= 3:
			# First pattern with positional args
			tags_str = match_result.strings[2]
		elif match_result.strings.size() >= 5:
			# Second pattern with named args
			tags_str = match_result.strings[4]

		if not tags_str.is_empty():
			extract_tags_from_string(tags_str, found_tags)

	# Pattern 2: Look for Log.TAG_* constant usage
	# This pattern identifies uses of the TAG constants
	var tag_const_regex := RegEx.new()
	tag_const_regex.compile("Log\\.TAG_[A-Za-z0-9_]+")

	# We don't need to add these to found_tags since we're already extracting
	# constants directly from Logger class, but we can log their usage
	var const_matches := tag_const_regex.search_all(content)
	if const_matches.size() > 0:
		var config = ConfigManager.get_instance()
		if config.get_show_editor_debug():
			print_rich("[color=#7daea3]Found %d TAG constant usages in %s[/color]" %
					[const_matches.size(), file_path.get_file()])

## Extracts tag strings from a matched tags array string
static func extract_tags_from_string(tags_str: String, found_tags: Array[String]) -> void:
	# Extract quoted strings using regex
	var tag_regex := RegEx.new()
	tag_regex.compile("\"([^\"]+)\"|'([^']+)'")

	var tag_matches := tag_regex.search_all(tags_str)
	for tag_match in tag_matches:
		# Get the tag value (either from double or single quotes)
		var tag := tag_match.strings[1] if tag_match.strings.size() > 1 and tag_match.strings[1] else tag_match.strings[2]

		# Validate the tag using TagManager and filter out reserved words
		if TagManager.is_valid_tag(tag) and not found_tags.has(tag):
			# Skip category names
			if tag.to_lower() == "active" or tag.to_lower() == "available" or tag.to_lower() == "ignored":
				var config = ConfigManager.get_instance()
				if config.get_show_editor_debug():
					print_rich("[color=#d8a657]WARNING: Skipping category name '%s' found in file[/color]" % tag)
				continue
			found_tags.append(tag)
