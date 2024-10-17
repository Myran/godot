extends Control


@export var _level_factory: Resource
var current_level = null
var current_level_name = null

signal cards_done_moving
var blocks_moving
var blockGrid = {}
var refillDistance
const gridWidth = 5 # max five cards in row
const gridHeight = 5
const freq_item = 5
const cardType = 5
@export var _block_factory: block_factory

func _ready():
	core.connect("event", Callable(self, "_on_core_event"))
	debug.connect(debug.SIGNAL_DEBUG, Callable(self, "_on_debug_event"))
	#if OS.has_feature("editor"):
		#call_deferred("setup_level")
		#setup_level()
func _on_debug_event(event,_data = null):
	match event:
		debug.DEBUG_EVENT_TYPE.EVENT_RESET_MATCH_LEVEL:
			setup_level(current_level_name)
		debug.DEBUG_EVENT_TYPE.EVENT_FORCE_LOAD_MATCH_LEVEL:
			var lvl_name = _data[0]
			setup_level(lvl_name)


func _on_core_event(_event,_data):
	if _event == core.EVENT_TYPE.CARD_FINISHED_MOVING:
		var card = _data
		if blocks_moving == null : return
		blocks_moving.erase(card)
		if blocks_moving.size() == 0:
			emit_signal("cards_done_moving")


func setup_level(level_name  = "default"):
	var new_level = _level_factory.create_level(level_name)
	if new_level == null : return
	if current_level:
		current_level.queue_free()
		current_level = null

	get_parent().add_child(new_level)
	current_level = new_level
	current_level_name = level_name
	refillDistance = Vector2(0,current_level.tile_set.tile_size.y)
	print("RefillDistance set to: ",refillDistance)
	create_blocks_from_level()



func create_blocks_from_level():
	for tilePos in current_level.get_used_cells():
		var block
		match current_level.get_cell_source_id((tilePos)):
			0:
			#block = upgradeblock
				block = _block_factory.create_locked_block()
			1:
				block = _block_factory.create_upgrade_block(1)
			2:
				block = _block_factory.create_upgrade_block(2)
			3:
				block = _block_factory.create_upgrade_block(3)
			4:
				block = _block_factory.create_nospace_block()
			5:
				block = _block_factory.create_passtrough_block()
			_:
				block = await _block_factory.createBlock()
		addToGrid(tilePos,block)
	current_level.clear()


func create_upgrade_block(upgrade_level):
	return _block_factory.create_upgrade_block(upgrade_level)


func createBlock():
	return await _block_factory.createBlock()

func addToGrid(gridPos,block,refill = 0):

	blockGrid[gridPos] = block
	current_level.add_child(block)
	var refillPos = refillDistance * refill
	print("refill pos :",refillPos)
	print("final position: ",(current_level.map_to_local(gridPos) -refillPos))
	#block.position = (current_level.map_to_local(gridPos) -refillPos)
	block.position = gridToWorldPos(gridPos)-refillPos
	#block.position=block.to_global(block.position)
	var magic_number = 3.3 # nåt med skalan är fel
	#block.position = block.position * magic_number

func getGridPos(block):

	for gridPos in blockGrid.keys():
		if blockGrid[gridPos] == block:
			return gridPos
	#return null

func switchBlocks(blockA,blockB):

	var posA = getGridPos(blockA)
	var posB = getGridPos(blockB)
	blockGrid[posA] = blockB
	blockGrid[posB] = blockA

func getBlock(gridPos):
	return blockGrid[gridPos]

func hasPos(pos):
	return blockGrid.has(pos)

func allBlocks():
	return blockGrid.values()

func gridToWorldPos(gridPos):
	return current_level.map_to_local(gridPos)

func moveBlocks():
	blocks_moving = allBlocks().duplicate()
	for blockIterator in blocks_moving:
		blockIterator.moveToPosition(gridToWorldPos(getGridPos(blockIterator)))
	await self.cards_done_moving

func removeFromGrid(block,destroy = true):
	var remove_pos = getGridPos(block)
	var empty_space = _block_factory.create_empty_space()
	addToGrid(remove_pos,empty_space)
	if destroy:
		if block.get_parent():
			block.get_parent().remove_child(block)
		block.queue_free()
