class_name DebugCategory
extends RefCounted
## Pure data container for organizing debug buttons

## Category name
var category_name: String
## Full path for nested categories (e.g. "Parent/Child")
var full_path: String
## Parent category if this is a subcategory
var parent_category: DebugCategory = null
## Optional description
var description: String = ""

## Buttons in this category
var buttons: Array[DebugButton] = []


func _init(p_name: String, p_description: String = "") -> void:
	category_name = p_name
	description = p_description
	full_path = p_name


## Add a button to this category
func add_button(button: DebugButton) -> void:
	buttons.append(button)


## Create and add a new button
func create_button(
	label: String, callback: Callable, is_test: bool = false, description: String = ""
) -> DebugButton:
	var button = DebugButton.new(label, callback, is_test, category_name, description)
	add_button(button)
	return button


## Has subcategory with this name?
func has_subcategory(name: String) -> bool:
	for button in buttons:
		if button.is_category and button.category_name == name:
			return true
	return false


## Get a button by label
func get_button_by_label(label: String) -> DebugButton:
	for button in buttons:
		if button.text == label:
			return button
	return null
