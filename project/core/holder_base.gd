extends TextureRect

var current_pos = null
var is_moving = false

func get_current_lineup(duplicate_card = false,new_layer = null):
	var retval = {}
	for pos in $grid_container.get_children():
		var card = pos.get_card()
		var new_card
		if card:
			new_card = card
			if duplicate_card:
				new_card = card.duplicate()
				new_card.init_card(card.card_info,card.level)
			if new_layer != null:
				new_layer.add_child(new_card)
				new_card.global_position = card.global_position
			retval[pos.get_index()] = new_card
	return retval


func get_card_position(_card):
	for pos in $grid_container.get_children():
		if pos.get_card() == _card:
			return pos.get_index()

func get_holder(pos):
	return $grid_container.get_child(pos)

func hide_lineup():
	lineup_visibility(false)
func show_lineup():
	lineup_visibility(true)

func lineup_visibility(vis):
	for pos in $grid_container.get_children():
		var card = pos.get_card()
		if card:
			card.visible = vis
