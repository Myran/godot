extends NinePatchRect

@onready var h_box_container_buttons = $"%h_box_container_buttons"

func _ready():
	for btn in h_box_container_buttons.get_children():
		btn.toggled.connect(on_hold_toggle.bind(btn))

func on_hold_toggle(state,btn):
	print("button toggle: ",btn,state)
	var col = btn.get_index()
	ui.action(ui.EVENT_TYPE.DRAFT_HOLD_TOGGLED,[btn.button_pressed,col])
