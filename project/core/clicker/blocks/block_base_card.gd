class_name Card extends Block

const CARD_IMAGE_PREFIX: String = "card_image_"
@export_dir var card_image_folder: String
@export var base: SmallBase
@export var shield: Sprite2D
@export var level: int = 1
@export var unit_info: UnitData = null
@export var card_info: Dictionary = {}  # CardInfo data structure
@export var card_name: String = ""


func show_shield() -> void:
	shield.show()


func hide_shield() -> void:
	shield.hide()


func init_card(_card_info: Dictionary, _card_level: int = 1) -> void:
	card_info = _card_info
	level = _card_level
	var card_name_value: String = _card_info.get("card_name", "Unknown")
	card_name = card_name_value

	unit_info = UnitData.new()
	unit_info.init_with_info(_card_info)
	unit_info.upgrade_unit_to_level(_card_level)

	var id: String = ""
	if _card_info.has("id"):
		var id_value: String = _card_info.id
		id = id_value
	else:
		Log.warning("Card info missing 'id' field", {"card_info": _card_info}, ["debug"])

	var img_string: String = card_controller.get_card_image_name(id)
	var upgrade_level: String = unit_info.card_info.upgrade_level
	base.set_card_img(img_string)

	var upgrade_level_int: int = 1
	if unit_info.card_info.has("upgrade_level"):
		var upgrade_level_str: String = unit_info.card_info.upgrade_level
		upgrade_level_int = upgrade_level_str.to_int()

	base.set_upgrade_level(upgrade_level_int)
	base.set_card_health(unit_info.current_health)
	base.set_card_attack(unit_info.current_attack)
	base.set_card_level(unit_info.level)


func init_battle_reenactment(source_card: Card) -> void:
	level = source_card.level
	card_name = source_card.card_name

	var card_id: String = source_card.unit_info.card_info.id

	var img_string: String = card_controller.get_card_image_name(card_id)
	base.set_card_img(img_string)
	base.set_card_attack(source_card.unit_info.current_attack)
	base.set_card_health(source_card.unit_info.current_health)
	base.set_card_level(source_card.level)


func get_card_name() -> String:
	return card_name


func refresh_ui_from_unit_data() -> void:
	"""Updates card UI to reflect current unit_info stats"""
	Log.debug(
		"UI REFRESH - Updating card display stats",
		{
			"card_id": card_info.get("id", "unknown"),
			"level": level,
			"attack_displayed": unit_info.current_attack,
			"health_displayed": unit_info.current_health,
			"effects_count": unit_info.effects_perm.size(),
			"context": "refresh_ui_from_unit_data"
		},
		[Log.TAG_UI, Log.TAG_CARD, Log.TAG_STAT, "ui_refresh"]
	)
	base.set_card_attack(unit_info.current_attack)
	base.set_card_health(unit_info.current_health)


func serialize_to_dict() -> Dictionary:
	"""
	Card block specialized serialization.
	Captures card-specific state including card_id, level, and unit checksum.
	"""
	var base_data: Dictionary = super.serialize_to_dict()

	# Add Card-specific data
	base_data["card_id"] = card_info.get("id", "") if card_info else ""
	base_data["level"] = level
	base_data["card_name"] = card_name
	base_data["unit_checksum"] = (unit_info.get_state_checksum() if unit_info else "")

	# Include card_info for complete restoration if needed
	if not card_info.is_empty():
		base_data["card_info"] = card_info

	# CRITICAL: Serialize complete UnitData state for effects and abilities
	if unit_info:
		base_data["unit_state"] = _serialize_unit_data_state(unit_info)

	Log.debug(
		"Card serialized",
		{
			"object_type": base_data["object_type"],
			"card_id": base_data["card_id"],
			"level": level,
			"checksum": base_data["unit_checksum"]
		},
		["serialization", "card"]
	)

	return base_data


