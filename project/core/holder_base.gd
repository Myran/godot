class_name HolderContainer extends TextureRect

var current_pos: Vector2i = Vector2i.ZERO
var is_moving: bool = false


func get_current_lineup(
	duplicate_card: bool = false, new_layer: Node = null
) -> Dictionary[int, Card]:
	var retval: Dictionary[int, Card] = {}
	for pos: Holder in $grid_container.get_children():
		var card: Card = pos.get_card()
		var new_card: Card
		if card:
			new_card = card
			if duplicate_card:
				new_card = card.duplicate()
				new_card.init_card(card.card_info, card.level)
			if new_layer != null:
				new_layer.add_child(new_card)
				new_card.global_position = card.global_position
			retval[pos.get_index()] = new_card
	return retval


func get_reenactment_lineup(new_layer: Node = null) -> Dictionary[int, Card]:
	var retval: Dictionary[int, Card] = {}
	for pos: Holder in $grid_container.get_children():
		var card: Card = pos.get_card()
		if card:
			var reenactment_card: Card = card.duplicate()
			reenactment_card.init_battle_reenactment(card)
			if new_layer != null:
				new_layer.add_child(reenactment_card)
				reenactment_card.global_position = card.global_position
			retval[pos.get_index()] = reenactment_card
	return retval


func get_card_position(card: Card) -> int:
	for pos: Holder in $grid_container.get_children():
		if pos.get_card() == card:
			return pos.get_index()
	return -1


func get_holder(pos: int) -> Holder:
	return $grid_container.get_child(pos)


func hide_lineup() -> void:
	lineup_visibility(false)


func show_lineup() -> void:
	lineup_visibility(true)


func lineup_visibility(vis: bool) -> void:
	for pos: Holder in $grid_container.get_children():
		var card: Card = pos.get_card()
		if card:
			card.visible = vis


func clear_lineup() -> void:
	"""Clear all cards from this lineup holder. For Debug Use"""
	for pos: Holder in $grid_container.get_children():
		var card: Card = pos.get_card()
		if card:
			# Clear holder reference first (sets _content = null)
			pos.remove_card()
			# Free the card (Godot will handle scene tree removal)
			card.queue_free()
