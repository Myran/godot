extends PanelContainer
@onready var label: Label = $label


func _on_button_pressed() -> void:
	print("tag pressed: ", label.text)


#	ui.action(ui.EVENT_TYPE.TAP_TAG,[self])
func set_tag(_tag_text: String = "tag text") -> void:
	label.text = _tag_text
