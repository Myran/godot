extends Node

const CARD_IMAGE_PREFIX: String = "card_image_"
@export_file("*.tscn") var card_scene_name: String
@export_dir var card_image_folder: String
var current_level: int = 1
var _rules: Dictionary


func get_card_image_name(card_id: String) -> String:
	return str(card_image_folder, CARD_IMAGE_PREFIX, debug.asset_variant, "_", card_id, ".png")


func setup() -> void:
	_rules = await data_source.get_rules_data()
	await data_source.activate_card_cache()


func get_card_from_pool() -> Node:  # Returns the card scene instance
	var new_card_id: String = await get_random_id_from_pool(current_level)
	var ret_unit: Node = await create_unit_from_id(new_card_id)
	return ret_unit


func get_random_id_from_pool(_level: int) -> String:
	var sel_level: int = select_recruited_unit_level(_level)
	var unit_id: String = await select_id_from_level(sel_level)
	return unit_id


func create_unit_from_id(id: String, unit_level: int = 1) -> Card:
	var card_info: Dictionary = await data_source.get_card_info(id, true)
	var card_scene: PackedScene = load(card_scene_name)
	var card_instanced: Node = card_scene.instantiate()
	card_instanced.init_card(card_info, unit_level)
	return card_instanced


func select_id_from_level(lvl: int) -> String:
	var sel_lvl: int = select_recruited_unit_level(lvl)
	var all_cards: Array = await data_source.get_all_cards(true)
	var cards_with_level: Array = []

	for card: Dictionary in all_cards:
		var level: String = card.upgrade_level
		if int(level) == sel_lvl:
			cards_with_level.append(card)

	var picked_card_id: String = (
		cards_with_level[rng.seeded_rng.next() % cards_with_level.size()].id
	)
	return picked_card_id


func select_recruited_unit_level(recruit_lvl: int) -> int:
	var roll: int = (randi() % 99) + 1
	var c_lvl_2_star_1: String = _rules.chance_lvl_2_star_1
	var c_lvl_2_star_2: String = _rules.chance_lvl_2_star_2
	var c_lvl_3_star_1: String = _rules.chance_lvl_3_star_1
	var c_lvl_3_star_2: String = _rules.chance_lvl_3_star_2
	var c_lvl_3_star_3: String = _rules.chance_lvl_3_star_3
	match recruit_lvl:
		1:
			return 1
		2:
			if roll <= int(c_lvl_2_star_1):
				return 1
			if roll <= int(c_lvl_2_star_2):
				return 2
		3:
			if roll <= int(c_lvl_3_star_1):
				return 1
			if roll <= int(c_lvl_3_star_2):
				return 2
			if roll <= int(c_lvl_3_star_3):
				return 3

	return 1  # Default fallback return
