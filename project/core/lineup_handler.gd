class_name LineupHandler extends Node

var holder_container: HolderContainer


func setup(_holder: HolderContainer) -> void:
	holder_container = _holder


func add_card(card: Card, pos: int) -> void:
	var holder_pos: Holder = holder_container.get_holder(pos)

	# Enhanced semantic logging for lineup addition (system action)
	Log.info(
		"Lineup handler adding card",
		{
			"card_id": card.card_info.id,
			"card_level": card.unit_info.level,
			"target_position": pos,
			"handler": "lineup_handler"
		},
		["semantic", "lineup", "add_card"]
	)

	holder_pos.set_card(card)


func find_tripples() -> Array[Card]:
	var lineup: Dictionary = holder_container.get_current_lineup()
	var tripple_found: bool = false
	var found_card_id: String = ""
	var found_level: int = -1

	for card: Card in DictUtils.values_sorted(lineup):
		var tripples: Array[Card] = []
		for lineup_card: Card in DictUtils.values_sorted(lineup):
			if lineup_card.card_info.id == card.card_info.id and lineup_card.level == card.level:
				if not tripples.has(lineup_card):
					tripples.append(lineup_card)
		if tripples.size() >= core.CARD_MERGE_AMOUNT:
			tripple_found = true
			found_card_id = card.card_info.id
			found_level = card.level

			# Enhanced semantic logging for tripple detection
			Log.info(
				"Tripple cards found for merge",
				{
					"card_id": found_card_id,
					"card_level": found_level,
					"tripple_count": tripples.size(),
					"handler": "lineup_handler"
				},
				["semantic", "lineup", "tripple_found"]
			)

			return tripples

	# Log when no tripples found
	Log.debug(
		"No tripples found in current lineup",
		{"lineup_card_count": lineup.size(), "handler": "lineup_handler"},
		["semantic", "lineup", "no_tripples"]
	)

	return []


func merge(card: Card, tripples: Array) -> Card:
	var merge_start_time: float = Time.get_unix_time_from_system() * 1000.0
	var old_level: int = card.level
	var new_level: int = card.level + 1

	# Enhanced semantic logging for merge start
	Log.info(
		"Starting lineup card merge",
		{
			"card_id": card.card_info.id,
			"old_level": old_level,
			"new_level": new_level,
			"tripple_count": tripples.size(),
			"handler": "lineup_handler"
		},
		["semantic", "lineup", "merge_start"]
	)

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

	var merge_duration: float = (Time.get_unix_time_from_system() * 1000.0) - merge_start_time

	# Enhanced semantic logging for merge completion
	Log.info(
		"Lineup card merge completed",
		{
			"card_id": card.card_info.id,
			"old_level": old_level,
			"new_level": new_level,
			"merge_duration_ms": merge_duration,
			"tripples_merged": tripples.size(),
			"handler": "lineup_handler"
		},
		["semantic", "lineup", "merge_complete", "performance"]
	)

	return new_card
