class_name AbilityHelper extends RefCounted

# Pure ability utilities - focused on ability-specific operations
# All methods are STATIC to ensure consistent separation of concerns
# Delegates complex operations to BattleRules for clean architecture

# ===== EVENT TYPE + PHASE CHECKING (ABILITY-SPECIFIC) =====


static func is_death_post(unit: BattleAbilityEvent) -> bool:
	"""Check if event is a death event in POST phase"""
	return unit.phase == core.Tempus.POST and unit.event is BattleContext.DeathEvent


static func is_damage_pre(unit: BattleAbilityEvent) -> bool:
	"""Check if event is a damage event in PRE phase"""
	return unit.phase == core.Tempus.PRE and unit.event is BattleContext.DamageEvent


static func is_damage_post(unit: BattleAbilityEvent) -> bool:
	"""Check if event is a damage event in POST phase"""
	return unit.phase == core.Tempus.POST and unit.event is BattleContext.DamageEvent


static func is_combat_pre(unit: BattleAbilityEvent) -> bool:
	"""Check if event is a combat event in PRE phase"""
	return unit.phase == core.Tempus.PRE and unit.event is BattleContext.CombatEvent


static func is_combat_post(unit: BattleAbilityEvent) -> bool:
	"""Check if event is a combat event in POST phase"""
	return unit.phase == core.Tempus.POST and unit.event is BattleContext.CombatEvent


static func is_stat_change_pre(unit: BattleAbilityEvent) -> bool:
	"""Check if event is a stat change event in PRE phase"""
	return unit.phase == core.Tempus.PRE and unit.event is BattleContext.StatChangeEvent


static func is_stat_change_post(unit: BattleAbilityEvent) -> bool:
	"""Check if event is a stat change event in POST phase"""
	return unit.phase == core.Tempus.POST and unit.event is BattleContext.StatChangeEvent


static func is_shield_event_pre(unit: BattleAbilityEvent) -> bool:
	"""Check if event is a shield event in PRE phase"""
	return unit.phase == core.Tempus.PRE and unit.event is BattleContext.ShieldEvent


static func is_shield_event_post(unit: BattleAbilityEvent) -> bool:
	"""Check if event is a shield event in POST phase"""
	return unit.phase == core.Tempus.POST and unit.event is BattleContext.ShieldEvent


static func is_start_of_turn_post(unit: BattleAbilityEvent) -> bool:
	"""Check if event is start of turn in POST phase"""
	return unit.phase == core.Tempus.POST and unit.event is BattleContext.StartOfTurnEvent


static func is_end_of_turn_post(unit: BattleAbilityEvent) -> bool:
	"""Check if event is end of turn in POST phase"""
	return unit.phase == core.Tempus.POST and unit.event is BattleContext.EndOfTurnEvent


# Note: BattleStartEvent doesn't exist in current BattleContext, so we'll add it when needed
# static func is_battle_start_post(unit: BattleAbilityEvent) -> bool:
#	"""Check if event is a battle start event in POST phase"""
#	return unit.phase == core.Tempus.POST and unit.event is BattleContext.BattleStartEvent

# ===== SINGLE-UNIT EVENT CREATION (ABILITY-SPECIFIC) =====


static func grant_health_bonus(unit: BattleAbilityEvent, bonus: int) -> void:
	"""Grant health bonus to the unit"""
	if bonus <= 0:
		return

	var event: BattleContext.StatChangeEvent = BattleContext.StatChangeEvent.new(
		Battle.UNIT_HEALTH, unit.position, unit.is_allied, bonus
	)
	unit.battle_context.add_event(event)


static func grant_attack_bonus(unit: BattleAbilityEvent, bonus: int) -> void:
	"""Grant attack bonus to the unit"""
	if bonus <= 0:
		return

	var event: BattleContext.StatChangeEvent = BattleContext.StatChangeEvent.new(
		Battle.UNIT_ATTACK, unit.position, unit.is_allied, bonus
	)
	unit.battle_context.add_event(event)


static func deal_damage_to_unit(unit: BattleAbilityEvent, damage: int) -> void:
	"""Deal damage to the unit"""
	if damage <= 0:
		return

	var event: BattleContext.DamageEvent = BattleContext.DamageEvent.new(
		damage, unit.position, unit.is_allied
	)
	unit.battle_context.add_event(event)


static func activate_shield(unit: BattleAbilityEvent, is_active: bool = true) -> void:
	"""Activate or deactivate shield for the unit"""
	var event: BattleContext.ShieldEvent = BattleContext.ShieldEvent.new(
		unit.position, unit.is_allied, is_active
	)
	unit.battle_context.add_event(event)


