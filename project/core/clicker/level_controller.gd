extends Control

@export var _level_factory: Resource
@export var _block_factory: block_factory

var current_level = null
var current_level_name = null
var block_grid = {}
var refill_distance


func _ready():
	debug.debug_event.connect(_on_debug_event)


func _on_debug_event(event, _data = null):
	match event:
		debug.DEBUG_EVENT_TYPE.EVENT_RESET_MATCH_LEVEL:
			setup_level(current_level_name)
		debug.DEBUG_EVENT_TYPE.EVENT_FORCE_LOAD_MATCH_LEVEL:
			var lvl_name = _data[0]
			setup_level(lvl_name)


func setup_level(level_name = "default"):
	var new_level = _level_factory.create_level(level_name)
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


func create_blocks_from_level():
	for tile_pos in current_level.get_used_cells():
		var block
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
		add_to_grid(tile_pos, block)
	current_level.clear()


func create_upgrade_block(upgrade_level):
	var upgrade_block = _block_factory.create_upgrade_block(upgrade_level)
	upgrade_block.block_context = Cards.CONTEXT.DRAFT
	return upgrade_block


func create_block():
	var random_block
	var rand = rng.seeded_rng.next() % LevelRules.FREQ_REFILL_ITEM
	if rand == 0:
		random_block = _block_factory.create_item_block()
	else:
		random_block = await card_controller.get_card_from_pool()
	random_block.block_context = Cards.CONTEXT.DRAFT
	return random_block


func add_to_grid(grid_pos, block, refill = 0):
	block_grid[grid_pos] = block
	current_level.add_child(block)
	var refill_pos = refill_distance * refill
	print("refill pos :", refill_pos)
	print("final position: ", current_level.map_to_local(grid_pos) - refill_pos)
	block.position = grid_to_world_pos(grid_pos) - refill_pos


func get_grid_pos(block):
	for grid_pos in block_grid.keys():
		if block_grid[grid_pos] == block:
			return grid_pos
	return null


func switch_blocks(block_a, block_b):
	var pos_a = get_grid_pos(block_a)
	var pos_b = get_grid_pos(block_b)
	block_grid[pos_a] = block_b
	block_grid[pos_b] = block_a


func get_block(grid_pos):
	return block_grid[grid_pos]


func has_pos(pos):
	return block_grid.has(pos)


func all_blocks():
	return block_grid.values()


func grid_to_world_pos(grid_pos):
	return current_level.map_to_local(grid_pos)


func move_blocks():
	var awaiter = SignalAwaiter.All.new()
	var b_moving = all_blocks()
	for block_iterator in b_moving:
		block_iterator.move_to_position(grid_to_world_pos(get_grid_pos(block_iterator)))
		awaiter.add(block_iterator.movement_done)
	await awaiter.finished


func remove_from_grid(block, destroy = true):
	var remove_pos = get_grid_pos(block)
	#kan om redan borttaget som inmergade objectet
	if remove_pos != null:
		var empty_space = _block_factory.create_empty_space()
		add_to_grid(remove_pos, empty_space)
	if destroy:
		if block.get_parent():
			block.get_parent().remove_child(block)
		block.queue_free()