static func deserialize_from_dict(data: Dictionary) -> Block:
	"""
	Card block specialized deserialization.
	Restores card-specific state from serialized data.
	"""
	var card_id: String = data.get("card_id", "")
	var card_level: int = data.get("level", 1)

	if card_id.is_empty():
		Log.error(
			"Cannot deserialize Card - missing card_id", {"data": data}, ["serialization", "error"]
		)
		return null

	# Create card using existing card creation system
	var card: Card = await _create_card_from_id(card_id, card_level)
	if not card:
		Log.error(
			"Failed to create Card from ID during deserialization",
			{"card_id": card_id, "level": card_level},
			["serialization", "error"]
		)
		return null

	# Restore basic block properties
	var object_type_value: int = data.get("object_type", 1)
	card.object_type = object_type_value as core.ObjectType

	var block_context_value: int = data.get("block_context", 0)
	if block_context_value > 0:
		card.block_context = block_context_value as Cards.CONTEXT

	# CRITICAL: Restore complete UnitData state including effects and abilities
	var unit_state: Dictionary = data.get("unit_state", {})
	if not unit_state.is_empty() and card.unit_info:
		var restoration_success: bool = _restore_unit_data_state(card.unit_info, unit_state)
		if restoration_success:
			Log.info(
				"Card UnitData state restored with effects and abilities",
				{
					"card_id": card_id,
					"effects_perm_count": unit_state.get("effects_perm", []).size(),
					"effects_temp_count": unit_state.get("effects_temp", []).size(),
					"abilities_count": unit_state.get("abilities", []).size()
				},
				["serialization", "unit_data", "restored"]
			)
		else:
			Log.warning(
				"Partial UnitData restoration - some effects/abilities may be lost",
				{"card_id": card_id},
				["serialization", "unit_data", "partial_restore"]
			)

	# Validate unit checksum if available for data integrity
	var expected_checksum: String = data.get("unit_checksum", "")
	if not expected_checksum.is_empty() and card.unit_info:
		var actual_checksum: String = card.unit_info.get_state_checksum()
		if actual_checksum != expected_checksum:
			Log.warning(
				"Card checksum mismatch during deserialization",
				{
					"card_id": card_id,
					"expected": expected_checksum,
					"actual": actual_checksum,
					"unit_state_restored": not unit_state.is_empty()
				},
				["serialization", "checksum", "warning"]
			)

	Log.debug(
		"Card deserialized",
		{
			"object_type": card.object_type,
			"card_id": card_id,
			"level": card_level,
			"checksum_validated": not expected_checksum.is_empty()
		},
		["serialization", "card"]
	)

	return card


static func _create_card_from_id(card_id: String, card_level: int) -> Card:
	"""
	Create a card using the existing card controller system.
	This maintains compatibility with existing card creation logic.
	"""
	# Fail-fast: Access card_controller autoload singleton directly
	return await card_controller.create_unit_from_id(card_id, card_level)


static func _serialize_unit_data_state(unit_data: UnitData) -> Dictionary:
	"""
	Serialize complete UnitData state including effects and abilities.
	This ensures cards with runtime modifications are properly preserved.
	"""
	var unit_state: Dictionary = {
		# Core stats (might be modified by effects)
		"current_health": unit_data.current_health,
		"current_attack": unit_data.current_attack,
		"max_health": unit_data.max_health,
		"max_attack": unit_data.max_attack,
		"base_health": unit_data.base_health,
		"base_attack": unit_data.base_attack,
		"level": unit_data.level
	}

	# Serialize permanent effects
	var effects_perm_data: Array[Dictionary] = []
	for effect in unit_data.effects_perm:
		if effect and effect.has_method("serialize_to_dict"):
			effects_perm_data.append(effect.serialize_to_dict())
		elif effect:
			# Fallback for effects without serialization
			effects_perm_data.append(
				{"type": effect.get_class(), "data": "serialization_not_supported"}
			)
	unit_state["effects_perm"] = effects_perm_data

	# Serialize temporary effects (for in-battle saves)
	var effects_temp_data: Array[Dictionary] = []
	for effect in unit_data.effects_temp:
		if effect and effect.has_method("serialize_to_dict"):
			effects_temp_data.append(effect.serialize_to_dict())
		elif effect:
			# Fallback for effects without serialization
			effects_temp_data.append(
				{"type": effect.get_class(), "data": "serialization_not_supported"}
			)
	unit_state["effects_temp"] = effects_temp_data

	# Serialize abilities
	var abilities_data: Array[Dictionary] = []
	for ability in unit_data.abilities:
		if ability and ability.has_method("serialize_to_dict"):
			abilities_data.append(ability.serialize_to_dict())
		elif ability:
			# Fallback using ability string parsing
			abilities_data.append(
				{"type": ability.get_class(), "data": "requires_ability_serialization"}
			)
	unit_state["abilities"] = abilities_data

	# Include battle reference data if available
	if unit_data.battle_original_reference:
		unit_state["has_battle_reference"] = true
		unit_state["battle_reference_checksum"] = (
			unit_data.battle_original_reference.get_state_checksum()
		)
	else:
		unit_state["has_battle_reference"] = false

	Log.debug(
		"UnitData state serialized",
		{
			"effects_perm_count": effects_perm_data.size(),
			"effects_temp_count": effects_temp_data.size(),
			"abilities_count": abilities_data.size(),
			"stats_modified":
			(
				unit_data.current_health != unit_data.base_health
				or unit_data.current_attack != unit_data.base_attack
			)
		},
		["serialization", "unit_data", "effects_abilities"]
	)

	return unit_state


