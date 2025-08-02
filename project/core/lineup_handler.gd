class_name LineupHandler extends Node

var holder_container: HolderContainer


func setup(holder: HolderContainer) -> void:
	holder_container = holder


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
	var lineup: Dictionary[int, Card] = holder_container.get_current_lineup()
	var tripple_found: bool = false
	var found_card_id: String = ""
	var found_level: int = -1

	# Enhanced granular logging for tripple detection call
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

	# Create merged card with effects transferred
	var new_card: Card = await _create_merged_card(base_card, source_cards)

	# Handle positioning and animation
	await _finalize_merge_animation(source_cards, new_card)

	Log.info(
		"Lineup merge completed",
		{"card_id": base_card.card_info.id, "effects": new_card.unit_info.effects_perm.size()},
		[Log.TAG_MERGE]
	)

	return new_card


# Create merged card with proper effect transfer
func _create_merged_card(base_card: Card, source_cards: Array[Card]) -> Card:
	var new_card: Card = await card_controller.create_unit_from_id(
		base_card.card_info.id, base_card.level + 1
	)
	new_card.block_context = Cards.CONTEXT.LINEUP

	# Transfer effects directly from cards (more efficient)
	new_card.unit_info.transfer_merge_effects_from_cards(source_cards)
	new_card.unit_info.apply_permanent_effects_to_current_stats()
	new_card.refresh_ui_from_unit_data()

	return new_card


# Handle merge animation and cleanup
func _finalize_merge_animation(source_cards: Array[Card], new_card: Card) -> void:
	# Remove source cards and place new card
	var base_pos: int = holder_container.get_card_position(source_cards[0])

	for source_card: Card in source_cards:
		var pos: int = holder_container.get_card_position(source_card)
		holder_container.get_holder(pos).remove_card()

	holder_container.get_holder(base_pos).set_card(new_card)
	new_card.show_upgrade()

	# Animate and cleanup
	var merge_pos: Vector2i = new_card.get_global_position()
	var awaiter: SignalAwaiter.All = SignalAwaiter.All.new()

	for source_card: Card in source_cards:
		awaiter.add(source_card.movement_done)
		source_card.move_to_on_top(merge_pos)

	await awaiter.finished

	for source_card: Card in source_cards:
		source_card.queue_free()
