@tool
class_name TagListController
extends RefCounted

signal tag_moved(tag: String, from_category: int, to_category: int)
signal tag_selected(tag: String, category: int)
signal tag_activated(tag: String, category: int)

const TagScanner = preload("res://addons/advanced_logger/utils/tag_scanner.gd")
const TagCategories = preload("res://addons/advanced_logger/utils/tag_categories.gd")



const SOURCE_AVAILABLE: String = "available"
const SOURCE_ACTIVE: String = "active"
const SOURCE_IGNORED: String = "ignored"

var _available_tags_list: ItemList
var _active_tags_list: ItemList
var _ignored_tags_list: ItemList

var _available_tags: Array[String] = []
var _active_tags: Array[String] = []
var _ignored_tags: Array[String] = []

var _config_manager

var _signals_connected: bool = false


func _init(_tag_manager_class, config_manager) -> void:
	_config_manager = config_manager


func setup(available_list: ItemList, active_list: ItemList, ignored_list: ItemList) -> void:
	_available_tags_list = available_list
	_active_tags_list = active_list
	_ignored_tags_list = ignored_list

	if not _signals_connected:
		_connect_signals()
		_signals_connected = true

	for list in [_available_tags_list, _active_tags_list, _ignored_tags_list]:
		if list:
			list.mouse_filter = Control.MOUSE_FILTER_PASS
			list.focus_mode = Control.FOCUS_ALL
			list.allow_rmb_select = true
			list.allow_reselect = true


func _connect_signals() -> void:
	if _available_tags_list:
		_available_tags_list.item_selected.connect(_on_available_tag_selected)
		_available_tags_list.item_activated.connect(_on_available_tag_activated)

	if _active_tags_list:
		_active_tags_list.item_selected.connect(_on_active_tag_selected)
		_active_tags_list.item_activated.connect(_on_active_tag_activated)

	if _ignored_tags_list:
		_ignored_tags_list.item_selected.connect(_on_ignored_tag_selected)
		_ignored_tags_list.item_activated.connect(_on_ignored_tag_activated)


func load_tags_from_config() -> void:
	_available_tags = _config_manager.get_available_tags()
	_active_tags = _config_manager.get_active_tags()
	_ignored_tags = _config_manager.get_ignored_tags()

	var category_names = ["available", "active", "ignored"]
	for category in category_names:
		if _active_tags.has(category):
			_active_tags.erase(category)
			if OS.is_debug_build() and _config_manager.get_show_editor_debug():
				print_rich(
					(
						"[color=#%s]WARNING: Removed category name '%s' from active tags[/color]"
						% [LoggerColors.WARNING_HTML, category]
					)
				)

		if _ignored_tags.has(category):
			_ignored_tags.erase(category)
			if OS.is_debug_build() and _config_manager.get_show_editor_debug():
				print_rich(
					(
						"[color=#%s]WARNING: Removed category name '%s' from ignored tags[/color]"
						% [LoggerColors.WARNING_HTML, category]
					)
				)

	for tag in _active_tags:
		if not _available_tags.has(tag):
			_available_tags.append(tag)

	for tag in _ignored_tags:
		if not _available_tags.has(tag):
			_available_tags.append(tag)

	_config_manager.set_active_tags(_active_tags)
	_config_manager.set_ignored_tags(_ignored_tags)
	_config_manager.set_available_tags(_available_tags)
	_config_manager.save()

	refresh_tag_lists()


func refresh_tag_lists() -> void:
	_populate_tag_list(
		_available_tags_list, _get_current_available_tags(), TagCategories.Category.AVAILABLE
	)
	_populate_tag_list(_active_tags_list, _active_tags, TagCategories.Category.ACTIVE)
	_populate_tag_list(_ignored_tags_list, _ignored_tags, TagCategories.Category.IGNORED)


func _get_current_available_tags() -> Array[String]:
	var current_available: Array[String] = []
	for tag in _available_tags:
		if not _active_tags.has(tag) and not _ignored_tags.has(tag):
			current_available.append(tag)
	return current_available


func _populate_tag_list(list_node: ItemList, tags: Array[String], category: int) -> void:
	if not list_node:
		return

	list_node.clear()
	for tag in tags:
		var display_text = _format_tag_for_display(tag)
		list_node.add_item(display_text)
		var index = list_node.item_count - 1
		list_node.set_item_metadata(index, tag)

		if _is_level_tag(tag):
			var color = LoggerColors.INFO_COLOR  # Default for available
			match category:
				TagCategories.Category.ACTIVE:
					color = LoggerColors.SUCCESS_COLOR
				TagCategories.Category.IGNORED:
					color = LoggerColors.ERROR_COLOR
			list_node.set_item_custom_fg_color(index, color)