static func _restore_unit_data_state(unit_data: UnitData, unit_state: Dictionary) -> bool:
	"""
	Restore complete UnitData state including effects and abilities.
	Returns true if restoration was successful, false if there were issues.
	"""
	var restoration_success: bool = true

	# Restore core stats (these might be modified by effects)
	unit_data.current_health = unit_state.get("current_health", unit_data.current_health)
	unit_data.current_attack = unit_state.get("current_attack", unit_data.current_attack)
	unit_data.max_health = unit_state.get("max_health", unit_data.max_health)
	unit_data.max_attack = unit_state.get("max_attack", unit_data.max_attack)
	unit_data.base_health = unit_state.get("base_health", unit_data.base_health)
	unit_data.base_attack = unit_state.get("base_attack", unit_data.base_attack)
	unit_data.level = unit_state.get("level", unit_data.level)

	# Clear existing effects/abilities before restoration
	unit_data.effects_perm.clear()
	unit_data.effects_temp.clear()
	unit_data.abilities.clear()

	# Restore permanent effects
	var effects_perm_data: Array = unit_state.get("effects_perm", [])
	for effect_data in effects_perm_data:
		if effect_data is Dictionary and effect_data.has("type"):
			var effect: Variant = _deserialize_effect(effect_data)
			if effect:
				unit_data.effects_perm.append(effect)
			else:
				Log.warning(
					"Failed to deserialize permanent effect",
					{"effect_type": effect_data.get("type", "unknown")},
					["serialization", "effect_restore", "warning"]
				)
				restoration_success = false

	# Restore temporary effects
	var effects_temp_data: Array = unit_state.get("effects_temp", [])
	for effect_data in effects_temp_data:
		if effect_data is Dictionary and effect_data.has("type"):
			var effect: Variant = _deserialize_effect(effect_data)
			if effect:
				unit_data.effects_temp.append(effect)
			else:
				Log.warning(
					"Failed to deserialize temporary effect",
					{"effect_type": effect_data.get("type", "unknown")},
					["serialization", "effect_restore", "warning"]
				)
				restoration_success = false

	# Restore abilities
	var abilities_data: Array = unit_state.get("abilities", [])
	for ability_data in abilities_data:
		if ability_data is Dictionary and ability_data.has("type"):
			var ability: Variant = _deserialize_ability(ability_data)
			if ability:
				unit_data.abilities.append(ability)
			else:
				Log.warning(
					"Failed to deserialize ability",
					{"ability_type": ability_data.get("type", "unknown")},
					["serialization", "ability_restore", "warning"]
				)
				restoration_success = false

	# Note: battle_original_reference restoration is complex and might not be needed
	# for most save/load scenarios since it's primarily used during battle

	Log.debug(
		"UnitData state restoration completed",
		{
			"restoration_success": restoration_success,
			"effects_perm_restored": unit_data.effects_perm.size(),
			"effects_temp_restored": unit_data.effects_temp.size(),
			"abilities_restored": unit_data.abilities.size(),
			"stats_updated": true
		},
		["serialization", "unit_data", "restoration"]
	)

	return restoration_success


