class_name UnitBehavior
extends RefCounted

# Static methods for unit behavior logic, extracted from UnitData to separate concerns
# This class contains all the complex game logic while UnitData remains a pure data container


# Apply permanent stat effects to a unit's current stats
# Extracted from UnitData.apply_permanent_effects_to_current_stats()
static func apply_permanent_effects_to_stats(unit: UnitData) -> void:
	var stats_before_attack: int = unit.current_attack
	var stats_before_health: int = unit.current_health
	var total_health_bonus: int = 0
	var total_attack_bonus: int = 0

	Log.debug(
		"STAT REAPPLICATION CALLED - Before applying effects",
		{
			"card_id": unit.card_info.get("id", "unknown"),
			"level": unit.level,
			"current_attack_before": stats_before_attack,
			"current_health_before": stats_before_health,
			"max_attack": unit.max_attack,
			"max_health": unit.max_health,
			"effects_perm_count": unit.effects_perm.size(),
			"call_source": "UnitBehavior.apply_permanent_effects_to_stats"
		},
		[Log.TAG_BATTLE, Log.TAG_STAT, Log.TAG_EFFECT, "stat_refresh"]
	)

	for effect: Variant in unit.effects_perm:
		if effect is StatEffect:
			var stat_effect: StatEffect = effect
			if not stat_effect:
				Log.error(
					"Invalid StatEffect in effects_perm array",
					{"card_id": unit.card_info.get("id", "unknown")},
					[Log.TAG_ERROR]
				)
				continue

			total_health_bonus += stat_effect.health_bonus
			total_attack_bonus += stat_effect.attack_bonus
			Log.debug(
				"Processing StatEffect for reapplication",
				{
					"card_id": unit.card_info.get("id", "unknown"),
					"effect_health": stat_effect.health_bonus,
					"effect_attack": stat_effect.attack_bonus,
					"running_health_total": total_health_bonus,
					"running_attack_total": total_attack_bonus
				},
				[Log.TAG_BATTLE, Log.TAG_STAT, Log.TAG_EFFECT, "stat_refresh"]
			)

	unit.max_attack = unit.base_attack + total_attack_bonus
	unit.max_health = unit.base_health + total_health_bonus
	unit.current_attack = unit.max_attack
	unit.current_health = unit.max_health

	Log.info(
		"STAT REAPPLICATION COMPLETED - Stats updated",
		{
			"card_id": unit.card_info.get("id", "unknown"),
			"level": unit.level,
			"stats_before_attack": stats_before_attack,
			"stats_before_health": stats_before_health,
			"stats_after_attack": unit.current_attack,
			"stats_after_health": unit.current_health,
			"health_bonus_applied": total_health_bonus,
			"attack_bonus_applied": total_attack_bonus,
			"final_attack": unit.current_attack,
			"final_health": unit.current_health,
			"effects_count": unit.effects_perm.size(),
			"stat_delta_attack": unit.current_attack - stats_before_attack,
			"stat_delta_health": unit.current_health - stats_before_health
		},
		[Log.TAG_BATTLE, Log.TAG_STAT, Log.TAG_EFFECT, "stat_refresh"]
	)


