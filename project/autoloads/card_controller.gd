extends Node

const CARD_IMAGE_PREFIX: String = "card_image_"
@export_file("*.tscn") var card_scene_name: String
@export_dir var card_image_folder: String
var current_level: int = 1
var _rules: Dictionary = {}


func get_card_image_name(card_id: String) -> String:
	var asset_variant_value: int = 0  # Default value

	if (
		DebugManager
		and DebugManager.has_method("get")
		and DebugManager.get("asset_variant") != null
	):
		asset_variant_value = DebugManager.asset_variant

	return str(card_image_folder, CARD_IMAGE_PREFIX, asset_variant_value, "_", card_id, ".png")


func setup() -> void:
	_rules = await data_source.rules.get_rules()
	await data_source.activate_card_cache()


func get_card_from_pool() -> Card:  # Returns the card scene instance
	var new_card_id: String = await get_random_id_from_pool(current_level)
	var ret_unit: Card = await create_unit_from_id(new_card_id)
	return ret_unit


func get_specific_card_block(card_id: String, card_level: int) -> Card:
	"""Create a card with specific ID and level for gamestate restoration"""
	var card: Card = await create_unit_from_id(card_id, card_level)
	return card


func get_random_id_from_pool(_level: int) -> String:
	var sel_level: int = select_recruited_unit_level(_level)
	var unit_id: String = await select_id_from_level(sel_level)
	return unit_id


func create_unit_from_id(id: String, unit_level: int = 1) -> Card:
	Log.debug("Starting card creation", {"card_id": id, "level": unit_level}, [Log.TAG_DEBUG, "card_creation"])
	
	var card_info: Dictionary = await data_source.cards.get_by_id(id, true)
	Log.debug("Card info retrieved", {"card_id": id, "has_info": !card_info.is_empty()}, [Log.TAG_DEBUG, "card_creation"])
	
	var card_scene: PackedScene = load(card_scene_name)
	Log.debug("Card scene loaded", {"scene_name": card_scene_name, "scene_valid": card_scene != null}, [Log.TAG_DEBUG, "card_creation"])
	
	var card_instanced: Card = card_scene.instantiate() as Card
	Log.debug("Card scene instantiated", {"card_id": id, "instance_valid": card_instanced != null}, [Log.TAG_DEBUG, "card_creation"])
	
	card_instanced.init_card(card_info, unit_level)
	Log.debug("Card initialization complete", {"card_id": id}, [Log.TAG_DEBUG, "card_creation"])
	
	return card_instanced


func select_id_from_level(lvl: int) -> String:
	var sel_lvl: int = select_recruited_unit_level(lvl)
	var all_cards: Array[Dictionary] = await data_source.cards.get_all(true)
	var cards_with_level: Array[Dictionary] = []

	for card: Dictionary in all_cards:
		if card.has("upgrade_level"):
			var level: String = card.upgrade_level
			if int(level) == sel_lvl:
				cards_with_level.append(card)

	if cards_with_level.size() == 0:
		Log.warning(
			"No cards found for level %d, using first card as fallback" % sel_lvl, {}, ["debug"]
		)
		if all_cards.size() > 0 and all_cards[0].has("id"):
			return all_cards[0].id
		return ""

	var picked_card_id: String = ""
	if cards_with_level.size() > 0:
		var selected_card: Dictionary = cards_with_level[
			rng.seeded_rng.next() % cards_with_level.size()
		]
		if selected_card.has("id"):
			picked_card_id = selected_card.id

	return picked_card_id


func select_recruited_unit_level(recruit_lvl: int) -> int:
	var roll: int = (rng.seeded_rng.next() % 99) + 1

	var c_lvl_2_star_1: String = "50"
	var c_lvl_2_star_2: String = "100"
	var c_lvl_3_star_1: String = "30"
	var c_lvl_3_star_2: String = "70"
	var c_lvl_3_star_3: String = "100"

	if _rules.has("chance_lvl_2_star_1"):
		c_lvl_2_star_1 = _rules.chance_lvl_2_star_1
	if _rules.has("chance_lvl_2_star_2"):
		c_lvl_2_star_2 = _rules.chance_lvl_2_star_2
	if _rules.has("chance_lvl_3_star_1"):
		c_lvl_3_star_1 = _rules.chance_lvl_3_star_1
	if _rules.has("chance_lvl_3_star_2"):
		c_lvl_3_star_2 = _rules.chance_lvl_3_star_2
	if _rules.has("chance_lvl_3_star_3"):
		c_lvl_3_star_3 = _rules.chance_lvl_3_star_3
	match recruit_lvl:
		GameConstants.CardSystem.DEFAULT_LEVEL:
			return GameConstants.CardSystem.DEFAULT_LEVEL
		GameConstants.CardSystem.LEVEL_TWO:
			if roll <= int(c_lvl_2_star_1):
				return GameConstants.CardSystem.DEFAULT_LEVEL
			if roll <= int(c_lvl_2_star_2):
				return GameConstants.CardSystem.LEVEL_TWO
		GameConstants.CardSystem.LEVEL_THREE:
			if roll <= int(c_lvl_3_star_1):
				return GameConstants.CardSystem.DEFAULT_LEVEL
			if roll <= int(c_lvl_3_star_2):
				return GameConstants.CardSystem.LEVEL_TWO
			if roll <= int(c_lvl_3_star_3):
				return GameConstants.CardSystem.LEVEL_THREE

	return GameConstants.CardSystem.DEFAULT_LEVEL  # Default fallback return
