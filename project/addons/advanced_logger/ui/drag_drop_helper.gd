@tool
class_name DragDropHelper
extends RefCounted
## Helper class for handling drag and drop operations in the Logger UI
##
## Centralizes drag and drop functionality for tag lists to avoid
## code duplication and improve maintainability.

# Tag source constants
const SOURCE_AVAILABLE: String = "available"
const SOURCE_ACTIVE: String = "active"
const SOURCE_IGNORED: String = "ignored"

# Now using static TagManager class directly

# Constructor - now just for initialization
func _init(_tag_manager_class) -> void:
	# No need to store tag_manager as we'll use it statically
	pass

## Creates a drag preview for a tag
## Parameters:
## - text: The text to display in the preview
## Returns: A Control node for the preview
func create_drag_preview(text: String) -> Control:
	var label = Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.8)

	var panel = Panel.new()
	panel.add_child(label)
	label.position = Vector2(10, 5)
	panel.custom_minimum_size = Vector2(label.get_minimum_size().x + 20, 30)

	return panel

## Gets drag data from a tag list
## Parameters:
## - item_list: The ItemList control
## - source_type: The source list type (available, active, ignored)
## Returns: The drag data or null if no item is selected
func get_drag_data_for_list(item_list: ItemList, source_type: String) -> Variant:
	var indices = item_list.get_selected_items()
	if indices.size() == 0:
		return null

	var tag_index = indices[0]
	var tag_text = item_list.get_item_metadata(tag_index) # Get original tag from metadata

	if not TagManager.is_valid_tag(tag_text):
		push_warning("Invalid tag: '%s'" % tag_text)
		return null

	# Create drag data
	var drag_data = {
		"type": "tag",
		"tag": tag_text,
		"source": source_type,
		"index": tag_index
	}

	return drag_data

## Checks if a tag can be dropped from one list to another
## Parameters:
## - tag: The tag being moved
## - source: The source list type
## - target: The target list type
## - active_tags: Current active tags
## - ignored_tags: Current ignored tags
## Returns: True if the drop is valid, false otherwise
func can_drop_tag(tag: String, source: String, target: String, active_tags: Array[String], ignored_tags: Array[String]) -> bool:
	# Can't drop to the same list
	if source == target:
		return false

	# Check valid source->target combinations
	match target:
		SOURCE_AVAILABLE:
			return source == SOURCE_ACTIVE or source == SOURCE_IGNORED
		SOURCE_ACTIVE:
			# Don't accept if already in active list
			if active_tags.has(tag):
				return false
			return source == SOURCE_AVAILABLE or source == SOURCE_IGNORED
		SOURCE_IGNORED:
			# Don't accept if already in ignored list
			if ignored_tags.has(tag):
				return false
			return source == SOURCE_AVAILABLE or source == SOURCE_ACTIVE

	return false
