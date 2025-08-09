@tool
class_name LogTagScanner
extends RefCounted

const TagManager = preload("res://addons/advanced_logger/utils/tag_manager.gd")
const ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")

static func scan_project_for_tags(exclude_dirs: Array[String] = []) -> Array[String]:
	var found_tags: Array[String] = []

	var Logger = load("res://addons/advanced_logger/core/logger.gd")

	if ALogger:
		found_tags.append(ALogger.TAG_LEVEL_DEBUG)
		found_tags.append(ALogger.TAG_LEVEL_INFO)
		found_tags.append(ALogger.TAG_LEVEL_WARNING)
		found_tags.append(ALogger.TAG_LEVEL_ERROR)
		found_tags.append(ALogger.TAG_LEVEL_CRITICAL)
	else:
		var config = ConfigManager.get_instance()
		if config.get_show_editor_debug():
			print_rich("[color=#ea6962]WARNING: Could not load Logger class, using hardcoded level tags[/color]")
		found_tags.append("level:debug")
		found_tags.append("level:info")
		found_tags.append("level:warning")
		found_tags.append("level:error")
		found_tags.append("level:critical")

	var logger_tags := extract_tag_constants_from_logger()
	found_tags.append_array(logger_tags)

	scan_directory("res://", found_tags, exclude_dirs)

	found_tags = get_unique_tags(found_tags)

	return TagManager.sort_tags(found_tags)

static func extract_tag_constants_from_logger() -> Array[String]:
	var logger_tags: Array[String] = []
	var logger_path := "res://addons/advanced_logger/core/logger.gd"

	var file := FileAccess.open(logger_path, FileAccess.READ)
	if not file:
		push_warning("Failed to open Logger class: " + logger_path)
		return logger_tags

	var content := file.get_as_text()
	file.close()

	var regex := RegEx.new()
	regex.compile("const\\s+TAG_[A-Za-z0-9_]+\\s*:\\s*String\\s*=\\s*\"([^\"]+)\"")

	var matches := regex.search_all(content)
	for match_result in matches:
		if match_result.strings.size() >= 2:
			var tag := match_result.strings[1]
			if TagManager.is_valid_tag(tag):
				logger_tags.append(tag)

	return logger_tags

static func get_unique_tags(tags: Array[String]) -> Array[String]:
	var filtered_tags: Array[String] = []
	var category_names = ["available", "active", "ignored"]

	for tag in tags:
		if category_names.has(tag.to_lower()):
			var config = ConfigManager.get_instance()
			if config.get_show_editor_debug():
				print_rich("[color=#d8a657]WARNING: Skipping category name '%s' found during tag scanning[/color]" % tag)
			continue

		if tag.length() < 3:  # Too short to be meaningful
			var config = ConfigManager.get_instance()
			if config.get_show_editor_debug():
				print_rich("[color=#d8a657]WARNING: Skipping too short tag '%s'[/color]" % tag)
			continue

		filtered_tags.append(tag)

	return TagManager.merge_tags([filtered_tags])

static func scan_directory(path: String, found_tags: Array[String], exclude_dirs: Array[String] = []) -> void:
	for exclude in exclude_dirs:
		var normalized_exclude = exclude
		if normalized_exclude.ends_with("/"):
			normalized_exclude = normalized_exclude.substr(0, normalized_exclude.length() - 1)

		if path == normalized_exclude or path.begins_with(normalized_exclude + "/"):
			return

	var dir := DirAccess.open(path)
	if not dir:
		push_warning("Failed to access directory: " + path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		var full_path := path.path_join(file_name)

		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		if dir.current_is_dir():
			scan_directory(full_path, found_tags, exclude_dirs)
		elif file_name.ends_with(".gd"):
			scan_file_for_tags(full_path, found_tags)

		file_name = dir.get_next()

	dir.list_dir_end()

static func scan_file_for_tags(file_path: String, found_tags: Array[String]) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("Failed to open file: " + file_path)
		return

	var content := file.get_as_text()

	var regex := RegEx.new()
	regex.compile("Log\\.(debug|info|warning|error|critical)\\s*\\(.*?(?:\\{.*?\\}\\s*,\\s*)?\\[([^\\]]+)\\]|Log\\.(debug|info|warning|error|critical)\\s*\\(.*?tags\\s*=\\s*\\[([^\\]]+)\\]")

	var matches := regex.search_all(content)
	for match_result in matches:
		var tags_str := ""
		if match_result.strings.size() >= 3:
			tags_str = match_result.strings[2]
		elif match_result.strings.size() >= 5:
			tags_str = match_result.strings[4]

		if not tags_str.is_empty():
			extract_tags_from_string(tags_str, found_tags)

	var tag_const_regex := RegEx.new()
	tag_const_regex.compile("Log\\.TAG_[A-Za-z0-9_]+")

	var const_matches := tag_const_regex.search_all(content)
	if const_matches.size() > 0:
		var config = ConfigManager.get_instance()
		if config.get_show_editor_debug():
			print_rich("[color=#7daea3]Found %d TAG constant usages in %s[/color]" %
					[const_matches.size(), file_path.get_file()])

static func extract_tags_from_string(tags_str: String, found_tags: Array[String]) -> void:
	var tag_regex := RegEx.new()
	tag_regex.compile("\"([^\"]+)\"|'([^']+)'")

	var tag_matches := tag_regex.search_all(tags_str)
	for tag_match in tag_matches:
		var tag := tag_match.strings[1] if tag_match.strings.size() > 1 and tag_match.strings[1] else tag_match.strings[2]

		if TagManager.is_valid_tag(tag) and not found_tags.has(tag):
			if tag.to_lower() == "active" or tag.to_lower() == "available" or tag.to_lower() == "ignored":
				var config = ConfigManager.get_instance()
				if config.get_show_editor_debug():
					print_rich("[color=#d8a657]WARNING: Skipping category name '%s' found in file[/color]" % tag)
				continue
			found_tags.append(tag)
