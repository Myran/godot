@tool
class_name UIBuilder
extends RefCounted

# Creates a titled section with standard styling
func create_section(parent: Control, title: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)

	var header = Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 16)
	section.add_child(header)

	parent.add_child(section)
	return section
