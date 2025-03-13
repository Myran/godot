@tool
class_name LogTagScanner
extends RefCounted
## Utility for scanning project files to find Log tags

## Scans the project for Log method calls and extracts tags
## 
## Parameters:
## - exclude_dirs: Array of directory paths to exclude from scanning (e.g. ["res://tests/"])
##
## Returns an array of unique tags found
static func scan_project_for_tags(exclude_dirs: Array[String] = []) -> Array[String]:
	var found_tags: Array[String] = []
	
	# Start scanning from the project root
	scan_directory("res://", found_tags, exclude_dirs)
	
	# Return unique tags sorted alphabetically
	found_tags.sort()
	return found_tags

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
	
	# Look for Log method calls with tags
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

## Extracts tag strings from a matched tags array string
static func extract_tags_from_string(tags_str: String, found_tags: Array[String]) -> void:
	# Extract quoted strings using regex
	var tag_regex := RegEx.new()
	tag_regex.compile("\"([^\"]+)\"|'([^']+)'")
	
	var tag_matches := tag_regex.search_all(tags_str)
	for tag_match in tag_matches:
		# Get the tag value (either from double or single quotes)
		var tag := tag_match.strings[1] if tag_match.strings.size() > 1 and tag_match.strings[1] else tag_match.strings[2]
		
		# Validate the tag using the existing validation method
		if LoggerSettings._is_valid_tag(tag) and not found_tags.has(tag):
			found_tags.append(tag)