func move_tag(tag: String, from_category: Variant, to_category: Variant) -> void:
	var from_cat := from_category
	var to_cat := to_category

	if from_cat is String:
		from_cat = TagCategories.from_string(from_cat)
	if to_cat is String:
		to_cat = TagCategories.from_string(to_cat)

	if OS.is_debug_build() and _config_manager.get_show_editor_debug():
		print_rich(
			(
				"[color=#%s]Moving tag: '%s' from %s to %s[/color]"
				% [
					LoggerColors.INFO_HTML,
					tag,
					TagCategories.category_to_string(from_cat) if from_cat is int else from_cat,
					TagCategories.category_to_string(to_cat) if to_cat is int else to_cat
				]
			)
		)

	var normalized_tag = TagManager.normalize_tag(tag)
	if normalized_tag != tag:
		if _config_manager.get_show_editor_debug():
			print_rich(
				(
					"[color=#%s]Normalized tag: %s -> %s[/color]"
					% [LoggerColors.WARNING_HTML, tag, normalized_tag]
				)
			)
		tag = normalized_tag

	if not TagManager.is_valid_tag(tag):
		if _config_manager.get_show_editor_debug():
			print_rich("[color=#%s]Tag is not valid: %s[/color]" % [LoggerColors.ERROR_HTML, tag])
		return

	if from_cat == to_cat:
		if _config_manager.get_show_editor_debug():
			print_rich(
				(
					"[color=#%s]Source and target categories are the same[/color]"
					% [LoggerColors.WARNING_HTML]
				)
			)
		return

	if OS.is_debug_build() and _config_manager.get_show_editor_debug():
		print_rich(
			(
				"[color=#%s]Before move - Active tags: %s[/color]"
				% [LoggerColors.DEBUG_HTML, _active_tags]
			)
		)
		print_rich(
			(
				"[color=#%s]Before move - Ignored tags: %s[/color]"
				% [LoggerColors.DEBUG_HTML, _ignored_tags]
			)
		)

	var result: Dictionary = TagManager.move_tag(
		tag, from_cat, to_cat, _available_tags, _active_tags, _ignored_tags
	)

	if OS.is_debug_build() and _config_manager.get_show_editor_debug():
		print_rich(
			(
				"[color=#%s]After move - Active tags: %s[/color]"
				% [LoggerColors.DEBUG_HTML, _active_tags]
			)
		)
		print_rich(
			(
				"[color=#%s]After move - Ignored tags: %s[/color]"
				% [LoggerColors.DEBUG_HTML, _ignored_tags]
			)
		)

	save_tags_to_config()

	_available_tags = result.available_tags
	_active_tags = result.active_tags
	_ignored_tags = result.ignored_tags

	refresh_tag_lists()

	tag_moved.emit(tag, from_category, to_category)


func _format_tag_for_display(tag: String) -> String:
	var formatted = TagManager.format_tag_for_display(tag)

	if _is_level_tag(tag):
		formatted = "⚙ " + formatted  # Use gear icon to indicate level tag
	else:
		formatted = "🏷 " + formatted  # Use tag icon for regular tags

	return formatted


func _is_level_tag(tag: String) -> bool:
	return tag.begins_with("level:")


func get_tag_lists() -> Dictionary:
	return {
		"available_tags": _available_tags,
		"active_tags": _active_tags,
		"ignored_tags": _ignored_tags
	}


func set_active_tags(tags: Array) -> void:
	if OS.is_debug_build() and _config_manager.get_show_editor_debug():
		print_rich(
			"[color=#%s]DEBUG: Setting active tags: %s[/color]" % [LoggerColors.DEBUG_HTML, tags]
		)

	_active_tags.clear()

	for tag in tags:
		if tag is String and TagManager.is_valid_tag(tag):
			if not _active_tags.has(tag):
				_active_tags.append(tag)

			if not _available_tags.has(tag):
				_available_tags.append(tag)

	if OS.is_debug_build() and _config_manager.get_show_editor_debug():
		print_rich(
			(
				"[color=#%s]DEBUG: New active tags: %s[/color]"
				% [LoggerColors.DEBUG_HTML, _active_tags]
			)
		)

	refresh_tag_lists()


