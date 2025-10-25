class_name CardController
extends RefCounted


static func setup() -> void:
	await data_source.activate_card_cache()
	await data_source.activate_rules_cache()


static func get_card_from_pool(level: int = 1) -> Card:  # Returns the card scene instance
	var new_card_id: String = await get_random_id_from_pool(level)
	var ret_unit: Card = await create_unit_from_id(new_card_id)
	return ret_unit


static func get_specific_card_block(card_id: String, card_level: int) -> Card:
	"""Create a card with specific ID and level for gamestate restoration"""
	var card: Card = await create_unit_from_id(card_id, card_level)
	return card


static func get_random_id_from_pool(_level: int) -> String:
	var sel_level: int = select_recruited_unit_level(_level)
	var unit_id: String = await select_id_from_level(sel_level)
	return unit_id


static func create_unit_from_id(id: String, unit_level: int = 1) -> Card:
	# ASSERT: Input parameters must be valid
	assert(id != null and id != "", "create_unit_from_id: Invalid card ID provided")
	assert(unit_level > 0, "create_unit_from_id: Invalid unit level: " + str(unit_level))

	Log.debug(
		"Starting card creation",
		{"card_id": id, "level": unit_level},
		[Log.TAG_DEBUG, "card_creation"]
	)

	# ASSERT: Data source must be available
	assert(data_source != null, "create_unit_from_id: Data source is null")
	assert(data_source.cards != null, "create_unit_from_id: Data source cards is null")

	var card_info: Dictionary = await data_source.cards.get_by_id(id, true)
	# ASSERT: Card info must be found
	assert(not card_info.is_empty(), "create_unit_from_id: No card info found for ID: " + id)
	assert(card_info.has("id"), "create_unit_from_id: Card info missing 'id' field for ID: " + id)

	Log.debug(
		"Card info retrieved",
		{"card_id": id, "has_info": !card_info.is_empty()},
		[Log.TAG_DEBUG, "card_creation"]
	)

	var card_scene: PackedScene = load(GameConstants.CardSystem.CARD_SCENE_NAME)
	# ASSERT: Card scene must load successfully
	assert(
		card_scene != null,
		(
			"create_unit_from_id: Failed to load card scene: "
			+ str(GameConstants.CardSystem.CARD_SCENE_NAME)
		)
	)
	assert(
		card_scene is PackedScene,
		(
			"create_unit_from_id: Loaded scene is not PackedScene: "
			+ str(GameConstants.CardSystem.CARD_SCENE_NAME)
		)
	)

	Log.debug(
		"Card scene loaded",
		{"scene_name": GameConstants.CardSystem.CARD_SCENE_NAME, "scene_valid": card_scene != null},
		[Log.TAG_DEBUG, "card_creation"]
	)

	var card_instanced: Card = card_scene.instantiate() as Card
	# ASSERT: Card must instantiate correctly
	assert(
		card_instanced != null,
		"create_unit_from_id: Failed to instantiate card scene for ID: " + id
	)
	assert(
		is_instance_valid(card_instanced),
		"create_unit_from_id: Card instance is invalid for ID: " + id
	)
	assert(
		card_instanced is Card,
		"create_unit_from_id: Instantiated object is not Card type for ID: " + id
	)

	Log.debug(
		"Card scene instantiated",
		{"card_id": id, "instance_valid": card_instanced != null},
		[Log.TAG_DEBUG, "card_creation"]
	)

	# ASSERT: Card initialization must succeed
	assert(
		card_instanced.has_method("init_card"),
		"create_unit_from_id: Card missing init_card method for ID: " + id
	)
	card_instanced.init_card(card_info, unit_level)

	# ASSERT: Final validation - card must be properly initialized
	assert(
		is_instance_valid(card_instanced),
		"create_unit_from_id: Card became invalid after initialization for ID: " + id
	)
	assert(
		card_instanced.card_info.has("id") and card_instanced.card_info.id != "",
		"create_unit_from_id: Card has empty ID after initialization"
	)

	Log.debug("Card initialization complete", {"card_id": id}, [Log.TAG_DEBUG, "card_creation"])
	return card_instanced


static func select_id_from_level(lvl: int) -> String:
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


static func select_recruited_unit_level(recruit_lvl: int) -> int:
	var roll: int = (rng.seeded_rng.next() % 99) + 1

	# Get drop rate rules from cache (no await needed)
	var rules: Dictionary = data_source.rules.get_cached_rules()

	var c_lvl_2_star_1: String = "50"
	var c_lvl_2_star_2: String = "100"
	var c_lvl_3_star_1: String = "30"
	var c_lvl_3_star_2: String = "70"
	var c_lvl_3_star_3: String = "100"

	if rules.has("chance_lvl_2_star_1"):
		c_lvl_2_star_1 = rules.chance_lvl_2_star_1
	if rules.has("chance_lvl_2_star_2"):
		c_lvl_2_star_2 = rules.chance_lvl_2_star_2
	if rules.has("chance_lvl_3_star_1"):
		c_lvl_3_star_1 = rules.chance_lvl_3_star_1
	if rules.has("chance_lvl_3_star_2"):
		c_lvl_3_star_2 = rules.chance_lvl_3_star_2
	if rules.has("chance_lvl_3_star_3"):
		c_lvl_3_star_3 = rules.chance_lvl_3_star_3
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
