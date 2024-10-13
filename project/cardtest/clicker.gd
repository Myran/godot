extends Node
var level
const CARD_MERGE_AMOUNT = 3
const SPAWN_HEIGHT = 0
var directions = [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)]
var gravityVector = Vector2i(0,1)
var refillCounter = []
var merging_cards = []

signal level_done
signal block_collected
signal merge_card_done
signal merge_move_done

var rerollables  = [core.OBJECT_TYPE.CARD,core.OBJECT_TYPE.BLOCK_ITEM]
var columns_locked = []
func setup():
	card_controller.setup()
	level = get_node("%level_controller")
	level.setup_level()
	#core.connect("event",self,"_on_core_event")
	if core.clicker == null:
		core.clicker = self

func has_card(card):
	if level.getGridPos(card) == null:
		return false
	return true

func get_all_cards():
	return level.allBlocks()
	
func remove_rerollables():
	for block in level.allBlocks():
		var pos = level.getGridPos(block)
		var col = pos.x
		if not col in columns_locked:
			if rerollables.has(block.object_type):
					level.removeFromGrid(block,true)

func _on_core_event(event_type,_data):
	match event_type:
		core.EVENT_TYPE.DRAFT_COLOUMN_LOCKED:
			var col = _data[0]
			print("Draft coloumn locked: ",col)
			columns_locked.append(col)
		core.EVENT_TYPE.DRAFT_COLUMN_UNLOCKED:
			var col = _data[0]
			print("Draft coloumn unlocked: ",col)
			columns_locked.erase(col)
		core.EVENT_TYPE.MERGE_CARD_DONE:
			emit_signal("merge_card_done")
		core.EVENT_TYPE.CARD_MERGE_MOVE_FINISHED:
			var card = _data
			merging_cards.erase(card)
			level.removeFromGrid(card)
			if merging_cards.size() == 0:
				emit_signal("merge_move_done")
		core.EVENT_TYPE.REROLL_DRAFT:
			remove_rerollables()
			update_blocks()
		core.EVENT_TYPE.DRAFT_ADD_BLOCK:
			var match_info = _data[0]
			level.addToGrid(match_info.pos,match_info.block)
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
			if level.getGridPos(block) != null:
				level.removeFromGrid(block,destroy)
		core.EVENT_TYPE.DRAFT_MERGE:
			var matches = _data[0]
			var merge_info = await merge_matched_cards(matches)
			await self.merge_move_done
			core.emit_signal("event",core.EVENT_TYPE.DRAFT_ADD_BLOCK,[merge_info])
			merge_info.block.show_upgrade()
			await self.merge_card_done
			update_blocks()
			pass
func remove_upgrade_blocks(upgrade_level):
	for block in level.allBlocks():
		if block.object_type == core.OBJECT_TYPE.BLOCK_UPGRADE:
			if block.level == upgrade_level:
				level.removeFromGrid(block,true)


func update_blocks():
	solveGravity()
	while refill():
		solveGravity()
	await level.moveBlocks().completed
	refillCounter.clear()
	var matches = find_match()
	if matches.size():
		core.emit_signal("event",core.EVENT_TYPE.DRAFT_MERGE,[matches])


func find_match():
	for block in level.allBlocks():
		if block != null and block.object_type == core.OBJECT_TYPE.CARD:
			var cluster = addNeighbourCards(block,[block])
			if cluster.size() >= CARD_MERGE_AMOUNT:
				return cluster
	return []

func merge_matched_cards(cluster):
	var card_id = cluster[0].card_info.id
	var new_level = int(cluster[0].level)+1
	var new_card = await card_controller.create_unit_from_id(card_id,new_level)
	new_card.context = cards.CONTEXT.DRAFT
	var cluster_pos = level.getGridPos(cluster[1])
	for block in cluster:
		block.merge_into_position(level.gridToWorldPos(cluster_pos))
		merging_cards.append(block)

	return {
		"block" : new_card,
		"pos" : cluster_pos
	}



func addNeighbourCards(block,cluster = []):

	var startPos = level.getGridPos(block)

	if startPos == null:
		return cluster

	for direction in directions:
		var neighbourPos = startPos + direction

		if level.hasPos(neighbourPos):
			var neighbour = level.getBlock(neighbourPos)
			if neighbour.object_type == core.OBJECT_TYPE.CARD and not cluster.has(neighbour):
				if neighbour.level == block.level and neighbour.card_info.id == block.card_info.id:
					cluster.append(neighbour)
					addNeighbourCards(neighbour,cluster)

	return cluster


func refill():
	var refillAction = false

	for x in level.gridWidth:

		var testPos = Vector2i(x,SPAWN_HEIGHT)

		if level.getBlock(testPos):
			var testBlock = level.getBlock(testPos)
			while (testPos.y < level.gridHeight):
				if testBlock.object_type == core.OBJECT_TYPE.BLOCK_PASSTROUGH:
					testPos = testPos + gravityVector
					if level.hasPos(testPos):
						testBlock = level.getBlock(testPos)
				else:
					break
			if testBlock.object_type == core.OBJECT_TYPE.EMPTY_SPACE:
				refillCounter.append(x)
				level.addToGrid(testPos,level.createBlock(),refillCounter.count(x))
				refillAction = true
	return refillAction


func solveGravity():

	var gravityAction = true

	while gravityAction:
		gravityAction = false

		for block in level.allBlocks():

			if block.object_type == core.OBJECT_TYPE.EMPTY_SPACE:

				var testPos = level.getGridPos(block)-gravityVector
				if level.hasPos(testPos):
					var testBlock = level.getBlock(testPos)
					while testBlock.object_type == core.OBJECT_TYPE.BLOCK_PASSTROUGH:
							testPos = testPos - gravityVector
							if level.hasPos(testPos):
								testBlock = level.getBlock(testPos)
							else:
								break
					if ![core.OBJECT_TYPE.BLOCK_PASSTROUGH,core.OBJECT_TYPE.EMPTY_SPACE].has(testBlock.object_type):
						level.switchBlocks(block,testBlock)
						gravityAction = true
