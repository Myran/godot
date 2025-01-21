class_name block_factory extends Resource

@export var upgrade_blocks: Array[PackedScene]
@export var locked_block_scene: PackedScene
@export var nospace_block_scene: PackedScene
@export var passtrough_block_scene: PackedScene
@export var item_block_scene: PackedScene
@export var empty_block_scene: PackedScene

func create_locked_block() -> Node:
	var locked_block: Node = locked_block_scene.instantiate()
	return locked_block

func create_item_block() -> Node:
	var item_block: Node = item_block_scene.instantiate()
	return item_block

func create_nospace_block() -> Node:
	var nospace_block: Node = nospace_block_scene.instantiate()
	return nospace_block

func create_passtrough_block() -> Node:
	var pass_block: Node = passtrough_block_scene.instantiate()
	return pass_block

func create_upgrade_block(upgrade_level: int) -> Node:
	var upgrade_block: Node = upgrade_blocks[upgrade_level - 1].instantiate()
	return upgrade_block

func create_empty_space() -> Node:
	var empty_space: Node = empty_block_scene.instantiate()
	return empty_space
