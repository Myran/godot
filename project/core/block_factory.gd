class_name block_factory extends Resource
const FREQ_ITEM = 5

@export var upgrade_blocks : Array # (Array, PackedScene)
#@export var block_types : Array  # (Array, PackedScene)
@export var locked_block_scene: PackedScene
@export var nospace_block_scene: PackedScene
@export var passtrough_block_scene: PackedScene
@export var item_block_scene: PackedScene
@export var empty_block_scene : PackedScene

func create_locked_block():
	var locked_block = locked_block_scene.instantiate()
	locked_block.object_type = core.OBJECT_TYPE.BLOCK_LOCKED
	locked_block.block_context = cards.CONTEXT.DRAFT
	return locked_block

func create_item_block():
	var locked_block = item_block_scene.instantiate()
	locked_block.object_type = core.OBJECT_TYPE.BLOCK_ITEM
	locked_block.block_context = cards.CONTEXT.DRAFT
	return locked_block

func create_nospace_block():
	var nospace_block = nospace_block_scene.instantiate()
	nospace_block.object_type = core.OBJECT_TYPE.BLOCK_NOSPACE
	nospace_block.block_context = cards.CONTEXT.DRAFT
	return nospace_block

func create_passtrough_block():
	var nospace_block = passtrough_block_scene.instantiate()
	nospace_block.object_type = core.OBJECT_TYPE.BLOCK_PASSTROUGH
	nospace_block.block_context = cards.CONTEXT.DRAFT
	return nospace_block

func create_upgrade_block(upgrade_level):
	var upgrade_block = upgrade_blocks[upgrade_level-1].instantiate()
	upgrade_block.object_type = core.OBJECT_TYPE.BLOCK_UPGRADE
	upgrade_block.block_context = cards.CONTEXT.DRAFT
	upgrade_block.level = upgrade_level
	return upgrade_block

func create_block():
	var random_block
	var rand = rng.seeded_rng.next() % FREQ_ITEM
	if rand == 0:
		random_block = create_item_block()
	else:
		random_block = await card_controller.get_card_from_pool()
		random_block.block_context = cards.CONTEXT.DRAFT
	return random_block

func create_empty_space():
	#var empty_space = block_types[0].instantiate()
	var empty_space = empty_block_scene.instantiate()
	empty_space.object_type = core.OBJECT_TYPE.EMPTY_SPACE
	return empty_space
