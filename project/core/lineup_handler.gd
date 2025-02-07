class_name LineupHandler extends Node

var holder_container: HolderContainer


func setup(_holder: HolderContainer) -> void:
	holder_container = _holder


func add_card(card: Card, pos: int) -> void:
	var holder_pos: Holder = holder_container.get_holder(pos)
	holder_pos.set_card(card)


func find_tripples() -> Array[Card]:
	var lineup: Dictionary = holder_container.get_current_lineup()
	for card: Card in lineup.values():
		var tripples: Array[Card] = []
		for lineup_card: Card in lineup.values():
			if lineup_card.card_info.id == card.card_info.id and lineup_card.level == card.level:
				if not tripples.has(lineup_card):
					tripples.append(lineup_card)
		if tripples.size() >= core.CARD_MERGE_AMOUNT:
			return tripples
	return []


func merge(card: Card, tripples: Array) -> Card:
	var new_card: Card
	var merge_pos: Vector2i
	var awaiter: SignalAwaiter = SignalAwaiter.All.new()
	for trip_card: Card in tripples:
		var lineup_pos: int = holder_container.get_card_position(trip_card)
		var current_holder: Holder = holder_container.get_holder(lineup_pos)
		current_holder.remove_card()

		if trip_card == card:
			var id: String = card.card_info.id
			new_card = await card_controller.create_unit_from_id(id, card.level + 1)
			new_card.block_context = Cards.CONTEXT.LINEUP
			current_holder.set_card(new_card)
			new_card.show_upgrade()
			merge_pos = new_card.get_global_position()

	for trip_card: Card in tripples:
		awaiter.add(trip_card.movement_done)
		trip_card.move_to_on_top(merge_pos)
	await awaiter.finished
	for trip_card: Card in tripples:
		trip_card.queue_free()
	return new_card
