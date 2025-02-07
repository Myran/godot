class_name HoldingBar extends NinePatchRect

@export var h_box_container_buttons: Container


func _ready() -> void:
	for btn : TextureButton in h_box_container_buttons.get_children():
		btn.toggled.connect(on_hold_toggle.bind(btn))


func on_hold_toggle(state: bool, btn: TextureButton) -> void:
	print("button toggle: ", btn, state)
	var col: int = btn.get_index()
#	ui.action(ui.EVENT_TYPE.DRAFT_HOLD_TOGGLED,[btn.button_pressed,col])
	ui.action(ui.DraftHolderToggledEvent.new(btn.button_pressed, col))
