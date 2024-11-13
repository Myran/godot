extends PanelContainer
@onready var label = $label


func _on_button_pressed():
	print("tag pressed: ", label.text)


#	ui.action(ui.EVENT_TYPE.TAP_TAG,[self])
func set_tag(_tag_text = "tag text"):
	label.text = _tag_text
