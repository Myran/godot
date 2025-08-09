class_name LevelController extends Control

@export var _level_factory: LevelFactory
@export var _block_factory: block_factory

var current_level: TileMapLayer
var current_level_name: String
var block_grid: Dictionary[Vector2i, Block] = {}
var refill_distance: Vector2


func _ready() -> void:
	Log.debug("Level controller initializing", {}, [Log.TAG_INITIALIZATION, Log.TAG_LEVEL])
	DebugManager.debug_event.connect(_on_debug_event)


func _on_debug_event(event: DebugManager.DebugEventType, _data: Array) -> void:
	match event:
		DebugManager.DebugEventType.EVENT_RESET_MATCH_LEVEL:
			Log.debug(
				"Debug event: Resetting current level",
				{"level": current_level_name},
				[Log.TAG_LEVEL, Log.TAG_DEBUG]
			)
			setup_level(current_level_name)
		DebugManager.DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL:
			var lvl_name: String = _data[0]
			Log.debug(
				"Debug event: Force loading level",
				{"level": lvl_name},
				[Log.TAG_LEVEL, Log.TAG_DEBUG]
			)
			setup_level(lvl_name)


func setup_level(level_name: String = "default") -> void:
	Log.info(
		"Setting up level", {"level_name": level_name}, [Log.TAG_LEVEL, Log.TAG_INITIALIZATION]
	)
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
	Log.debug(
		"RefillDistance set for level",
		{"distance": refill_distance, "level": level_name},
		[Log.TAG_CLICKER, Log.TAG_GAME_STATE]
	)
	create_blocks_from_level()


func create_blocks_from_level() -> void:
	Log.debug(
		"Creating blocks from level layout (sequential execution for deterministic RNG)",
		{"tile_count": current_level.get_used_cells().size()},
		[Log.TAG_LEVEL, Log.TAG_INITIALIZATION]
	)

	var tile_positions: Array[Vector2i] = current_level.get_used_cells()

	for i: int in range(tile_positions.size()):
		var tile_pos: Vector2i = tile_positions[i]
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
				# CRITICAL: Sequential execution ensures each await completes
				block = await create_block()

		block.block_context = Cards.CONTEXT.DRAFT
		core.action(core.DraftAddBlockEvent.new(block, tile_pos))

	current_level.clear()


func create_upgrade_block(upgrade_level: int) -> Block:
	Log.debug("Creating upgrade block", {"level": upgrade_level}, [Log.TAG_LEVEL, Log.TAG_CARD])
	var upgrade_block: Block = _block_factory.create_upgrade_block(upgrade_level)
	upgrade_block.block_context = Cards.CONTEXT.DRAFT
	return upgrade_block


func create_block() -> Block:
	Log.debug("Creating random block", {}, [Log.TAG_LEVEL, Log.TAG_CARD])
	var random_block: Block
	var rand: int = rng.seeded_rng.next() % LevelRules.FREQ_REFILL_ITEM
	if rand == 0:
		Log.debug("Created item block", {}, [Log.TAG_LEVEL, Log.TAG_ITEM])
		random_block = _block_factory.create_item_block()
	else:
		Log.debug("Getting card from pool", {}, [Log.TAG_LEVEL, Log.TAG_CARD])
		random_block = await card_controller.get_card_from_pool()
	random_block.block_context = Cards.CONTEXT.DRAFT
	return random_block


func add_to_grid(grid_pos: Vector2i, block: Block, refill: int = 0) -> void:
	Log.debug(
		"Adding block to grid",
		{"grid_pos": grid_pos, "block_type": block.object_type, "refill": refill},
		[Log.TAG_LEVEL, Log.TAG_GRID]
	)
	block_grid[grid_pos] = block
	current_level.add_child(block)
	var refill_pos: Vector2 = refill_distance * refill
	block.position = grid_to_world_pos(grid_pos) - refill_pos


func get_grid_pos(block: Block) -> Vector2i:
	for grid_pos: Vector2i in DictUtils.keys_sorted(block_grid):
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
	var block_array: Array[Block] = []
	block_array.assign(block_grid.values())
	return block_array


func grid_to_world_pos(grid_pos: Vector2i) -> Vector2:
	return current_level.map_to_local(grid_pos)


func move_blocks() -> void:
	Log.debug(
		"Moving blocks to positions",
		{"block_count": block_grid.size()},
		[Log.TAG_LEVEL, Log.TAG_GRID, Log.TAG_UI_ANIMATION]
	)
	var awaiter: SignalAwaiter = SignalAwaiter.All.new()
	var b_moving: Array = all_blocks()

	for i: int in range(b_moving.size()):
		var block_iterator: Block = b_moving[i]
		var current_pos: Vector2i = get_grid_pos(block_iterator)
		var target_pos: Vector2i = grid_to_world_pos(current_pos)

		block_iterator.move_to_position(target_pos)
		awaiter.add(block_iterator.movement_done)

	await awaiter.finished

	Log.debug("Block movement complete", {}, [Log.TAG_LEVEL, Log.TAG_GRID, Log.TAG_UI_ANIMATION])


func remove_from_grid(block: Block, destroy: bool = true) -> void:
	Log.debug(
		"Removing block from grid",
		{"block_type": block.object_type, "destroy": destroy},
		[Log.TAG_LEVEL, Log.TAG_GRID]
	)
	var remove_pos: Vector2i = get_grid_pos(block)
	if remove_pos != Clicker.NO_POS:
		var empty_space: Block = _block_factory.create_empty_space()
		add_to_grid(remove_pos, empty_space)
	if destroy:
		if block.get_parent():
			block.get_parent().remove_child(block)
		block.block_kill()
