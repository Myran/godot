@tool
class_name TagManager
extends RefCounted

const TagCategories = preload("res://addons/advanced_logger/utils/tag_categories.gd")

static func is_valid_tag(tag) -> bool:
	if not (tag is String):
		return false

	if tag.is_empty():
		return false

	if tag.begins_with("level:") or tag.begins_with("Level:"):
		var parts = tag.split(":")
		if parts.size() != 2 or parts[1].is_empty():
			return false

		var regex = RegEx.new()
		regex.compile("^[a-zA-Z0-9_-]+$")
		return regex.search(parts[1]) != null

	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_-]+$")
	return regex.search(tag) != null

static func validate_tags(tags: Array) -> Array[String]:
	var validated_tags: Array[String] = []
	for tag in tags:
		if is_valid_tag(tag):
			validated_tags.append(tag)
	return validated_tags

static func should_show_tags(tags: Array, active_tags: Array[String], ignored_tags: Array[String]) -> bool:
	for tag in tags:
		if tag is String and ignored_tags.has(tag):
			return false

	if active_tags.is_empty():
		return true

	var has_only_level_tags = true
	var level_tags_count = 0

	for tag in active_tags:
		if tag is String and is_level_tag(tag):
			level_tags_count += 1
		else:
			has_only_level_tags = false
			break

	if has_only_level_tags and level_tags_count > 0:
		return true

	if not has_only_level_tags and tags.is_empty():
		return false

	for tag in tags:
		if tag is String and active_tags.has(tag):
			return true

	return false

static func move_tag(
	tag: String,
	from_category: Variant,
	to_category: Variant,
	available_tags: Array[String],
	active_tags: Array[String],
	ignored_tags: Array[String]
) -> Dictionary:
	var from_cat := from_category
	var to_cat := to_category

	if from_cat is String:
		from_cat = TagCategories.from_string(from_cat)
	if to_cat is String:
		to_cat = TagCategories.from_string(to_cat)

	if not is_valid_tag(tag) or from_cat == to_cat:
		return {
			"available_tags": available_tags,
			"active_tags": active_tags,
			"ignored_tags": ignored_tags
		}

	if not available_tags.has(tag):
		available_tags.append(tag)

	match from_cat:
		TagCategories.Category.ACTIVE:
			if active_tags.has(tag):
				active_tags.erase(tag)
		TagCategories.Category.IGNORED:
			if ignored_tags.has(tag):
				ignored_tags.erase(tag)

	match to_cat:
		TagCategories.Category.AVAILABLE:
			active_tags.erase(tag)
			ignored_tags.erase(tag)
		TagCategories.Category.ACTIVE:
			ignored_tags.erase(tag)
			if not active_tags.has(tag):
				active_tags.append(tag)
		TagCategories.Category.IGNORED:
			active_tags.erase(tag)
			if not ignored_tags.has(tag):
				ignored_tags.append(tag)

	return {
		"available_tags": available_tags,
		"active_tags": active_tags,
		"ignored_tags": ignored_tags
	}

static func format_tag_for_display(tag: String) -> String:
	if tag.is_empty():
		return tag

	tag = normalize_tag(tag)

	if is_level_tag(tag):
		var parts = tag.split(":")
		if parts.size() == 2:
			return parts[0].capitalize() + ":" + parts[1]

	return tag.substr(0, 1).capitalize() + tag.substr(1)

static func filter_tags(all_tags: Array[String], active_tags: Array[String], ignored_tags: Array[String]) -> Array[String]:
	var filtered_tags: Array[String] = []

	for tag in all_tags:
		if ignored_tags.has(tag):
			continue

		if not active_tags.is_empty():
			if active_tags.has(tag):
				filtered_tags.append(tag)
		else:
			filtered_tags.append(tag)

	return filtered_tags

static func merge_tags(tag_arrays: Array) -> Array[String]:
	var merged_tags: Array[String] = []

	for tag_array in tag_arrays:
		for tag in tag_array:
			if tag is String and is_valid_tag(tag) and not merged_tags.has(tag):
				merged_tags.append(tag)

	return merged_tags

static func is_level_tag(tag: String) -> bool:
	return tag is String and (tag.begins_with("level:") or tag.begins_with("Level:"))

static func normalize_tag(tag: String) -> String:
	if not tag is String:
		return tag

	if tag.to_lower().begins_with("level:"):
		var parts = tag.split(":")
		if parts.size() == 2:
			return "level:" + parts[1].to_lower()

	return tag

static func sort_tags(tags: Array[String]) -> Array[String]:
	var level_tags: Array[String] = []
	var regular_tags: Array[String] = []

	for tag in tags:
		if is_level_tag(tag):
			level_tags.append(tag)
		else:
			regular_tags.append(tag)

	level_tags.sort()
	regular_tags.sort()

	var sorted_tags: Array[String] = []
	sorted_tags.append_array(level_tags)
	sorted_tags.append_array(regular_tags)

	return sorted_tags