static func _deserialize_effect(effect_data: Dictionary) -> Variant:
	"""
	Deserialize effect from saved data.
	Supports StatEffect and other effect types in the system.
	"""
	var effect_type: String = effect_data.get("type", "")

	# Handle legacy serialization format
	if effect_data.get("data") == "serialization_not_supported":
		Log.info(
			"Effect deserialization not supported for legacy format",
			{"effect_type": effect_type},
			["serialization", "effect_restore", "legacy"]
		)
		return null

	# Deserialize StatEffect
	if effect_type == "StatEffect":
		var stat_effect: StatEffect = StatEffect.new()
		stat_effect.health_bonus = effect_data.get("health_bonus", 0)
		stat_effect.attack_bonus = effect_data.get("attack_bonus", 0)
		stat_effect.source = effect_data.get("source", "")

		Log.debug(
			"StatEffect deserialized",
			{
				"health_bonus": stat_effect.health_bonus,
				"attack_bonus": stat_effect.attack_bonus,
				"source": stat_effect.source
			},
			["serialization", "effect_restore", "success"]
		)
		return stat_effect

	# Add support for other effect types as they are implemented
	# elif effect_type == "BuffEffect":
	#     return _deserialize_buff_effect(effect_data)

	Log.warning(
		"Effect deserialization not implemented for type",
		{"effect_type": effect_type, "available_keys": effect_data.keys()},
		["serialization", "effect_restore", "not_implemented"]
	)
	return null


static func _deserialize_ability(ability_data: Dictionary) -> Variant:
	"""
	Deserialize ability from saved data.
	Supports all ability types in the system.
	"""
	var ability_type: String = ability_data.get("type", "")

	# Handle legacy serialization format
	if ability_data.get("data") == "requires_ability_serialization":
		Log.info(
			"Ability deserialization not supported for legacy format",
			{"ability_type": ability_type},
			["serialization", "ability_restore", "legacy"]
		)
		return null

	var persistence_type: int = ability_data.get(
		"persistence_type", Ability.PersistenceType.TEMPLATE
	)
	var ability: Ability = null

	# Deserialize specific ability types
	match ability_type:
		"HarmonyAbility":
			var health_bonus: int = ability_data.get("health_bonus", 2)
			var attack_bonus: int = ability_data.get("attack_bonus", 2)
			ability = HarmonyAbility.new(health_bonus, attack_bonus)

		"AbilityDamage":
			var damage_type: String = ability_data.get("damage_type", "")
			ability = AbilityDamage.new(damage_type)

		"DeathTriggerHealthAbility":
			var health_bonus: int = ability_data.get("health_bonus", 1)
			ability = DeathTriggerHealthAbility.new(health_bonus)

		"SoldierBonusAbility":
			var health_per_soldier: int = ability_data.get("health_per_soldier", 1)
			var attack_per_soldier: int = ability_data.get("attack_per_soldier", 1)
			ability = SoldierBonusAbility.new(health_per_soldier, attack_per_soldier)

		"MergeBonusAbility":
			var base_health_bonus: int = ability_data.get("base_health_bonus", 1)
			var base_attack_bonus: int = ability_data.get("base_attack_bonus", 1)
			ability = MergeBonusAbility.new(base_health_bonus, base_attack_bonus)

		"EvilSynergyAbility":
			var health_per_evil: int = ability_data.get("health_per_evil", 1)
			var attack_per_evil: int = ability_data.get("attack_per_evil", 1)
			ability = EvilSynergyAbility.new(health_per_evil, attack_per_evil)

		"DamageShieldAbility":
			ability = DamageShieldAbility.new()
			if ability_data.has("shield_used"):
				(ability as DamageShieldAbility).shield_used = ability_data.get(
					"shield_used", false
				)

		"Ability":
			# Base ability with no specific properties
			ability = Ability.new()

		_:
			Log.warning(
				"Ability deserialization not implemented for type",
				{"ability_type": ability_type, "available_keys": ability_data.keys()},
				["serialization", "ability_restore", "not_implemented"]
			)
			return null

	# Set persistence type for all abilities
	if ability:
		ability.persistence_type = persistence_type

		Log.debug(
			"Ability deserialized",
			{
				"ability_type": ability_type,
				"persistence_type": persistence_type,
				"persistence_name": _get_persistence_type_name(persistence_type)
			},
			["serialization", "ability_restore", "success"]
		)

	return ability


static func _get_persistence_type_name(persistence_type: int) -> String:
	"""Helper method to convert persistence type int to readable name"""
	match persistence_type:
		Ability.PersistenceType.TEMPLATE:
			return "TEMPLATE"
		Ability.PersistenceType.ACQUIRED:
			return "ACQUIRED"
		Ability.PersistenceType.TEMPORARY:
			return "TEMPORARY"
		Ability.PersistenceType.ENHANCEMENT:
			return "ENHANCEMENT"
		_:
			return "UNKNOWN"
