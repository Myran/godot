class_name TagContainer extends PanelContainer
@onready var label: Label = $label


func _on_button_pressed() -> void:
	Log.debug("Tag button pressed", {"tag_text": label.text}, ["ui"])


#	ui.action(ui.EVENT_TYPE.TAP_TAG,[self])
func set_tag(_tag_text: String = "tag text") -> void:
	label.text = _tag_text