func set_ignored_tags(tags: Array) -> void:
	if OS.is_debug_build() and _config_manager.get_show_editor_debug():
		print_rich(
			"[color=#%s]DEBUG: Setting ignored tags: %s[/color]" % [LoggerColors.DEBUG_HTML, tags]
		)

	_ignored_tags.clear()

	for tag in tags:
		if tag is String and TagManager.is_valid_tag(tag):
			if not _ignored_tags.has(tag):
				_ignored_tags.append(tag)

			if not _available_tags.has(tag):
				_available_tags.append(tag)

	if OS.is_debug_build() and _config_manager.get_show_editor_debug():
		print_rich(
			(
				"[color=#%s]DEBUG: New ignored tags: %s[/color]"
				% [LoggerColors.DEBUG_HTML, _ignored_tags]
			)
		)

	refresh_tag_lists()


func save_tags_to_config() -> void:
	if OS.is_debug_build() and _config_manager.get_show_editor_debug():
		print_rich(
			(
				"[color=#%s]DEBUG: Saving to config - Active tags: %s[/color]"
				% [LoggerColors.DEBUG_HTML, _active_tags]
			)
		)
		print_rich(
			(
				"[color=#%s]DEBUG: Saving to config - Ignored tags: %s[/color]"
				% [LoggerColors.DEBUG_HTML, _ignored_tags]
			)
		)

	_config_manager.set_active_tags(_active_tags)
	_config_manager.set_ignored_tags(_ignored_tags)
	_config_manager.set_available_tags(_available_tags)

	var result: int = _config_manager.save()
	if OS.is_debug_build() and _config_manager.get_show_editor_debug():
		print_rich(
			(
				"[color=#%s]DEBUG: Config save result: %s[/color]"
				% [LoggerColors.DEBUG_HTML, "OK" if result == OK else error_string(result)]
			)
		)

	var saved_active = _config_manager.get_active_tags()
	var saved_ignored = _config_manager.get_ignored_tags()

	if OS.is_debug_build() and _config_manager.get_show_editor_debug():
		print_rich(
			(
				"[color=#%s]DEBUG: Verified in config - Active tags: %s[/color]"
				% [LoggerColors.DEBUG_HTML, saved_active]
			)
		)
		print_rich(
			(
				"[color=#%s]DEBUG: Verified in config - Ignored tags: %s[/color]"
				% [LoggerColors.DEBUG_HTML, saved_ignored]
			)
		)


func _on_available_tag_selected(index: int) -> void:
	var tag = _available_tags_list.get_item_metadata(index)
	tag = TagManager.normalize_tag(tag)
	tag_selected.emit(tag, TagCategories.Category.AVAILABLE)


func _on_available_tag_activated(index: int) -> void:
	var tag = _available_tags_list.get_item_metadata(index)
	tag = TagManager.normalize_tag(tag)
	tag_activated.emit(tag, TagCategories.Category.AVAILABLE)
	move_tag(tag, TagCategories.Category.AVAILABLE, TagCategories.Category.ACTIVE)


func _on_active_tag_selected(index: int) -> void:
	var tag = _active_tags_list.get_item_metadata(index)
	tag = TagManager.normalize_tag(tag)
	tag_selected.emit(tag, TagCategories.Category.ACTIVE)


func _on_active_tag_activated(index: int) -> void:
	var tag = _active_tags_list.get_item_metadata(index)
	tag = TagManager.normalize_tag(tag)
	tag_activated.emit(tag, TagCategories.Category.ACTIVE)
	move_tag(tag, TagCategories.Category.ACTIVE, TagCategories.Category.IGNORED)


func _on_ignored_tag_selected(index: int) -> void:
	var tag = _ignored_tags_list.get_item_metadata(index)
	tag = TagManager.normalize_tag(tag)
	tag_selected.emit(tag, TagCategories.Category.IGNORED)


func _on_ignored_tag_activated(index: int) -> void:
	var tag = _ignored_tags_list.get_item_metadata(index)
	tag = TagManager.normalize_tag(tag)
	tag_activated.emit(tag, TagCategories.Category.IGNORED)
	move_tag(tag, TagCategories.Category.IGNORED, TagCategories.Category.ACTIVE)


func scan_tags(exclude_dirs: Array[String] = []) -> int:
	var scanner_tags = TagScanner.scan_project_for_tags(exclude_dirs)

	var added_count := 0
	for tag in scanner_tags:
		if not _available_tags.has(tag):
			_available_tags.append(tag)
			added_count += 1

	_available_tags.sort()

	refresh_tag_lists()

	save_tags_to_config()

	return added_count
