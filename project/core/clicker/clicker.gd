class_name Clicker extends Node

signal merge_completed

const NO_POS: Vector2i = Vector2i(-1, -1)
const SPAWN_HEIGHT: int = 0
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var level: LevelController
var refill_counter: Array[int] = []
var columns_locked: Array[int] = []


func setup(_level_controller: LevelController) -> void:
	await card_controller.setup()
	level = _level_controller
	level.setup_level()


func has_card(card: Card) -> bool:
	if level.get_grid_pos(card) == NO_POS:
		return false
	return true


func get_all_cards() -> Array[Block]:
	return level.all_blocks()


func remove_rerollables() -> void:
	for block: Block in level.all_blocks():
		var pos: Vector2i = level.get_grid_pos(block)
		var col: int = pos.x
		if not col in columns_locked:
			if LevelRules.REROLLABLES.has(block.object_type):
				level.remove_from_grid(block, true)


func on_core_event(event: core.CoreEvent, _current_context: Context) -> void:
	if event is core.DraftColumnStateEvent:
		if event.source == core.EventSource.PLAYER:
			var column: int = event.col
			var locked_state: bool = event.is_locked
			SemanticLogger.log_draft_toggle_line(column, locked_state)

		if event.is_locked:
			Log.debug(
				"Draft column locked", {"column": event.col}, [Log.TAG_DRAFT, Log.TAG_CLICKER]
			)
			columns_locked.append(event.col)
		else:
			Log.debug(
				"Draft column unlocked", {"column": event.col}, [Log.TAG_DRAFT, Log.TAG_CLICKER]
			)
			columns_locked.erase(event.col)

	if event is core.RerollDraftEvent:
		if event.source == core.EventSource.PLAYER:
			var current_cards: Array = []
			for block: Block in level.all_blocks():
				if block.object_type == core.ObjectType.CARD:
					var card_id: String = block.card_info.id
					current_cards.append(card_id)
			SemanticLogger.log_draft_reroll(0, current_cards, rng.seeded_rng._initial_seed)

		remove_rerollables()
		await _handle_async_update_blocks()

	if event is core.DraftAddBlockEvent:
		var grid_pos: Vector2i = event.pos
		var block: Block = event.block
		var count: int = event.refill_count
		level.add_to_grid(grid_pos, block, count)
		core.action(core.BlockEntersPlay.new(block, grid_pos))

	if event is core.UpgradeEvent:
		var new_level: int = event.new_level
		if event.source == core.EventSource.PLAYER:
			SemanticLogger.log_draft_upgrade(new_level)

		remove_upgrade_blocks(new_level)
		await _handle_async_update_blocks()

	if event is core.UpdateDraftAreaEvent:
		await _handle_async_update_blocks()

	if event is core.RemoveBlockFromDraft:
		var block: Block = event.block
		var is_destroy: bool = event.destroy_block

		if event.source == core.EventSource.PLAYER:
			var block_pos: Vector2i = level.get_grid_pos(block)
			var card_id: String = ""
			if block.object_type == core.ObjectType.CARD:
				card_id = block.card_info.id
			SemanticLogger.log_draft_remove_card(card_id, block_pos)

		if level.get_grid_pos(block) != Clicker.NO_POS:
			level.remove_from_grid(block, is_destroy)

		if event.source in [core.EventSource.PLAYER, core.EventSource.DEBUG_SETUP]:
			core.action(core.UpdateDraftAreaEvent.new())

	if event is core.DraftMergeEvent:
		var matches: Array[Card] = event.matches

		var matched_card_ids: Array[String] = []
		for card: Card in matches:
			matched_card_ids.append(card.unit_info.card_info.get("id", ""))

		Log.debug(
			"DraftMergeEvent: Starting merge process",
			{
				"matched_cards": matched_card_ids,
				"matches_count": matches.size(),
				"event_source":
				(
					str(event.source)
					if event.has_method("get") and event.get("source") != null
					else "unknown"
				)
			},
			[Log.TAG_MERGE, Log.TAG_CLICKER, Log.TAG_DEBUG]
		)

		for i: int in range(matches.size()):
			var match_card: Card = matches[i]
			Log.debug(
				"Pre-merge card StatEffect status",
				{
					"card_index": i,
					"card_id": match_card.card_info.id,
					"effects_perm_count": match_card.unit_info.effects_perm.size(),
					"card_level": match_card.level
				},
				[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
			)

		var merge_info: Dictionary = await merge_matched_cards(matches)
		await merge_info.awaiter.finished
		var new_block: Block = merge_info.block
		var pos: Vector2i = merge_info.pos

		if new_block is Card:
			var merged_card: Card = new_block as Card
			Log.debug(
				"Post-merge card StatEffect status",
				{
					"merged_card_id": merged_card.card_info.id,
					"merged_card_level": merged_card.level,
					"effects_perm_count": merged_card.unit_info.effects_perm.size(),
					"current_attack": merged_card.unit_info.current_attack,
					"current_health": merged_card.unit_info.current_health,
					"max_attack": merged_card.unit_info.max_attack,
					"max_health": merged_card.unit_info.max_health
				},
				[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
			)

		for _block: Block in event.matches:
			level.remove_from_grid(_block)
		core.action(core.DraftAddBlockEvent.new(new_block, pos))
		var tween: Tween = new_block.show_upgrade()
		await tween.finished
		merge_completed.emit()


func remove_upgrade_blocks(upgrade_level: int) -> void:
	for block: Block in level.all_blocks():
		if block.object_type == core.ObjectType.BLOCK_UPGRADE:
			if block.level == upgrade_level:
				level.remove_from_grid(block, true)


func update_blocks() -> void:
	var block_action: bool = true
	while block_action:
		block_action = false
		solve_gravity()
		while await refill():
			solve_gravity()
		await level.move_blocks()
		refill_counter.clear()
		var matches: Array[Card] = find_match()
		if matches.size():
			block_action = true
			core.action(core.DraftMergeEvent.new(matches))
			await merge_completed

	core.action(core.DraftSteadyEvent.new())


func _handle_async_update_blocks() -> void:
	await update_blocks()


func find_match() -> Array[Card]:
	for block: Block in level.all_blocks():
		if block != null and block.object_type == core.ObjectType.CARD:
			var cluster: Array[Card] = add_neighbour_cards(block, [block])
			if cluster.size() >= core.CARD_MERGE_AMOUNT:
				return cluster
	return []


func merge_matched_cards(cluster: Array[Card]) -> Dictionary:
	if cluster.is_empty():
		Log.error("Cannot merge empty cluster", {}, [Log.TAG_ERROR, Log.TAG_MERGE])
		return {}

	var first_card: Card = cluster[0] as Card
	if not first_card or not first_card.card_info:
		Log.error(
			"Invalid first card in cluster",
			{"cluster_size": cluster.size()},
			[Log.TAG_ERROR, Log.TAG_MERGE]
		)
		return {}

	var card_id: String = first_card.card_info.id
	var cluster_level: int = first_card.level
	var new_level: int = cluster_level + 1

	var source_units: Array[UnitData] = []
	for card: Card in cluster:
		if not card or not card.unit_info:
			Log.error(
				"Invalid card in cluster",
				{"card_id": card_id if card else "null"},
				[Log.TAG_ERROR, Log.TAG_MERGE]
			)
			continue
		source_units.append(card.unit_info)

	var new_card: Card = await card_controller.create_unit_from_id(card_id, new_level)
	if not new_card or not new_card.unit_info:
		Log.error(
			"Failed to create new merged card",
			{"card_id": card_id, "new_level": new_level},
			[Log.TAG_ERROR, Log.TAG_MERGE]
		)
		return {}

	new_card.block_context = Cards.CONTEXT.DRAFT

	Log.debug(
		"Before StatEffect transfer - source units analysis",
		{
			"card_id": card_id,
			"source_units_count": source_units.size(),
			"new_card_initial_effects": new_card.unit_info.effects_perm.size()
		},
		[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
	)

	for i: int in range(source_units.size()):
		var source_unit: UnitData = source_units[i]
		Log.debug(
			"Source unit StatEffect inventory",
			{
				"source_index": i,
				"source_card_id": source_unit.card_info.get("id", ""),
				"effects_perm_count": source_unit.effects_perm.size()
			},
			[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
		)

	new_card.unit_info.transfer_merge_effects_from(source_units)

	Log.debug(
		"ABOUT TO REAPPLY STATS - Post-transfer, pre-reapplication state",
		{
			"card_id": card_id,
			"new_level": new_level,
			"effects_perm_count": new_card.unit_info.effects_perm.size(),
			"current_attack_before_reapply": new_card.unit_info.current_attack,
			"current_health_before_reapply": new_card.unit_info.current_health,
			"max_attack": new_card.unit_info.max_attack,
			"max_health": new_card.unit_info.max_health,
			"context": "merge_matched_cards_post_transfer"
		},
		[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG, "stat_refresh"]
	)

	new_card.unit_info.apply_permanent_effects_to_current_stats()

	new_card.refresh_ui_from_unit_data()

	Log.info(
		"STAT REAPPLICATION COMPLETED - Final merged card state",
		{
			"card_id": card_id,
			"new_level": new_level,
			"effects_perm_count": new_card.unit_info.effects_perm.size(),
			"current_attack_after_reapply": new_card.unit_info.current_attack,
			"current_health_after_reapply": new_card.unit_info.current_health,
			"max_attack": new_card.unit_info.max_attack,
			"max_health": new_card.unit_info.max_health,
			"context": "merge_matched_cards_post_reapply"
		},
		[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG, "stat_refresh"]
	)

	Log.info(
		"Merged card with transferred effects",
		{
			"card_id": card_id,
			"old_level": cluster_level,
			"new_level": new_level,
			"source_units_count": source_units.size(),
			"final_effects_count": new_card.unit_info.effects_perm.size(),
			"final_abilities_count": new_card.unit_info.abilities.size(),
			"final_current_attack": new_card.unit_info.current_attack,
			"final_current_health": new_card.unit_info.current_health
		},
		[Log.TAG_CARD, Log.TAG_MERGE, Log.TAG_EFFECT]
	)
	var cluster_block: Block = cluster[1]
	var cluster_pos: Vector2i = level.get_grid_pos(cluster_block)
	var awaiter: SignalAwaiter = SignalAwaiter.All.new()
	for block: Block in cluster:
		block.merge_into_position(level.grid_to_world_pos(cluster_pos))
		awaiter = awaiter.add(block.movement_done)

	return {"block": new_card, "pos": cluster_pos, "awaiter": awaiter}


func add_neighbour_cards(block: Block, cluster: Array[Card] = []) -> Array[Card]:
	var start_pos: Vector2i = level.get_grid_pos(block)

	if start_pos == null:
		return cluster

	for direction: Vector2i in DIRECTIONS:
		var neighbour_pos: Vector2i = start_pos + direction

		if level.has_pos(neighbour_pos):
			var neighbour: Block = level.get_block(neighbour_pos)
			if neighbour.object_type == core.ObjectType.CARD and not cluster.has(neighbour):
				if neighbour.level == block.level and neighbour.card_info.id == block.card_info.id:
					cluster.append(neighbour)
					cluster = add_neighbour_cards(neighbour, cluster)

	return cluster


func refill() -> bool:
	var refill_action: bool = false

	for x: int in LevelRules.GRID_WIDTH:
		var test_pos: Vector2i = Vector2i(x, SPAWN_HEIGHT)

		if level.get_block(test_pos):
			var test_block: Block = level.get_block(test_pos)
			while test_pos.y < LevelRules.GRID_HEIGTH:
				if test_block.object_type == core.ObjectType.BLOCK_PASSTROUGH:
					test_pos = test_pos + LevelRules.GRAVITY_VECTOR
					if level.has_pos(test_pos):
						test_block = level.get_block(test_pos)
				else:
					break
			if test_block.object_type == core.ObjectType.EMPTY_SPACE:
				refill_counter.append(x)
				var new_block: Block = await level.create_block()
				core.action(
					core.DraftAddBlockEvent.new(new_block, test_pos, refill_counter.count(x))
				)
				refill_action = true
	return refill_action


func solve_gravity() -> void:
	var gravity_action: bool = true

	while gravity_action:
		gravity_action = false

		for block: Block in level.all_blocks():
			if block.object_type == core.ObjectType.EMPTY_SPACE:
				var test_pos: Vector2i = level.get_grid_pos(block) - LevelRules.GRAVITY_VECTOR
				if level.has_pos(test_pos):
					var test_block: Block = level.get_block(test_pos)
					while test_block.object_type == core.ObjectType.BLOCK_PASSTROUGH:
						test_pos = test_pos - LevelRules.GRAVITY_VECTOR
						if level.has_pos(test_pos):
							test_block = level.get_block(test_pos)
						else:
							break
					if ![core.ObjectType.BLOCK_PASSTROUGH, core.ObjectType.EMPTY_SPACE].has(
						test_block.object_type
					):
						level.switch_blocks(block, test_block)
						gravity_action = true




static func find_block_at_position(clicker_instance: Clicker, position: Vector2i) -> Block:
	"""Find block at specified grid position.

	Args:
		clicker_instance: The clicker instance to search in
		position: Grid position (Vector2i) to look for block

	Returns:
		Block at position, or null if no block found
	"""
	if not clicker_instance or not clicker_instance.level:
		return null

	return clicker_instance.level.get_block(position)


static func remove_block_from_draft_complete(
	clicker_instance: Clicker, block: Block, destroy: bool = true
) -> void:
	"""Complete block removal from draft with proper cascading actions.

	This method replicates the exact UI system logic for block removal,
	ensuring consistent behavior between UI interactions and debug actions.

	Args:
		block: The actual block to remove (must be real block from game state)
		destroy: Whether to destroy the block after removal
	"""
	if not clicker_instance or not block:
		Log.error(
			"Invalid parameters for block removal",
			{"clicker_valid": clicker_instance != null, "block_valid": block != null},
			["debug", "clicker", "error"]
		)
		return

	core.action(core.RemoveBlockFromDraft.new(block, destroy))
