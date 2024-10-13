extends TileMap

signal cards_done_moving
var blocks_moving
var blockGrid = {}
var refillDistance
const gridWidth = 5 # max five cards in row
const gridHeight = 5
const freq_item = 5
var tap_handler
const cardType = 5
@export var _block_factory: Resource

#var grid_pos = load("res://cardtest/grid_pos.tscn")
func set_tap_handler(_tap_handler):
	refillDistance = Vector2(0,tile_set.tile_size.y)
	tap_handler = _tap_handler
	#position = -(get_used_rect().size*cell_size) /2
	core.connect("event", Callable(self, "_on_core_event"))
	for tilePos in get_used_cells(0):
		#var block = blockTypes[get_cellv(tilePos)].instance()
		var block
		match get_cell_source_id(0,tilePos):
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
				block = _block_factory.createBlock()
		addToGrid(tilePos,block)
	clear()


func create_upgrade_block(upgrade_level):
	return _block_factory.create_upgrade_block(upgrade_level)


func createBlock():
	return _block_factory.createBlock()

func addToGrid(gridPos,block,refill = 0):

	blockGrid[gridPos] = block
	add_child(block)
	var refillPos = refillDistance * refill
	print("refill pos :",refillPos)
	block.position = map_to_local(gridPos) -refillPos

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

func _on_core_event(_event,_data):
	if _event == core.EVENT_TYPE.CARD_FINISHED_MOVING:
		var card = _data
		blocks_moving.erase(card)
		if blocks_moving.size() == 0:
			emit_signal("cards_done_moving")

func gridToWorldPos(gridPos):
	return map_to_local(gridPos)

func moveBlocks():
	blocks_moving = allBlocks().duplicate()
	for blockIterator in blocks_moving:
		blockIterator.moveToPosition(map_to_local(getGridPos(blockIterator)))
	await self.cards_done_moving

func removeFromGrid(block,destroy = true):
	var remove_pos = getGridPos(block)
	var empty_space = _block_factory.create_empty_space()
	addToGrid(remove_pos,empty_space)
	if destroy:
		if block.get_parent():
			block.get_parent().remove_child(block)
		block.queue_free()