static func grant_stat_bonus(unit: BattleAbilityEvent, stat_name: StringName, bonus: int) -> void:
	"""Grant bonus to any stat type"""
	if bonus <= 0:
		return

	var event: BattleContext.StatChangeEvent = BattleContext.StatChangeEvent.new(
		stat_name, unit.position, unit.is_allied, bonus
	)
	unit.battle_context.add_event(event)


# ===== COMPLEX ABILITY OPERATIONS (DELEGATES TO BATTLE RULES) =====


static func deal_damage_to_random_enemy(
	unit: BattleAbilityEvent, damage: int, count: int = 1
) -> void:
	"""Deal damage to random enemies (delegates to BattleRules)"""
	BattleRules.deal_damage_to_random_enemies(unit.battle_context, unit.is_allied, damage, count)


static func deal_damage_to_random_enemies(
	unit: BattleAbilityEvent, damage: int, count: int
) -> void:
	"""Deal damage to multiple random enemies (delegates to BattleRules)"""
	BattleRules.deal_damage_to_random_enemies(unit.battle_context, unit.is_allied, damage, count)


static func grant_ally_bonuses(
	unit: BattleAbilityEvent, health_bonus: int, attack_bonus: int
) -> void:
	"""Grant bonuses to all allies except self (delegates to BattleRules)"""
	BattleRules.grant_bonuses_to_all_allies(
		unit.battle_context, unit.position, unit.is_allied, health_bonus, attack_bonus
	)


static func deal_damage_to_all_enemies(unit: BattleAbilityEvent, damage: int) -> void:
	"""Deal damage to all enemy units (delegates to BattleRules)"""
	var enemy_positions: Array[int] = unit.get_enemy_positions()
	BattleRules.deal_damage_to_random_enemies(
		unit.battle_context, unit.is_allied, damage, enemy_positions.size()
	)


static func deal_breakthrough_damage(
	unit: BattleAbilityEvent, target_position: int, damage: int
) -> void:
	"""
	Deal breakthrough damage to units behind the primary target.
	This is used by spearman-like abilities that pierce through to hit back-row units.
	"""
	if damage <= 0:
		return

	# Get the target side (enemy of the attacker)
	var target_is_allied: bool = not unit.is_allied

	# Get breakthrough targets using BattleRules positioning logic
	var breakthrough_targets: Array[int] = BattleRules.get_breakthrough_targets(
		unit.battle_context, target_position, target_is_allied
	)

	# Deal damage to all breakthrough targets
	BattleRules.deal_damage_to_targets(
		unit.battle_context, unit.is_allied, breakthrough_targets, damage
	)


static func grant_bonuses_to_all_allies_including_self(
	unit: BattleAbilityEvent, health_bonus: int, attack_bonus: int
) -> void:
	"""Grant bonuses to all allies including self"""
	# Grant to self first
	if health_bonus > 0:
		grant_health_bonus(unit, health_bonus)
	if attack_bonus > 0:
		grant_attack_bonus(unit, attack_bonus)

	# Then to other allies
	grant_ally_bonuses(unit, health_bonus, attack_bonus)


# ===== ABILITY SYSTEM OPTIMIZATION =====


static func should_process_event(ability: Ability, event: Context.Event) -> bool:
	"""Check if ability should process this event type for performance optimization"""
	if not ability:
		return false

	var handled_event_classes: Array = ability.get_handled_event_classes()
	if handled_event_classes.is_empty():
		return true  # Process all events if no filtering specified

	# Check if event is instance of any handled class
	for event_class: Variant in handled_event_classes:
		if is_instance_of(event, event_class):
			return true

	return false


# ===== TARGETING HELPERS =====


static func is_event_targeting_unit(unit: BattleAbilityEvent) -> bool:
	"""Check if current event is targeting this specific unit (delegates to BattleAbilityEvent)"""
	return unit.is_event_targeting_this_unit()


static func is_event_from_unit(unit: BattleAbilityEvent) -> bool:
	"""Check if current event originated from this specific unit (delegates to BattleAbilityEvent)"""
	return unit.is_event_from_this_unit()


