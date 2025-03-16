@tool
class_name TagListController
extends RefCounted
## Controller for tag list UI operations
##
## Manages the interaction between tag lists in the UI and the underlying
## tag management system. Handles refreshing UI and responding to user actions.

# Preload required dependencies
const TagScanner = preload("res://addons/advanced_logger/utils/tag_scanner.gd")

signal tag_moved(tag: String, from_category: String, to_category: String)
signal tag_selected(tag: String, category: String)
signal tag_activated(tag: String, category: String)

# Tag source constants
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

# Initialize the controller with required dependencies
func _init(_tag_manager_class, config_manager) -> void:
	# TagManager is used statically
	_config_manager = config_manager

## Setup the UI components
func setup(available_list: ItemList, active_list: ItemList, ignored_list: ItemList) -> void:
	_available_tags_list = available_list
	_active_tags_list = active_list
	_ignored_tags_list = ignored_list
	
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
	
	# Configure ItemList UI settings
	for list in [_available_tags_list, _active_tags_list, _ignored_tags_list]:
		if list:
			list.mouse_filter = Control.MOUSE_FILTER_PASS
			list.focus_mode = Control.FOCUS_ALL
			list.allow_rmb_select = true
			list.allow_reselect = true

## Load tags from configuration
func load_tags_from_config() -> void:
	_available_tags = _config_manager.get_available_tags()
	_active_tags = _config_manager.get_active_tags()
	_ignored_tags = _config_manager.get_ignored_tags()
	
	# Make sure active and ignored tags are in available tags
	for tag in _active_tags:
		if not _available_tags.has(tag):
			_available_tags.append(tag)
			
	for tag in _ignored_tags:
		if not _available_tags.has(tag):
			_available_tags.append(tag)
	
	refresh_tag_lists()

## Refresh all tag lists UI from current data
func refresh_tag_lists() -> void:
	# Clear and populate available tags list
	if _available_tags_list:
		_available_tags_list.clear()
		for tag in _available_tags:
			if not _active_tags.has(tag) and not _ignored_tags.has(tag):
				_available_tags_list.add_item(_format_tag_for_display(tag))
				_available_tags_list.set_item_metadata(_available_tags_list.item_count - 1, tag)

	# Clear and populate active tags list
	if _active_tags_list:
		_active_tags_list.clear()
		for tag in _active_tags:
			_active_tags_list.add_item(_format_tag_for_display(tag))
			_active_tags_list.set_item_metadata(_active_tags_list.item_count - 1, tag)

	# Clear and populate ignored tags list
	if _ignored_tags_list:
		_ignored_tags_list.clear()
		for tag in _ignored_tags:
			_ignored_tags_list.add_item(_format_tag_for_display(tag))
			_ignored_tags_list.set_item_metadata(_ignored_tags_list.item_count - 1, tag)

## Move a tag between categories
func move_tag(tag: String, from_category: String, to_category: String) -> void:
	if not TagManager.is_valid_tag(tag) or from_category == to_category:
		return
		
	# Use TagManager to handle the move
	var result = TagManager.move_tag(
		tag,
		from_category,
		to_category,
		_available_tags,
		_active_tags,
		_ignored_tags
	)
	
	# Update arrays with the result
	_available_tags = result.available_tags
	_active_tags = result.active_tags
	_ignored_tags = result.ignored_tags
	
	# Refresh the UI
	refresh_tag_lists()
	
	# Emit signal for external listeners
	tag_moved.emit(tag, from_category, to_category)

## Format a tag for display
func _format_tag_for_display(tag: String) -> String:
	return TagManager.format_tag_for_display(tag)

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
	print_rich("[color=#%s]DEBUG: New active tags: %s[/color]" % 
		[LoggerColors.DEBUG_HTML, _active_tags])
	
	# Refresh the UI
	refresh_tag_lists()
	
## Set ignored tags (replaces existing ignored tags)
func set_ignored_tags(tags: Array) -> void:
	# Print what we received
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
	print_rich("[color=#%s]DEBUG: New ignored tags: %s[/color]" % 
		[LoggerColors.DEBUG_HTML, _ignored_tags])
	
	# Refresh the UI
	refresh_tag_lists()

## Update tags in configuration
func save_tags_to_config() -> void:
	# Debug what we're saving to config
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
	print_rich("[color=#%s]DEBUG: Config save result: %s[/color]" % 
		[LoggerColors.DEBUG_HTML, "OK" if result == OK else error_string(result)])
	
	# Verify what was actually saved
	var saved_active = _config_manager.get_active_tags()
	var saved_ignored = _config_manager.get_ignored_tags()
	
	print_rich("[color=#%s]DEBUG: Verified in config - Active tags: %s[/color]" % 
		[LoggerColors.DEBUG_HTML, saved_active])
	print_rich("[color=#%s]DEBUG: Verified in config - Ignored tags: %s[/color]" % 
		[LoggerColors.DEBUG_HTML, saved_ignored])

## Signal handlers
func _on_available_tag_selected(index: int) -> void:
	var tag = _available_tags_list.get_item_metadata(index)
	tag_selected.emit(tag, SOURCE_AVAILABLE)

func _on_available_tag_activated(index: int) -> void:
	var tag = _available_tags_list.get_item_metadata(index)
	tag_activated.emit(tag, SOURCE_AVAILABLE)
	# Default behavior: Move to active list
	move_tag(tag, SOURCE_AVAILABLE, SOURCE_ACTIVE)

func _on_active_tag_selected(index: int) -> void:
	var tag = _active_tags_list.get_item_metadata(index)
	tag_selected.emit(tag, SOURCE_ACTIVE)

func _on_active_tag_activated(index: int) -> void:
	var tag = _active_tags_list.get_item_metadata(index)
	tag_activated.emit(tag, SOURCE_ACTIVE)
	# Default behavior: Move to ignored list
	move_tag(tag, SOURCE_ACTIVE, SOURCE_IGNORED)

func _on_ignored_tag_selected(index: int) -> void:
	var tag = _ignored_tags_list.get_item_metadata(index)
	tag_selected.emit(tag, SOURCE_IGNORED)

func _on_ignored_tag_activated(index: int) -> void:
	var tag = _ignored_tags_list.get_item_metadata(index)
	tag_activated.emit(tag, SOURCE_IGNORED)
	# Default behavior: Move to active list
	move_tag(tag, SOURCE_IGNORED, SOURCE_ACTIVE)

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
