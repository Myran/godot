extends Control

@export var card_popup: PackedScene
var current_card

func _on_popup_card_about_to_show():
	if not visible:
		return
	if current_card:
		current_card.show_card()
	else:
		print("card to show missing")

func _on_popup_card_gui_input(event):
	print("Event:",event)


func setup_card(_card):
	var new_card = card_popup.instantiate()
	add_child(new_card)
	new_card.setup_card(_card)
	if current_card:
		current_card.queue_free()
	current_card = new_card

func show_card(_card):
	setup_card(_card)
	show()