static func get_target_unit(unit: BattleAbilityEvent) -> UnitData:
	"""Get the unit being targeted by the current event, if applicable"""
	if unit.event is BattleContext.DamageEvent:
		var damage_event: BattleContext.DamageEvent = unit.event as BattleContext.DamageEvent
		return unit.battle_context.get_unit_at_position(
			damage_event.target_position, damage_event.is_allied_side
		)

	if unit.event is BattleContext.StatChangeEvent:
		var stat_event: BattleContext.StatChangeEvent = unit.event as BattleContext.StatChangeEvent
		return unit.battle_context.get_unit_at_position(
			stat_event.target_position as int, stat_event.is_allied_side as bool
		)

	if unit.event is BattleContext.ShieldEvent:
		var shield_event: BattleContext.ShieldEvent = unit.event as BattleContext.ShieldEvent
		return unit.battle_context.get_unit_at_position(
			shield_event.target_position as int, shield_event.is_allied_side as bool
		)

	return null


static func get_attacker_unit(unit: BattleAbilityEvent) -> UnitData:
	"""Get the unit that initiated the current combat event, if applicable"""
	if unit.event is BattleContext.CombatEvent:
		var combat_event: BattleContext.CombatEvent = unit.event as BattleContext.CombatEvent
		return unit.battle_context.get_unit_at_position(
			combat_event.attacker_position as int, combat_event.is_allied_attack as bool
		)

	return null


# ===== CONDITION CHECKING HELPERS =====


static func is_unit_at_low_health(
	unit: BattleAbilityEvent, threshold_percent: float = 0.25
) -> bool:
	"""Check if the unit is at low health (default: 25% or below)"""
	var unit_data: UnitData = unit.get_self_unit()
	if not unit_data:
		return false

	var health_ratio: float = float(unit_data.current_health) / float(unit_data.max_health)
	return health_ratio <= threshold_percent


static func is_unit_at_high_health(
	unit: BattleAbilityEvent, threshold_percent: float = 0.75
) -> bool:
	"""Check if the unit is at high health (default: 75% or above)"""
	var unit_data: UnitData = unit.get_self_unit()
	if not unit_data:
		return false

	var health_ratio: float = float(unit_data.current_health) / float(unit_data.max_health)
	return health_ratio >= threshold_percent


static func count_allies_with_condition(unit: BattleAbilityEvent, condition_func: Callable) -> int:
	"""Count allied units that meet a specific condition"""
	var count: int = 0
	var ally_positions: Array[int] = unit.get_ally_positions()

	for pos: int in ally_positions:
		var ally_unit: UnitData = unit.battle_context.get_unit_at_position(pos, unit.is_allied)
		if ally_unit and condition_func.call(ally_unit):
			count += 1

	return count


static func count_enemies_with_condition(unit: BattleAbilityEvent, condition_func: Callable) -> int:
	"""Count enemy units that meet a specific condition"""
	var count: int = 0
	var enemy_positions: Array[int] = unit.get_enemy_positions()

	for pos: int in enemy_positions:
		var enemy_unit: UnitData = unit.battle_context.get_unit_at_position(pos, not unit.is_allied)
		if enemy_unit and condition_func.call(enemy_unit):
			count += 1

	return count


# ===== TAG RETRIEVAL UTILITIES =====


static func get_all_tags_from_card(card: Card) -> Array[String]:
	"""
	Get all tags from a card, including both explicit tags and tribe.
	This is the canonical way to retrieve all classification tags for a unit.

	Returns:
		Array[String]: All tags including tribe (empty array if no tags/tribe)
	"""
	if not card or not card.unit_info or not card.unit_info.card_definition:
		return []

	var card_tags: String = card.unit_info.card_definition.tags
	var card_tribe: String = card.unit_info.card_definition.tribe

	var all_tags: Array[String] = []

	# Add explicit tags
	if not card_tags.is_empty():
		var tag_list: PackedStringArray = card_tags.split(",")
		for tag: String in tag_list:
			var trimmed_tag: String = tag.strip_edges()
			if not trimmed_tag.is_empty():
				all_tags.append(trimmed_tag)

	# Add tribe as a tag
	if not card_tribe.is_empty():
		all_tags.append(card_tribe)

	return all_tags


# ===== TAG-BASED UNIT COUNTING =====


static func count_units_with_tags_in_lineup(
	lineup: Dictionary[int, Card], tags: Array[String], exclude_unit: Block = null
) -> int:
	"""
	Count units in lineup that have ANY of the specified tags.

	Args:
		lineup: Dictionary of position -> Card
		tags: Array of tag strings to match (OR logic - unit needs ANY tag)
		exclude_unit: Optional unit to exclude from count (typically self)

	Returns:
		int: Count of units with matching tags
	"""
	var count: int = 0

	for unit_position: int in lineup:
		var card: Card = lineup[unit_position]
		if card == exclude_unit:
			continue

		if has_any_tag(card, tags):
			count += 1

	return count


