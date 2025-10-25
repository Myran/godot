class_name LineupHandler extends Node

var holder_container: HolderContainer
var game: Game


func setup(holder: HolderContainer, game_instance: Game) -> void:
	holder_container = holder
	game = game_instance


func add_card(card: Card, pos: int) -> void:
	var holder_pos: Holder = holder_container.get_holder(pos)

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
	var lineup: Dictionary[int, Card] = holder_container.get_current_lineup()
	var tripple_found: bool = false
	var found_card_id: String = ""
	var found_level: int = -1

	var lineup_summary: Array[Dictionary] = []
	for pos: int in lineup.keys():
		var card: Card = lineup[pos]
		lineup_summary.append(
			{"position": pos, "card_id": card.card_info.id, "card_level": card.level}
		)

	Log.debug(
		"TRIPPLE DETECTION CALLED - Current lineup state",
		{"lineup_size": lineup.size(), "lineup_cards": lineup_summary, "handler": "lineup_handler"},
		["semantic", "lineup", "tripple_detection_start"]
	)

	var sorted_cards: Array[Card] = []
	var sorted_positions: Array[int] = DictUtils.keys_sorted(lineup)
	for pos: int in sorted_positions:
		sorted_cards.append(lineup[pos])

	var position_order: Array[String] = []
	for pos: int in sorted_positions:
		position_order.append(str(pos))
	var card_iteration_order: Array[String] = []
	for card: Card in sorted_cards:
		card_iteration_order.append("%s_L%d" % [card.card_info.id, card.level])

	Log.debug(
		"DETERMINISM DEBUG - Position-based iteration order",
		{
			"sorted_positions": sorted_positions,
			"position_order_str": position_order,
			"card_iteration_order": card_iteration_order,
			"platform": OS.get_name(),
			"handler": "lineup_handler"
		},
		["semantic", "lineup", "determinism_debug"]
	)

	var processed_types: Array[String] = []

	for card: Card in sorted_cards:
		var card_type_key: String = "%s_L%d" % [card.card_info.id, card.level]

		if processed_types.has(card_type_key):
			continue

		var tripples: Array[Card] = []
		for lineup_card: Card in sorted_cards:
			if lineup_card.card_info.id == card.card_info.id and lineup_card.level == card.level:
				if not tripples.has(lineup_card):
					tripples.append(lineup_card)

		Log.debug(
			"Checking card for tripples",
			{
				"checking_card": card_type_key,
				"found_matches": tripples.size(),
				"merge_threshold": core.CARD_MERGE_AMOUNT,
				"will_merge": tripples.size() >= core.CARD_MERGE_AMOUNT,
				"already_processed": processed_types,
				"handler": "lineup_handler"
			},
			["semantic", "lineup", "tripple_check"]
		)

		if tripples.size() >= core.CARD_MERGE_AMOUNT:
			tripple_found = true
			found_card_id = card.card_info.id
			found_level = card.level

			var merge_card_details: Array[String] = []
			for merge_card: Card in tripples:
				var card_pos: int = holder_container.get_card_position(merge_card)
				merge_card_details.append(
					"pos_%d:%s_L%d" % [card_pos, merge_card.card_info.id, merge_card.level]
				)

			Log.info(
				"Tripple cards found for merge",
				{
					"card_id": found_card_id,
					"card_level": found_level,
					"tripple_count": tripples.size(),
					"merge_cards_detail": merge_card_details,
					"first_card_position": holder_container.get_card_position(tripples[0]),
					"unique_merge": true,
					"handler": "lineup_handler"
				},
				["semantic", "lineup", "tripple_found"]
			)

			return tripples

		processed_types.append(card_type_key)

	Log.debug(
		"No tripples found in current lineup",
		{"lineup_card_count": lineup.size(), "handler": "lineup_handler"},
		["semantic", "lineup", "no_tripples"]
	)

	return []


func merge(base_card: Card, source_cards: Array[Card]) -> Card:
	Log.info(
		"Starting lineup merge",
		{
			"card_id": base_card.card_info.id,
			"level": base_card.level,
			"sources": source_cards.size()
		},
		[Log.TAG_MERGE]
	)

	var new_card: Card = await _create_merged_card(base_card, source_cards)

	await _finalize_merge_animation(source_cards, new_card)

	Log.info(
		"Lineup merge completed",
		{"card_id": base_card.card_info.id, "effects": new_card.unit_info.effects_perm.size()},
		[Log.TAG_MERGE]
	)

	return new_card


func _create_merged_card(base_card: Card, source_cards: Array[Card]) -> Card:
	var card_id: String = base_card.card_info.get("id", "")
	var new_card: Card = await card_controller.create_unit_from_id(card_id, base_card.level + 1)
	new_card.block_context = Cards.CONTEXT.LINEUP

	new_card.unit_info.transfer_merge_effects_from_cards(source_cards)
	new_card.unit_info.apply_permanent_effects_to_current_stats()
	new_card.refresh_ui_from_unit_data()

	return new_card


func _finalize_merge_animation(source_cards: Array[Card], new_card: Card) -> void:
	var base_pos: int = holder_container.get_card_position(source_cards[0])

	for source_card: Card in source_cards:
		var pos: int = holder_container.get_card_position(source_card)
		holder_container.get_holder(pos).remove_card()

	holder_container.get_holder(base_pos).set_card(new_card)
	new_card.show_upgrade()

	var merge_pos: Vector2i = new_card.get_global_position()
	var awaiter: SignalAwaiter.All = SignalAwaiter.All.new()

	for source_card: Card in source_cards:
		awaiter.add(source_card.movement_done)
		source_card.move_to_on_top(merge_pos)

	await awaiter.finished

	for source_card: Card in source_cards:
		source_card.queue_free()
