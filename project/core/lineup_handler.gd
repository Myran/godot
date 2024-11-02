class_name LineupHandler extends Node

var holder


func _init(_holder) -> void:
	holder = _holder


func add_card(card, pos):
	var holder_pos = holder.get_holder(pos)
	holder_pos.set_card(card)


func find_tripples():
	var lineup = holder.get_current_lineup()
	for card in lineup.values():
		var tripples = []
		for lineup_card in lineup.values():
			if lineup_card.card_info.id == card.card_info.id and lineup_card.level == card.level:
				if not tripples.has(lineup_card):
					tripples.append(lineup_card)
		if tripples.size() >= core.CARD_MERGE_AMOUNT:
			return tripples
	return []


func merge(card, tripples):
	var new_card
	var merge_pos
	var awaiter = SignalAwaiter.All.new()
	for trip_card in tripples:
		var lineup_pos = holder.get_card_position(trip_card)
		var current_holder = holder.get_holder(lineup_pos)
		current_holder.remove_card()
		#update_context_units(current_context)
		if trip_card == card:
			new_card = await card_controller.create_unit_from_id(card.card_info.id, card.level + 1)
			new_card.block_context = Cards.CONTEXT.LINEUP
			current_holder.set_card(new_card)
			new_card.show_upgrade()
			merge_pos = new_card.get_global_position()

	for trip_card in tripples:
		awaiter.add(trip_card.movement_done)
		trip_card.move_to_on_top(merge_pos)
	await awaiter.finished
	for trip_card in tripples:
		trip_card.queue_free()
	return new_card
