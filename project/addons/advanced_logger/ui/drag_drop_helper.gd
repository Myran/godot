@tool
class_name DragDropHelper
extends RefCounted

const TagCategories = preload("res://addons/advanced_logger/utils/tag_categories.gd")
const ConfigManager = preload("res://addons/advanced_logger/utils/config_manager.gd")

const SOURCE_AVAILABLE: String = "available"
const SOURCE_ACTIVE: String = "active"
const SOURCE_IGNORED: String = "ignored"


func _init(_tag_manager_class) -> void:
	pass

func create_drag_preview(text: String) -> Control:
	var label = Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.8)
	label.add_theme_font_size_override("font_size", 14)

	var panel = Panel.new()
	panel.add_child(label)
	label.position = Vector2(10, 5)
	panel.custom_minimum_size = Vector2(label.get_minimum_size().x + 20, 30)

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	stylebox.border_color = Color(0.5, 0.5, 0.5, 0.8)
	stylebox.border_width_bottom = 2
	stylebox.border_width_top = 2
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	panel.add_theme_stylebox_override("panel", stylebox)

	return panel

func get_drag_data_for_list(item_list: ItemList, source_type: String) -> Variant:
	var indices = item_list.get_selected_items()

	if indices.size() == 0:
		var mouse_pos = item_list.get_local_mouse_position()
		var item_at_position = item_list.get_item_at_position(mouse_pos)

		if item_at_position == -1:
			return null

		item_list.select(item_at_position)
		indices = [item_at_position]

	var tag_index = indices[0]

	if tag_index < 0 or tag_index >= item_list.get_item_count():
		return null

	var tag_text = item_list.get_item_metadata(tag_index) # Get original tag from metadata

	if OS.is_debug_build() and ConfigManager.get_instance().get_show_editor_debug():
		print_rich("[color=#7daea3]DEBUG: Getting drag data for index %d, tag: '%s'[/color]" % [tag_index, tag_text])

	if not TagManager.is_valid_tag(tag_text):
		push_warning("Invalid tag: '%s'" % tag_text)
		return null

	var drag_data = {
		"type": "tag",
		"tag": tag_text,
		"source": source_type,
		"index": tag_index
	}

	if OS.is_debug_build() and ConfigManager.get_instance().get_show_editor_debug():
		print_rich("[color=#7daea3]DEBUG: Created drag data: %s[/color]" % [drag_data])

	return drag_data

func can_drop_tag(tag: String, source: Variant, target: Variant, active_tags: Array[String], ignored_tags: Array[String]) -> bool:
	var source_cat := source
	var target_cat := target

	if source_cat is String:
		source_cat = TagCategories.from_string(source_cat)
	if target_cat is String:
		target_cat = TagCategories.from_string(target_cat)

	if source_cat == target_cat:
		return false

	match target_cat:
		TagCategories.Category.AVAILABLE:
			return source_cat == TagCategories.Category.ACTIVE or source_cat == TagCategories.Category.IGNORED
		TagCategories.Category.ACTIVE:
			if active_tags.has(tag):
				return false
			return source_cat == TagCategories.Category.AVAILABLE or source_cat == TagCategories.Category.IGNORED
		TagCategories.Category.IGNORED:
			if ignored_tags.has(tag):
				return false
			return source_cat == TagCategories.Category.AVAILABLE or source_cat == TagCategories.Category.ACTIVE

	return false
