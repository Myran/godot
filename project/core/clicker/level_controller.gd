class_name LevelController extends Control

@export var _level_factory: Resource
@export var _block_factory: block_factory

var current_level: TileMapLayer
var current_level_name: String
var block_grid : Dictionary = {}
var refill_distance: Vector2


func _ready() -> void:
	debug.debug_event.connect(_on_debug_event)


func _on_debug_event(event: debug.DEBUG_EVENT_TYPE, _data: Array) -> void:
	match event:
		debug.DEBUG_EVENT_TYPE.EVENT_RESET_MATCH_LEVEL:
			setup_level(current_level_name)
		debug.DEBUG_EVENT_TYPE.EVENT_FORCE_LOAD_MATCH_LEVEL:
			var lvl_name: String = _data[0]
			setup_level(lvl_name)


func setup_level(level_name: String = "default") -> void:
	var new_level: TileMapLayer = _level_factory.create_level(level_name)
	if new_level == null:
		return
	if current_level:
		current_level.queue_free()
		current_level = null

	get_parent().add_child(new_level)
	current_level = new_level
	current_level_name = level_name
	refill_distance = Vector2(0, current_level.tile_set.tile_size.y)
	print("RefillDistance set to: ", refill_distance)
	create_blocks_from_level()


func create_blocks_from_level() -> void:
	for tile_pos : Vector2i in current_level.get_used_cells():
		var block: Block
		match current_level.get_cell_source_id(tile_pos):
			0:
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
				block = await create_block()
		block.block_context = Cards.CONTEXT.DRAFT
		#add_to_grid(tile_pos, block)
		core.action(core.DraftAddBlockEvent.new(block, tile_pos))
	current_level.clear()


func create_upgrade_block(upgrade_level: int) -> Block:
	var upgrade_block: Block = _block_factory.create_upgrade_block(upgrade_level)
	upgrade_block.block_context = Cards.CONTEXT.DRAFT
	return upgrade_block


func create_block() -> Block:
	var random_block: Block
	var rand: int = rng.seeded_rng.next() % LevelRules.FREQ_REFILL_ITEM
	if rand == 0:
		random_block = _block_factory.create_item_block()
	else:
		random_block = await card_controller.get_card_from_pool()
	random_block.block_context = Cards.CONTEXT.DRAFT
	return random_block


func add_to_grid(grid_pos: Vector2i, block: Block, refill: int = 0) -> void:
	block_grid[grid_pos] = block
	current_level.add_child(block)
	var refill_pos: Vector2 = refill_distance * refill
	# print("refill pos :", refill_pos)
	# print("final position: ", current_level.map_to_local(grid_pos) - refill_pos)
	block.position = grid_to_world_pos(grid_pos) - refill_pos


func get_grid_pos(block: Block) -> Vector2i:
	for grid_pos: Vector2i in block_grid.keys():
		if block_grid[grid_pos] == block:
			return grid_pos
	return Clicker.NO_POS


func switch_blocks(block_a: Block, block_b: Block) -> void:
	var pos_a: Vector2i = get_grid_pos(block_a)
	var pos_b: Vector2i = get_grid_pos(block_b)
	block_grid[pos_a] = block_b
	block_grid[pos_b] = block_a


func get_block(grid_pos: Vector2i) -> Block:
	return block_grid[grid_pos]


func has_pos(pos: Vector2i) -> bool:
	return block_grid.has(pos)


func all_blocks() -> Array[Block]:
	var block_array : Array[Block] = []
	block_array.assign(block_grid.values())
	return block_array


func grid_to_world_pos(grid_pos: Vector2i) -> Vector2:
	return current_level.map_to_local(grid_pos)


func move_blocks() -> void:
	var awaiter: SignalAwaiter = SignalAwaiter.All.new()
	var b_moving: Array = all_blocks()
	for block_iterator: Block in b_moving:
		block_iterator.move_to_position(grid_to_world_pos(get_grid_pos(block_iterator)))
		awaiter.add(block_iterator.movement_done)
	await awaiter.finished


func remove_from_grid(block: Block, destroy: bool = true) -> void:
	var remove_pos: Vector2i = get_grid_pos(block)
	#kan om redan borttaget som inmergade objectet
	if remove_pos != Clicker.NO_POS:
		var empty_space: Block = _block_factory.create_empty_space()
		add_to_grid(remove_pos, empty_space)
	if destroy:
		if block.get_parent():
			block.get_parent().remove_child(block)
		block.queue_free()
