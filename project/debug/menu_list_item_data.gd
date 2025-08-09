class_name MenuListItemData
extends RefCounted

enum ItemType { CATEGORY, GROUP, ACTION, BACK_TO_MAIN, BACK_TO_GROUPS }

@export var type: ItemType
@export var display_name: String = ""
@export var category_name: String = ""
@export var group_name: String = ""
@export var action_instance: DebugAction = null
@export var prefix: String = ""
@export var has_run_all: bool = false


func _init(p_type: ItemType = ItemType.CATEGORY) -> void:
	type = p_type


static func create_category(name: String, _has_run_all: bool = false) -> MenuListItemData:
	var data: MenuListItemData = MenuListItemData.new(ItemType.CATEGORY)
	data.display_name = name
	data.category_name = name
	data.has_run_all = _has_run_all
	return data


static func create_group(category: String, group: String) -> MenuListItemData:
	var data: MenuListItemData = MenuListItemData.new(ItemType.GROUP)
	data.display_name = group
	data.category_name = category
	data.group_name = group
	return data


static func create_action(
	action: DebugAction, category: String, group: String = ""
) -> MenuListItemData:
	var data: MenuListItemData = MenuListItemData.new(ItemType.ACTION)
	data.display_name = action.action_name
	data.category_name = category
	data.group_name = group
	data.action_instance = action
	return data


static func create_back_to_main() -> MenuListItemData:
	var data: MenuListItemData = MenuListItemData.new(ItemType.BACK_TO_MAIN)
	data.display_name = "< Back to Main"
	data.prefix = ""
	return data


static func create_back_to_groups(category: String) -> MenuListItemData:
	var data: MenuListItemData = MenuListItemData.new(ItemType.BACK_TO_GROUPS)
	data.display_name = "< Back to Groups"
	data.category_name = category
	data.prefix = ""
	return data
