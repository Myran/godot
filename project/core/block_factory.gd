extends Resource
class_name block_factory
const freq_item = 5

@export var upgrade_blocks : Array # (Array, PackedScene)
@export var blockTypes : Array  # (Array, PackedScene)
@export var locked_block_scene: PackedScene
@export var nospace_block_scene: PackedScene
@export var passtrough_block_scene: PackedScene
@export var item_block_scene: PackedScene

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

func createBlock():
	var randomBlock
	var rand = rng.seeded_rng.next() % freq_item
	if rand == 0:
		randomBlock = create_item_block()
	else:
		randomBlock = await card_controller.get_card_from_pool()
		randomBlock.block_context = cards.CONTEXT.DRAFT
	return randomBlock

func create_empty_space():
	var empty_space = blockTypes[0].instantiate()
	empty_space.object_type = core.OBJECT_TYPE.EMPTY_SPACE
	return empty_space
