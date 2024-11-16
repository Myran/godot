class_name block_factory extends Resource

@export var upgrade_blocks: Array
@export var locked_block_scene: PackedScene
@export var nospace_block_scene: PackedScene
@export var passtrough_block_scene: PackedScene
@export var item_block_scene: PackedScene
@export var empty_block_scene: PackedScene


func create_locked_block():
	var locked_block = locked_block_scene.instantiate()
	return locked_block


func create_item_block():
	var item_block = item_block_scene.instantiate()
	return item_block


func create_nospace_block():
	var nospace_block = nospace_block_scene.instantiate()
	return nospace_block


func create_passtrough_block():
	var pass_block = passtrough_block_scene.instantiate()
	return pass_block


func create_upgrade_block(upgrade_level):
	var upgrade_block = upgrade_blocks[upgrade_level - 1].instantiate()
	return upgrade_block


func create_empty_space():
	var empty_space = empty_block_scene.instantiate()
	return empty_space
