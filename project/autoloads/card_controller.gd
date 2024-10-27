extends Node
const CARD_IMAGE_PREFIX = "card_image_"
@export_file("*.tscn") var card_scene_name : String
@export_dir var card_image_folder : String


var current_level = 1
var current_pool = ["card_1","card_2","card_3"]
var rules

func get_card_image_name(card_id):
	return str(card_image_folder,CARD_IMAGE_PREFIX,debug.asset_variant,"_",card_id,".png")
func setup():
	rules = await data_source.get_rules_data()
	await data_source.activate_card_cache()

func get_card_from_pool():
	var new_card_id = await get_random_id_from_pool(current_level)
	var ret_unit = await create_unit_from_id(new_card_id)
	return ret_unit

func get_random_id_from_pool(_level):
	var sel_level = select_recruited_unit_level(_level)
	var unit_id = await select_id_from_level(sel_level)
	return unit_id

func create_unit_from_id(id,_unit_level = 1):
	var card_info = await data_source.get_card_info(id,true) # true in gameone
	var card_scene = load(card_scene_name)
	var card_instanced = card_scene.instantiate()
	card_instanced.init_card(card_info,_unit_level)
	return card_instanced

func select_id_from_level(lvl):
	var sel_lvl = select_recruited_unit_level(lvl)
	var all_cards = await data_source.get_all_cards(true) #gameone two
	var cards_with_level = []
	for card in all_cards:
		if int(card.upgrade_level) == sel_lvl:
			cards_with_level.append(card)

	var picked_card_id = cards_with_level[rng.seeded_rng.next() % cards_with_level.size()].id
	return picked_card_id


func select_recruited_unit_level(recruit_lvl):
	var roll = (randi() % 99) +1
	match recruit_lvl:
		1: return 1
		2:
			if roll <= int(rules.chance_lvl_2_star_1): return 1
			if roll <= int(rules.chance_lvl_2_star_2): return 2
		3:
			if roll <= int(rules.chance_lvl_3_star_1): return 1
			if roll <= int(rules.chance_lvl_3_star_2): return 2
			if roll <= int(rules.chance_lvl_3_star_3): return 3