# Apply permanent changes from battle state to a unit
# Extracted from UnitData.apply_permanent_changes_from()
static func apply_permanent_changes_from_battle(
	unit: UnitData, final_battle_state: UnitData
) -> void:
	var original_effects_count: int = unit.effects_perm.size()
	var original_abilities_count: int = unit.get_acquired_abilities().size()
	var battle_died: bool = (
		final_battle_state.current_health <= GameConstants.BattleSystem.ZERO_HEALTH_THRESHOLD
	)

	Log.debug(
		"Applying permanent changes from battle",
		{
			"original_health": unit.current_health,
			"battle_health": final_battle_state.current_health,
			"unit_died_in_battle": battle_died,
			"battle_effects_perm_count": final_battle_state.effects_perm.size(),
			"battle_acquired_abilities_count": final_battle_state.get_acquired_abilities().size()
		},
		[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_ABILITY]
	)

	if final_battle_state.max_health > unit.max_health:
		unit.max_health = final_battle_state.max_health
		Log.debug(
			"Max health increased during battle",
			{"old": unit.max_health, "new": final_battle_state.max_health},
			[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_STAT]
		)
	if final_battle_state.max_attack > unit.max_attack:
		unit.max_attack = final_battle_state.max_attack
		Log.debug(
			"Max attack increased during battle",
			{"old": unit.max_attack, "new": final_battle_state.max_attack},
			[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_STAT]
		)

	unit.current_health = unit.max_health

	var effects_transferred: int = 0
	for battle_effect: Variant in final_battle_state.effects_perm:
		if not battle_effect is StatEffect:
			continue

		var battle_stat_effect: StatEffect = battle_effect
		if not battle_stat_effect:
			Log.error(
				"Invalid StatEffect in battle state during reconciliation",
				{"unit_died": battle_died},
				[Log.TAG_ERROR, Log.TAG_BATTLE]
			)
			continue

		var already_has_effect: bool = false
		for existing_effect: Variant in unit.effects_perm:
			if existing_effect is StatEffect:
				var existing_stat_effect: StatEffect = existing_effect
				if not existing_stat_effect:
					continue
				if (
					existing_stat_effect.source == battle_stat_effect.source
					and existing_stat_effect.health_bonus == battle_stat_effect.health_bonus
					and existing_stat_effect.attack_bonus == battle_stat_effect.attack_bonus
				):
					already_has_effect = true
					break

		if not already_has_effect:
			unit.effects_perm.append(battle_stat_effect)
			effects_transferred += 1
			Log.info(
				"Transferred permanent stat effect from battle",
				{"effect": battle_stat_effect.get_description(), "unit_died": battle_died},
				[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_STAT, Log.TAG_EFFECT]
			)

	var current_ability_classes: Array[String] = []
	for ab: Ability in unit.abilities:
		current_ability_classes.append(Utils.get_type(ab))

	var abilities_transferred: int = 0
	for battle_ability: Ability in final_battle_state.abilities:
		if (
			battle_ability.persistence_type == Ability.PersistenceType.ACQUIRED
			and not Utils.get_type(battle_ability) in current_ability_classes
			and not is_combat_only_ability(battle_ability)
		):
			var enhanced_ability: Ability = battle_ability.deep_duplicate()
			enhanced_ability.persistence_type = Ability.PersistenceType.ENHANCEMENT
			unit.add_ability(enhanced_ability)
			abilities_transferred += 1
			Log.info(
				"Unit gained new permanent ability from combat (converted to ENHANCEMENT)",
				{
					"ability": Utils.get_type(enhanced_ability),
					"unit_died": battle_died,
					"converted_from": "ACQUIRED"
				},
				[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_ABILITY]
			)
		elif is_combat_only_ability(battle_ability):
			Log.debug(
				"Skipped combat-only ability from becoming permanent",
				{
					"ability": Utils.get_type(battle_ability),
					"unit_died": battle_died,
					"reason": "combat_only_exclusion"
				},
				[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_ABILITY]
			)

	Log.info(
		"Battle reconciliation summary",
		{
			"unit_died_in_battle": battle_died,
			"effects_perm_transferred": effects_transferred,
			"abilities_transferred": abilities_transferred,
			"final_effects_perm_count": unit.effects_perm.size(),
			"final_acquired_abilities_count": unit.get_acquired_abilities().size()
		},
		[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_VALIDATION]
	)

	if effects_transferred > 0:
		apply_permanent_effects_to_stats(unit)
		Log.debug(
			"Applied transferred battle effects to current stats",
			{
				"current_attack": unit.current_attack,
				"current_health": unit.current_health,
				"effects_applied": effects_transferred
			},
			[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_STAT]
		)