static func count_units_with_all_tags_in_lineup(
	lineup: Dictionary[int, Card], tags: Array[String], exclude_unit: Block = null
) -> int:
	"""
	Count units in lineup that have ALL of the specified tags.

	Args:
		lineup: Dictionary of position -> Card
		tags: Array of tag strings to match (AND logic - unit needs ALL tags)
		exclude_unit: Optional unit to exclude from count (typically self)

	Returns:
		int: Count of units with all matching tags
	"""
	var count: int = 0

	for unit_position: int in lineup:
		var card: Card = lineup[unit_position]
		if card == exclude_unit:
			continue

		if has_all_tags(card, tags):
			count += 1

	return count


static func has_any_tag(card: Card, tags: Array[String]) -> bool:
	"""Check if card has ANY of the specified tags (includes both tags and tribe)"""
	var all_card_tags: Array[String] = get_all_tags_from_card(card)

	for tag: String in tags:
		for card_tag: String in all_card_tags:
			if card_tag == tag:
				return true

	return false


static func has_all_tags(card: Card, tags: Array[String]) -> bool:
	"""Check if card has ALL of the specified tags (includes both tags and tribe)"""
	var all_card_tags: Array[String] = get_all_tags_from_card(card)

	for tag: String in tags:
		var found: bool = false
		for card_tag: String in all_card_tags:
			if card_tag == tag:
				found = true
				break
		if not found:
			return false

	return true


# ===== DRAFT SYNERGY HELPERS =====


static func apply_permanent_stat_bonus(
	event: DraftAbilityEvent, health_bonus: int, attack_bonus: int
) -> void:
	"""Apply permanent stat bonuses to a unit during draft"""
	if health_bonus <= 0 and attack_bonus <= 0:
		return

	var modified_card: Card = event.unit
	var stat_effect_event: core.StatEffectEvent = core.StatEffectEvent.new(
		modified_card, health_bonus, attack_bonus, core.EventSource.SYSTEM_CASCADE
	)
	event.draft_context.add_event(stat_effect_event)


static func apply_permanent_stat_bonus_to_unit(
	event: DraftAbilityEvent, target_unit: Card, health_bonus: int, attack_bonus: int
) -> void:
	"""Apply permanent stat bonuses to a specific target unit during draft"""
	if health_bonus <= 0 and attack_bonus <= 0:
		return

	var stat_effect_event: core.StatEffectEvent = core.StatEffectEvent.new(
		target_unit, health_bonus, attack_bonus, core.EventSource.SYSTEM_CASCADE
	)
	event.draft_context.add_event(stat_effect_event)


static func get_units_with_tag_in_lineup(
	lineup: Dictionary[int, Card], tag: String, exclude_unit: Block = null
) -> Array[Card]:
	"""Get all units in lineup that have the specified tag, optionally excluding one unit"""
	var units: Array[Card] = []

	for position: int in lineup:
		var card: Card = lineup[position]
		if card == exclude_unit:
			continue

		if has_any_tag(card, [tag]):
			units.append(card)

	return units


# ===== UTILITY METHODS =====


static func get_damage_from_event(unit: BattleAbilityEvent) -> int:
	"""Extract damage amount from damage event, if applicable"""
	if unit.event is BattleContext.DamageEvent:
		var damage_event: BattleContext.DamageEvent = unit.event as BattleContext.DamageEvent
		return damage_event.damage_amount

	return 0


static func get_stat_change_from_event(unit: BattleAbilityEvent) -> Dictionary:
	"""Extract stat change information from stat change event"""
	if unit.event is BattleContext.StatChangeEvent:
		var stat_event: BattleContext.StatChangeEvent = unit.event as BattleContext.StatChangeEvent
		return {
			"stat_name": stat_event.stat_name,
			"change_value": stat_event.change_value,
			"new_value": stat_event.new_stat_value
		}

	return {}


static func is_ability_trigger_condition_met(
	unit: BattleAbilityEvent, trigger_type: StringName
) -> bool:
	"""Check if general ability trigger conditions are met"""
	match trigger_type:
		"on_death":
			return is_death_post(unit) and is_event_targeting_unit(unit)
		"on_take_damage":
			return is_damage_post(unit) and is_event_targeting_unit(unit)
		"on_deal_damage":
			return is_damage_post(unit) and is_event_from_unit(unit)
		"on_combat_start":
			return is_combat_pre(unit) and is_event_from_unit(unit)
		"on_combat_end":
			return is_combat_post(unit) and is_event_from_unit(unit)
		"on_turn_start":
			return is_start_of_turn_post(unit)
		"on_turn_end":
			return is_end_of_turn_post(unit)
		_:
			return false
