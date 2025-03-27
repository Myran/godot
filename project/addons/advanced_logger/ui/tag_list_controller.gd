@tool
class_name TagListController
extends RefCounted
## Controller for tag list UI operations
##
## Manages the interaction between tag lists in the UI and the underlying
## tag management system. Handles refreshing UI and responding to user actions.

# Preload required dependencies
const TagScanner = preload("res://addons/advanced_logger/utils/tag_scanner.gd")
const TagCategories = preload("res://addons/advanced_logger/utils/tag_categories.gd")

signal tag_moved(tag: String, from_category: int, to_category: int)
signal tag_selected(tag: String, category: int)
signal tag_activated(tag: String, category: int)

# For backwards compatibility with string-based code
const SOURCE_AVAILABLE: String = "available"
const SOURCE_ACTIVE: String = "active"
const SOURCE_IGNORED: String = "ignored"

# References to the UI components
var _available_tags_list: ItemList
var _active_tags_list: ItemList
var _ignored_tags_list: ItemList

# Tag data
var _available_tags: Array[String] = []
var _active_tags: Array[String] = []
var _ignored_tags: Array[String] = []

# Dependencies
var _config_manager

# Signal connection tracking
var _signals_connected: bool = false

# Initialize the controller with required dependencies
func _init(_tag_manager_class, config_manager) -> void:
	# TagManager is used statically
	_config_manager = config_manager

## Setup the UI components
func setup(available_list: ItemList, active_list: ItemList, ignored_list: ItemList) -> void:
	_available_tags_list = available_list
	_active_tags_list = active_list
	_ignored_tags_list = ignored_list
	
	# Only connect signals if this is the first time
	if not _signals_connected:
		_connect_signals()
		_signals_connected = true
	
	# Configure ItemList UI settings
	for list in [_available_tags_list, _active_tags_list, _ignored_tags_list]:
		if list:
			list.mouse_filter = Control.MOUSE_FILTER_PASS
			list.focus_mode = Control.FOCUS_ALL
			list.allow_rmb_select = true
			list.allow_reselect = true

## Connect UI signals - only called once
func _connect_signals() -> void:
	# Connect signals
	if _available_tags_list:
		_available_tags_list.item_selected.connect(_on_available_tag_selected)
		_available_tags_list.item_activated.connect(_on_available_tag_activated)
	
	if _active_tags_list:
		_active_tags_list.item_selected.connect(_on_active_tag_selected)
		_active_tags_list.item_activated.connect(_on_active_tag_activated)
	
	if _ignored_tags_list:
		_ignored_tags_list.item_selected.connect(_on_ignored_tag_selected)
		_ignored_tags_list.item_activated.connect(_on_ignored_tag_activated)

## Load tags from configuration
func load_tags_from_config() -> void:
	_available_tags = _config_manager.get_available_tags()
	_active_tags = _config_manager.get_active_tags()
	_ignored_tags = _config_manager.get_ignored_tags()
	
	# Clean up any tags with category names (likely from migration)
	var category_names = ["available", "active", "ignored"]
	for category in category_names:
		if _active_tags.has(category):
			_active_tags.erase(category)
			if OS.is_debug_build():
				print_rich("[color=#%s]WARNING: Removed category name '%s' from active tags[/color]" % 
					[LoggerColors.WARNING_HTML, category])
		
		if _ignored_tags.has(category):
			_ignored_tags.erase(category)
			if OS.is_debug_build():
				print_rich("[color=#%s]WARNING: Removed category name '%s' from ignored tags[/color]" % 
					[LoggerColors.WARNING_HTML, category])
	
	# Make sure active and ignored tags are in available tags
	for tag in _active_tags:
		if not _available_tags.has(tag):
			_available_tags.append(tag)
			
	for tag in _ignored_tags:
		if not _available_tags.has(tag):
			_available_tags.append(tag)
	
	# Save cleaned tags back to config
	_config_manager.set_active_tags(_active_tags)
	_config_manager.set_ignored_tags(_ignored_tags)
	_config_manager.set_available_tags(_available_tags)
	_config_manager.save()
	
	refresh_tag_lists()

## Refresh all tag lists UI from current data
func refresh_tag_lists() -> void:
	_populate_tag_list(_available_tags_list, _get_current_available_tags(), TagCategories.Category.AVAILABLE)
	_populate_tag_list(_active_tags_list, _active_tags, TagCategories.Category.ACTIVE)
	_populate_tag_list(_ignored_tags_list, _ignored_tags, TagCategories.Category.IGNORED)

## Gets tags that should be in the "Available" list
func _get_current_available_tags() -> Array[String]:
	var current_available: Array[String] = []
	for tag in _available_tags:
		if not _active_tags.has(tag) and not _ignored_tags.has(tag):
			current_available.append(tag)
	return current_available

