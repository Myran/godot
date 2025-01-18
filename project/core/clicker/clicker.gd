class_name Clicker extends Node

signal merge_completed
const NO_POS = Vector2i(-1, -1)
const SPAWN_HEIGHT = 0
const DIRECTIONS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var level: LevelController
var refill_counter := []
var columns_locked := []


func setup(_level_controller: LevelController) -> void:
	card_controller.setup()
	level = _level_controller
	level.setup_level()


func has_card(card: Card) -> bool:
	if level.get_grid_pos(card) == NO_POS:
		return false
	return true


func get_all_cards() -> Array:
	return level.all_blocks()


func remove_rerollables() -> void:
	for block: Block in level.all_blocks():
		var pos: Vector2i = level.get_grid_pos(block)
		var col: int = pos.x
		if not col in columns_locked:
			if LevelRules.REROLLABLES.has(block.object_type):
				level.remove_from_grid(block, true)


func on_core_event(event: core.CoreEvent, _current_context: Context) -> void:
	if event is core.DraftColumnLocked:
		print("Draft coloumn locked: ", event.col)
		columns_locked.append(event.col)

	if event is core.DraftColumnUnlocked:
		print("Draft coloumn unlocked: ", event.col)
		columns_locked.erase(event.col)

	if event is core.RerollDraftEvent:
		remove_rerollables()
		update_blocks()

	if event is core.DraftAddBlockEvent:
		level.add_to_grid(event.pos, event.block, event.refill_count)

	if event is core.UpgradeEvent:
		remove_upgrade_blocks(event.new_level)
		update_blocks()

	if event is core.UpdateDraftAreaEvent:
		update_blocks()

	if event is core.RemoveBlockFromDraft:
		if level.get_grid_pos(event.block) != Clicker.NO_POS:
			level.remove_from_grid(event.block, event.destroy_block)

	if event is core.DraftMergeEvent:
		var merge_info: Dictionary = await merge_matched_cards(event.matches)
		await merge_info.awaiter.finished
		for _block: Block in event.matches:
			level.remove_from_grid(_block)
		core.action(core.DraftAddBlockEvent.new(merge_info.block, merge_info.pos))
		var tween: Tween = merge_info.block.show_upgrade()
		await tween.finished
		merge_completed.emit()


func remove_upgrade_blocks(upgrade_level: int) -> void:
	for block: Block in level.all_blocks():
		if block.object_type == core.ObjectType.BLOCK_UPGRADE:
			if block.level == upgrade_level:
				level.remove_from_grid(block, true)


func update_blocks() -> void:
	var block_action := true
	while block_action:
		block_action = false
		solve_gravity()
		while await refill():
			solve_gravity()
		await level.move_blocks()
		refill_counter.clear()
		var matches: Array = find_match()
		if matches.size():
			block_action = true
			core.action(core.DraftMergeEvent.new(matches))
			await merge_completed

	core.action(core.DraftSteadyEvent.new())


func find_match() -> Array:
	for block: Block in level.all_blocks():
		if block != null and block.object_type == core.ObjectType.CARD:
			var cluster: Array = add_neighbour_cards(block, [block])
			if cluster.size() >= core.CARD_MERGE_AMOUNT:
				return cluster
	return []


func merge_matched_cards(cluster: Array) -> Dictionary:
	var card_id: String = cluster[0].card_info.id
	var new_level: int = int(cluster[0].level) + 1
	var new_card: Block = await card_controller.create_unit_from_id(card_id, new_level)
	new_card.block_context = Cards.CONTEXT.DRAFT
	var cluster_pos: Vector2i = level.get_grid_pos(cluster[1])
	var awaiter: SignalAwaiter = SignalAwaiter.All.new()
	for block: Block in cluster:
		block.merge_into_position(level.grid_to_world_pos(cluster_pos))

		awaiter.add(block.movement_done)

	return {"block": new_card, "pos": cluster_pos, "awaiter": awaiter}


func add_neighbour_cards(block: Block, cluster: Array = []) -> Array:
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
					add_neighbour_cards(neighbour, cluster)

	return cluster


func refill() -> bool:
	var refill_action := false

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
				#level.add_to_grid(test_pos, new_block, refill_counter.count(x))
				core.action(
					core.DraftAddBlockEvent.new(new_block, test_pos, refill_counter.count(x))
				)
				refill_action = true
	return refill_action


func solve_gravity() -> void:
	var gravity_action := true

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
