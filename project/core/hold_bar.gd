extends NinePatchRect

@onready var h_box_container_buttons = $"%h_box_container_buttons"

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	for btn in h_box_container_buttons.get_children():
		btn.toggled.connect(on_hold_toggle.bind(btn))
func on_hold_toggle(state,btn):
	print("button toggle: ",btn,state)
	var col = btn.get_index()
	ui.action(ui.EVENT_TYPE.DRAFT_HOLD_TOGGLED,[btn.pressed,col])