## Helper function to populate a tag list
func _populate_tag_list(list_node: ItemList, tags: Array[String], category: int) -> void:
	if not list_node: return
	
	list_node.clear()
	for tag in tags:
		var display_text = _format_tag_for_display(tag)
		list_node.add_item(display_text)
		var index = list_node.item_count - 1
		list_node.set_item_metadata(index, tag)
		
		# Set custom color for level tags
		if _is_level_tag(tag):
			var color = LoggerColors.INFO_COLOR # Default for available
			match category:
				TagCategories.Category.ACTIVE: color = LoggerColors.SUCCESS_COLOR
				TagCategories.Category.IGNORED: color = LoggerColors.ERROR_COLOR
			list_node.set_item_custom_fg_color(index, color)

## Move a tag between categories
func move_tag(tag: String, from_category: Variant, to_category: Variant) -> void:
	# Convert string categories to enum if needed
	var from_cat := from_category
	var to_cat := to_category
	
	if from_cat is String:
		from_cat = TagCategories.from_string(from_cat)
	if to_cat is String:
		to_cat = TagCategories.from_string(to_cat)
	
	# Debug output
	if OS.is_debug_build():
		print_rich("[color=#%s]Moving tag: '%s' from %s to %s[/color]" % 
			[LoggerColors.INFO_HTML, tag, 
			TagCategories.category_to_string(from_cat) if from_cat is int else from_cat, 
			TagCategories.category_to_string(to_cat) if to_cat is int else to_cat])
	
	# Normalize the tag to ensure consistent case
	var normalized_tag = TagManager.normalize_tag(tag)
	if normalized_tag != tag:
		print_rich("[color=#%s]Normalized tag: %s -> %s[/color]" % 
			[LoggerColors.WARNING_HTML, tag, normalized_tag])
		tag = normalized_tag
	
	if not TagManager.is_valid_tag(tag):
		print_rich("[color=#%s]Tag is not valid: %s[/color]" % [LoggerColors.ERROR_HTML, tag])
		return
		
	if from_cat == to_cat:
		print_rich("[color=#%s]Source and target categories are the same[/color]" % [LoggerColors.WARNING_HTML])
		return
	
	# Debug the tag lists before moving
	if OS.is_debug_build():
		print_rich("[color=#%s]Before move - Active tags: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, _active_tags])
		print_rich("[color=#%s]Before move - Ignored tags: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, _ignored_tags])
	
	# Use TagManager to handle the move
	var result = TagManager.move_tag(
		tag,
		from_cat,
		to_cat,
		_available_tags,
		_active_tags,
		_ignored_tags
	)
	
	# Debug the tag lists after moving
	if OS.is_debug_build():
		print_rich("[color=#%s]After move - Active tags: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, _active_tags])
		print_rich("[color=#%s]After move - Ignored tags: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, _ignored_tags])
	
	# Save after every move to ensure persistence
	save_tags_to_config()
	
	# Update arrays with the result
	_available_tags = result.available_tags
	_active_tags = result.active_tags
	_ignored_tags = result.ignored_tags
	
	# Refresh the UI
	refresh_tag_lists()
	
	# Emit signal for external listeners
	tag_moved.emit(tag, from_category, to_category)

## Format a tag for display, with special handling for level tags
func _format_tag_for_display(tag: String) -> String:
	var formatted = TagManager.format_tag_for_display(tag)
	
	# Add special indicator based on tag type
	if _is_level_tag(tag):
		formatted = "⚙ " + formatted  # Use gear icon to indicate level tag
	else:
		formatted = "🏷 " + formatted  # Use tag icon for regular tags
	
	return formatted

## Check if a tag is a level tag
func _is_level_tag(tag: String) -> bool:
	return tag.begins_with("level:")

## Get current lists of tags
func get_tag_lists() -> Dictionary:
	return {
		"available_tags": _available_tags,
		"active_tags": _active_tags, 
		"ignored_tags": _ignored_tags
	}
	
## Set active tags (replaces existing active tags)
func set_active_tags(tags: Array) -> void:
	# Print what we received
	if OS.is_debug_build():
		print_rich("[color=#%s]DEBUG: Setting active tags: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, tags])
	
	# Reset the active tags
	_active_tags.clear()
	
	# Carefully convert and add each tag
	for tag in tags:
		if tag is String and TagManager.is_valid_tag(tag):
			# Make sure we don't have duplicates
			if not _active_tags.has(tag):
				_active_tags.append(tag)
				
			# Ensure tag is in available tags
			if not _available_tags.has(tag):
				_available_tags.append(tag)
	
	# Debug what we've set
	if OS.is_debug_build():
		print_rich("[color=#%s]DEBUG: New active tags: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, _active_tags])
	
	# Refresh the UI
	refresh_tag_lists()
	
## Set ignored tags (replaces existing ignored tags)
func set_ignored_tags(tags: Array) -> void:
	# Print what we received
	if OS.is_debug_build():
		print_rich("[color=#%s]DEBUG: Setting ignored tags: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, tags])
	
	# Reset the ignored tags
	_ignored_tags.clear()
	
	# Carefully convert and add each tag
	for tag in tags:
		if tag is String and TagManager.is_valid_tag(tag):
			# Make sure we don't have duplicates
			if not _ignored_tags.has(tag):
				_ignored_tags.append(tag)
				
			# Ensure tag is in available tags
			if not _available_tags.has(tag):
				_available_tags.append(tag)
	
	# Debug what we've set
	if OS.is_debug_build():
		print_rich("[color=#%s]DEBUG: New ignored tags: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, _ignored_tags])
	
	# Refresh the UI
	refresh_tag_lists()

## Update tags in configuration
func save_tags_to_config() -> void:
	# Debug what we're saving to config
	if OS.is_debug_build():
		print_rich("[color=#%s]DEBUG: Saving to config - Active tags: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, _active_tags])
		print_rich("[color=#%s]DEBUG: Saving to config - Ignored tags: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, _ignored_tags])
		
	# Save to config
	_config_manager.set_active_tags(_active_tags)
	_config_manager.set_ignored_tags(_ignored_tags)
	_config_manager.set_available_tags(_available_tags)
	
	# Force save
	var result = _config_manager.save()
	if OS.is_debug_build():
		print_rich("[color=#%s]DEBUG: Config save result: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, "OK" if result == OK else error_string(result)])
	
	# Verify what was actually saved
	var saved_active = _config_manager.get_active_tags()
	var saved_ignored = _config_manager.get_ignored_tags()
	
	if OS.is_debug_build():
		print_rich("[color=#%s]DEBUG: Verified in config - Active tags: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, saved_active])
		print_rich("[color=#%s]DEBUG: Verified in config - Ignored tags: %s[/color]" % 
			[LoggerColors.DEBUG_HTML, saved_ignored])

## Signal handlers
func _on_available_tag_selected(index: int) -> void:
	var tag = _available_tags_list.get_item_metadata(index)
	tag = TagManager.normalize_tag(tag)
	tag_selected.emit(tag, TagCategories.Category.AVAILABLE)

func _on_available_tag_activated(index: int) -> void:
	var tag = _available_tags_list.get_item_metadata(index)
	tag = TagManager.normalize_tag(tag)
	tag_activated.emit(tag, TagCategories.Category.AVAILABLE)
	# Default behavior: Move to active list
	move_tag(tag, TagCategories.Category.AVAILABLE, TagCategories.Category.ACTIVE)

func _on_active_tag_selected(index: int) -> void:
	var tag = _active_tags_list.get_item_metadata(index)
	tag = TagManager.normalize_tag(tag)
	tag_selected.emit(tag, TagCategories.Category.ACTIVE)

func _on_active_tag_activated(index: int) -> void:
	var tag = _active_tags_list.get_item_metadata(index)
	tag = TagManager.normalize_tag(tag)
	tag_activated.emit(tag, TagCategories.Category.ACTIVE)
	# Default behavior: Move to ignored list
	move_tag(tag, TagCategories.Category.ACTIVE, TagCategories.Category.IGNORED)

func _on_ignored_tag_selected(index: int) -> void:
	var tag = _ignored_tags_list.get_item_metadata(index)
	tag = TagManager.normalize_tag(tag)
	tag_selected.emit(tag, TagCategories.Category.IGNORED)

func _on_ignored_tag_activated(index: int) -> void:
	var tag = _ignored_tags_list.get_item_metadata(index)
	tag = TagManager.normalize_tag(tag)
	tag_activated.emit(tag, TagCategories.Category.IGNORED)
	# Default behavior: Move to active list
	move_tag(tag, TagCategories.Category.IGNORED, TagCategories.Category.ACTIVE)

## Scan the project for tags
func scan_tags(exclude_dirs: Array[String] = []) -> int:
	var scanner_tags = TagScanner.scan_project_for_tags(exclude_dirs)
	
	# Add each tag to available tags if not already present
	var added_count := 0
	for tag in scanner_tags:
		if not _available_tags.has(tag):
			_available_tags.append(tag)
			added_count += 1
	
	# Sort tags alphabetically
	_available_tags.sort()
	
	# Refresh UI
	refresh_tag_lists()
	
	# Save changes to config
	save_tags_to_config()
	
	return added_count
