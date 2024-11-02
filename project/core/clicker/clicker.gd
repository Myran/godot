extends Node

signal merge_completed

const GRAVITY_VECTOR = Vector2i(0,1)
const CARD_MERGE_AMOUNT = 3
const SPAWN_HEIGHT = 0
var directions = [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
var level
var refill_counter = []


var rerollables  = [core.OBJECT_TYPE.CARD,core.OBJECT_TYPE.BLOCK_ITEM]
var columns_locked = []

func setup(_level_controller):
	card_controller.setup()
	level = _level_controller
	level.setup_level()


	
func has_card(card):
	if level.get_grid_pos(card) == null:
		return false
	return true

func get_all_cards():
	return level.all_blocks()

func remove_rerollables():
	for block in level.all_blocks():
		var pos = level.get_grid_pos(block)
		var col = pos.x
		if not col in columns_locked:
			if rerollables.has(block.object_type):
					level.remove_from_grid(block,true)

func on_core_event(event_type,_data, _current_context):
	match event_type:
		core.EVENT_TYPE.DRAFT_COLOUMN_LOCKED:
			var col = _data[0]
			print("Draft coloumn locked: ",col)
			columns_locked.append(col)

		core.EVENT_TYPE.DRAFT_COLUMN_UNLOCKED:
			var col = _data[0]
			print("Draft coloumn unlocked: ",col)
			columns_locked.erase(col)


		core.EVENT_TYPE.REROLL_DRAFT:
			remove_rerollables()
			update_blocks()

		core.EVENT_TYPE.DRAFT_ADD_BLOCK:
			var match_info = _data[0]
			level.add_to_grid(match_info.pos,match_info.block)

		core.EVENT_TYPE.UPGRADE:
			var upgrade_level = _data[0]
			remove_upgrade_blocks(upgrade_level)
			update_blocks()

		core.EVENT_TYPE.UPDATE_DRAFT_AREA:
			update_blocks()

		core.EVENT_TYPE.REMOVE_BLOCK_FROM_DRAFT:
			var block = _data[0]
			var destroy = false
			if _data.size()>1:
				destroy = _data[1]
			if level.get_grid_pos(block) != null:
				level.remove_from_grid(block,destroy)

		core.EVENT_TYPE.DRAFT_MERGE:
			var matches = _data[0]
			var merge_info = await merge_matched_cards(matches)
			await merge_info.awaiter.finished
			for _block in matches:
				level.remove_from_grid(_block)
			
			core.action(core.EVENT_TYPE.DRAFT_ADD_BLOCK,[merge_info])
			var tween = merge_info.block.show_upgrade()
			await tween.finished
			merge_completed.emit()


func remove_upgrade_blocks(upgrade_level):
	for block in level.all_blocks():
		if block.object_type == core.OBJECT_TYPE.BLOCK_UPGRADE:
			if block.level == upgrade_level:
				level.remove_from_grid(block,true)


func update_blocks():
	var block_action = true
	while block_action:
		block_action = false
		solve_gravity()
		while refill():
			solve_gravity()
		await level.move_blocks()
		refill_counter.clear()
		var matches = find_match()
		if matches.size():
			block_action = true	
			core.action(core.EVENT_TYPE.DRAFT_MERGE,[matches])
			await merge_completed


	core.action(core.EVENT_TYPE.DRAFT_STEADY,[])

func find_match():
	for block in level.all_blocks():
		if block != null and block.object_type == core.OBJECT_TYPE.CARD:
			var cluster = add_neighbour_cards(block,[block])
			if cluster.size() >= CARD_MERGE_AMOUNT:
				return cluster
	return []

func merge_matched_cards(cluster):
	var card_id = cluster[0].card_info.id
	var new_level = int(cluster[0].level)+1
	var new_card = await card_controller.create_unit_from_id(card_id,new_level)
	new_card.block_context = Cards.CONTEXT.DRAFT
	var cluster_pos = level.get_grid_pos(cluster[1])
	var awaiter = SignalAwaiter.All.new()
	#add_child(awaiter)
	for block in cluster:
		block.merge_into_position(level.grid_to_world_pos(cluster_pos))
		#merging_cards.append(block)
		awaiter.add(block.movement_done)

	return {
		"block" : new_card,
		"pos" : cluster_pos,
		"awaiter" : awaiter
	}



func add_neighbour_cards(block,cluster = []):

	var start_pos = level.get_grid_pos(block)

	if start_pos == null:
		return cluster

	for direction in directions:
		var neighbour_pos = start_pos + direction

		if level.has_pos(neighbour_pos):
			var neighbour = level.get_block(neighbour_pos)
			if neighbour.object_type == core.OBJECT_TYPE.CARD and not cluster.has(neighbour):
				if neighbour.level == block.level and neighbour.card_info.id == block.card_info.id:
					cluster.append(neighbour)
					add_neighbour_cards(neighbour,cluster)

	return cluster


func refill():
	var refill_action = false

	for x in level.GRID_WIDTH:
		var test_pos = Vector2i(x,SPAWN_HEIGHT)

		if level.get_block(test_pos):
			var test_block = level.get_block(test_pos)
			while (test_pos.y < level.GRID_HEIGTH):
				if test_block.object_type == core.OBJECT_TYPE.BLOCK_PASSTROUGH:
					test_pos = test_pos + GRAVITY_VECTOR
					if level.has_pos(test_pos):
						test_block = level.get_block(test_pos)
				else:
					break
			if test_block.object_type == core.OBJECT_TYPE.EMPTY_SPACE:
				refill_counter.append(x)
				level.add_to_grid(test_pos,level.create_block(),refill_counter.count(x))
				refill_action = true
	return refill_action


func solve_gravity():

	var gravity_action = true

	while gravity_action:
		gravity_action = false

		for block in level.all_blocks():

			if block.object_type == core.OBJECT_TYPE.EMPTY_SPACE:

				var test_pos = level.get_grid_pos(block)-GRAVITY_VECTOR
				if level.has_pos(test_pos):
					var test_block = level.get_block(test_pos)
					while test_block.object_type == core.OBJECT_TYPE.BLOCK_PASSTROUGH:
							test_pos = test_pos - GRAVITY_VECTOR
							if level.has_pos(test_pos):
								test_block = level.get_block(test_pos)
							else:
								break
					if ![core.OBJECT_TYPE.BLOCK_PASSTROUGH,core.OBJECT_TYPE.EMPTY_SPACE].has(test_block.object_type):
						level.switch_blocks(block,test_block)
						gravity_action = true
