class_name block_factory extends Resource

@export var upgrade_blocks: Array[PackedScene]
@export var locked_block_scene: PackedScene
@export var nospace_block_scene: PackedScene
@export var passtrough_block_scene: PackedScene
@export var item_block_scene: PackedScene
@export var empty_block_scene: PackedScene


func create_locked_block() -> Block:
	var locked_block: Block = locked_block_scene.instantiate()
	return locked_block


func create_item_block() -> Block:
	var item_block: Block = item_block_scene.instantiate()
	return item_block


func create_nospace_block() -> Block:
	var nospace_block: Block = nospace_block_scene.instantiate()
	return nospace_block


func create_passtrough_block() -> Block:
	var pass_block: Block = passtrough_block_scene.instantiate()
	return pass_block


func create_upgrade_block(upgrade_level: int) -> Block:
	var upgrade_block: Block = upgrade_blocks[upgrade_level - 1].instantiate()
	return upgrade_block


func create_empty_space() -> Block:
	var empty_space: Block = empty_block_scene.instantiate()
	return empty_space