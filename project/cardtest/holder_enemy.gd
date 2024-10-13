extends TextureRect

var target_pos

func get_current_lineup():
	var retval = {}
	for pos in $grid_container.get_children():
		var card = pos.get_card()
		if card:
			retval[pos.get_index()] = card
	return retval