# Upgrade unit stats to a new level
# Extracted from UnitData.upgrade_stats_to_new_level()
static func upgrade_unit_stats(unit: UnitData, new_level: int) -> void:
	var health: int = unit.card_info.health.to_int()
	var attack: int = unit.card_info.attack.to_int()

	unit.base_health = health * new_level
	unit.base_attack = attack * new_level

	apply_permanent_effects_to_stats(unit)


# Transfer stat effects from source units
# Extracted from UnitData.transfer_stat_effects_from()
static func transfer_stat_effects(unit: UnitData, source_units: Array[UnitData]) -> void:
	Log.debug(
		"Starting StatEffect transfer",
		{
			"target_card_id": unit.card_info.get("id", ""),
			"source_units_count": source_units.size(),
			"target_effects_before": unit.effects_perm.size()
		},
		[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
	)

	for i: int in range(source_units.size()):
		var source_unit: UnitData = source_units[i]
		var source_card_id: String = source_unit.card_info.get("id", "")

		Log.debug(
			"Processing source unit for StatEffect transfer",
			{
				"source_index": i,
				"source_card_id": source_card_id,
				"source_effects_count": source_unit.effects_perm.size()
			},
			[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
		)

		for j: int in range(source_unit.effects_perm.size()):
			var effect: Variant = source_unit.effects_perm[j]
			if effect is StatEffect:
				var stat_effect: StatEffect = effect
				if not stat_effect:
					Log.error(
						"Invalid StatEffect during transfer",
						{"source_card_id": source_card_id},
						[Log.TAG_ERROR, Log.TAG_MERGE]
					)
					continue
				var copied_effect: StatEffect = stat_effect.deep_duplicate()
				unit.effects_perm.append(copied_effect)

				Log.debug(
					"Transferred StatEffect from source unit",
					{
						"source_card_id": source_card_id,
						"target_card_id": unit.card_info.get("id", ""),
						"effect_description": stat_effect.get_description(),
						"health_bonus": stat_effect.health_bonus,
						"attack_bonus": stat_effect.attack_bonus,
						"effect_source": stat_effect.source,
						"effect_id": stat_effect.get_instance_id(),
						"copied_effect_id": copied_effect.get_instance_id()
					},
					[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
				)
			else:
				var effect_type: String = Utils.get_variant_type(effect)

				Log.debug(
					"Skipping non-StatEffect during transfer",
					{"source_card_id": source_card_id, "effect_type": effect_type},
					[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
				)

	Log.debug(
		"Completed StatEffect transfer",
		{
			"target_card_id": unit.card_info.get("id", ""),
			"target_effects_after": unit.effects_perm.size(),
			"effects_transferred":
			unit.effects_perm.size() - GameConstants.BattleSystem.ZERO_STAT_VALUE
		},
		[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
	)


# Transfer merge effects from source units
# Extracted from UnitData.transfer_merge_effects_from()
static func transfer_merge_effects(unit: UnitData, source_units: Array[UnitData]) -> void:
	Log.debug(
		"Starting merge effects transfer",
		{
			"target_card_id": unit.card_info.get("id", ""),
			"source_units_count": source_units.size(),
			"target_abilities_before": unit.abilities.size(),
			"target_effects_before": unit.effects_perm.size()
		},
		[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
	)

	for i: int in range(source_units.size()):
		var source_unit: UnitData = source_units[i]
		var source_card_id: String = source_unit.card_info.get("id", "")

		Log.debug(
			"Source unit ability inventory (ALL abilities)",
			{
				"source_index": i,
				"source_card_id": source_card_id,
				"total_abilities": source_unit.abilities.size()
			},
			[Log.TAG_MERGE, Log.TAG_ABILITY, Log.TAG_DEBUG]
		)

		for j: int in range(source_unit.abilities.size()):
			var source_ability: Ability = source_unit.abilities[j]
			Log.debug(
				"Source ability details",
				{
					"source_card_id": source_card_id,
					"ability_index": j,
					"ability_class": Utils.get_type(source_ability),
					"persistence_type": source_ability.persistence_type,
					"persistence_name": persistence_type_name(source_ability.persistence_type)
				},
				[Log.TAG_MERGE, Log.TAG_ABILITY, Log.TAG_DEBUG]
			)

		var transferable_abilities: Array[Ability] = []
		transferable_abilities.append_array(source_unit.get_acquired_abilities())
		transferable_abilities.append_array(source_unit.get_enhancement_abilities())
		transferable_abilities.append_array(source_unit.get_temporary_abilities())

		Log.debug(
			"Processing source unit for ability transfer",
			{
				"source_index": i,
				"source_card_id": source_card_id,
				"template_abilities": source_unit.get_template_abilities().size(),
				"acquired_abilities": source_unit.get_acquired_abilities().size(),
				"enhancement_abilities": source_unit.get_enhancement_abilities().size(),
				"temporary_abilities": source_unit.get_temporary_abilities().size(),
				"transferable_abilities": transferable_abilities.size()
			},
			[Log.TAG_MERGE, Log.TAG_ABILITY, Log.TAG_DEBUG]
		)

		for ability: Ability in transferable_abilities:
			Log.debug(
				"Transferring ability",
				{
					"source_card_id": source_card_id,
					"target_card_id": unit.card_info.get("id", ""),
					"ability_class": Utils.get_type(ability),
					"persistence_type": ability.persistence_type,
					"persistence_name": persistence_type_name(ability.persistence_type)
				},
				[Log.TAG_MERGE, Log.TAG_ABILITY, Log.TAG_DEBUG]
			)
			unit.abilities.append(ability)

	transfer_stat_effects(unit, source_units)

	Log.debug(
		"Completed merge effects transfer",
		{
			"target_card_id": unit.card_info.get("id", ""),
			"target_abilities_after": unit.abilities.size(),
			"target_effects_after": unit.effects_perm.size()
		},
		[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
	)


# Generate deterministic checksum for complete unit state
# Extracted from UnitData.get_state_checksum()
static func get_state_checksum(unit: UnitData) -> String:
	var state_data: Dictionary = {
		"card_id": unit.card_info.get("id", ""),
		"level": unit.level,
		"current_health": unit.current_health,
		"current_attack": unit.current_attack,
		"max_health": unit.max_health,
		"max_attack": unit.max_attack,
		"base_health": unit.base_health,
		"base_attack": unit.base_attack,
		"abilities_count": unit.abilities.size(),
		"effects_perm_count": unit.effects_perm.size()
	}

	var ability_types: Array[String] = []
	for ability: Ability in unit.abilities:
		if ability:
			ability_types.append(Utils.get_type(ability))
	ability_types.sort()
	state_data["ability_types"] = ability_types

	var effect_details: Array[Dictionary] = []
	for effect: Variant in unit.effects_perm:
		if effect is StatEffect:
			var stat_effect: StatEffect = effect
			effect_details.append(
				{
					"type": "StatEffect",
					"health_bonus": stat_effect.health_bonus,
					"attack_bonus": stat_effect.attack_bonus,
					"source": stat_effect.source
				}
			)
		else:
			effect_details.append({"type": str(type_string(typeof(effect))), "value": str(effect)})

	effect_details.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a) < str(b))
	state_data["effect_details"] = effect_details

	return DictUtils.deterministic_hash(state_data)


# Check if this ability should only apply during combat and not persist between battles
# Uses the ability's persistence_type as the authoritative source
# Extracted from UnitData._is_combat_only_ability()
static func is_combat_only_ability(ability: Ability) -> bool:
	# Combat-only abilities use TEMPORARY persistence type
	# This is a general system that works for all abilities without hardcoding
	return ability.persistence_type == Ability.PersistenceType.TEMPORARY


# Get the string name for a persistence type
# Extracted from UnitData._persistence_type_name()
static func persistence_type_name(persistence_type: Ability.PersistenceType) -> String:
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
