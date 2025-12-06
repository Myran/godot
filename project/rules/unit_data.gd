class_name UnitData extends Resource

const POST_EVENT_RESPONSE: String = "post_event_response"
const PRE_EVENT_RESPONSE: String = "pre_event_response"
const DRAFT_POST_EVENT_RESPONSE: String = "draft_post_event_response"
const DRAFT_PRE_EVENT_RESPONSE: String = "draft_pre_event_response"

var max_health: int = 1  # DEFAULT_HEALTH
var max_attack: int = 1  # DEFAULT_ATTACK
var base_health: int = 1  # DEFAULT_HEALTH
var base_attack: int = 1  # DEFAULT_ATTACK

var current_health: int = 1:  # DEFAULT_HEALTH
	set = set_current_health
var current_attack: int = 1:  # DEFAULT_ATTACK
	set = set_current_attack
var level: int = 0
var card_definition: CardDefinition = null
var effects_temp: Array[Variant] = []
var effects_perm: Array[Variant] = []
var abilities: Array[Ability] = []
var battle_original_reference: UnitData = null


func get_active_abilities() -> Array[Ability]:
	return abilities


func set_current_health(new_health: int) -> void:
	if max_health < new_health:
		max_health = new_health
	current_health = new_health


func set_current_attack(new_attack: int) -> void:
	if max_attack < new_attack:
		max_attack = new_attack
	current_attack = new_attack


func init_with_definition(_card_def: CardDefinition) -> void:
	"""Initialize unit with strongly-typed CardDefinition."""
	card_definition = _card_def

	var abilities_str: String = card_definition.abilities_string
	if abilities_str.is_empty():
		Log.warning(
			"Card definition missing abilities",
			{"card_id": card_definition.id, "card_name": card_definition.card_name},
			["debug"]
		)

	var new_abilities: Array[Ability] = AbilitiesHandler.parse_ability_string(abilities_str)
	for _ab: Ability in new_abilities:
		if _ab != null:
			_ab.persistence_type = Ability.PersistenceType.TEMPLATE
			add_ability(_ab)

	var ability: Ability
	# TESTING SCAFFOLDING: Give archer (ID 1) a shield ability for testing shield mechanics
	# This is temporary scaffolding to test DamageShieldAbility functionality
	# The archer will not have this ability in the final game
	if card_definition.id == "1":
		ability = DamageShieldAbility.new()
		ability.persistence_type = Ability.PersistenceType.TEMPLATE
		add_ability(ability)
		Log.info(
			"Archer scaffolding: Added DamageShieldAbility for testing",
			{"card_id": card_definition.id, "card_name": card_definition.card_name},
			["ability", "scaffolding", "archer", "shield", "testing"]
		)
	if card_definition.id == "2":
		ability = DeathTriggerHealthAbility.new(2)
		ability.persistence_type = Ability.PersistenceType.TEMPORARY  # Combat-only, doesn't persist
		add_ability(ability)
	if card_definition.id == "12":
		ability = EvilSynergyAbility.new()
		ability.persistence_type = Ability.PersistenceType.TEMPLATE
		add_ability(ability)
	if card_definition.id == "4":
		ability = MergeBonusAbility.new(1, 1)  # DEFAULT_HEALTH, DEFAULT_ATTACK
		ability.persistence_type = Ability.PersistenceType.TEMPLATE
		add_ability(ability)


func add_ability(_ability: Ability) -> void:
	abilities.append(_ability)


func _has_ability_instance(new_ability: Ability) -> bool:
	for existing_ability: Ability in abilities:
		if Utils.get_type(existing_ability) == Utils.get_type(new_ability):
			return true
	return false


func _persistence_type_name(persistence_type: Ability.PersistenceType) -> String:
	return UnitBehavior.persistence_type_name(persistence_type)


func _is_combat_only_ability(ability: Ability) -> bool:
	"""Check if this ability should only apply during combat and not persist between battles"""
	return UnitBehavior.is_combat_only_ability(ability)


func remove_ability(_ability: Ability) -> void:
	abilities.erase(_ability)


func get_template_abilities() -> Array[Ability]:
	return abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type == Ability.PersistenceType.TEMPLATE
	)


func get_permanent_abilities() -> Array[Ability]:
	return get_template_abilities()


func get_acquired_abilities() -> Array[Ability]:
	return abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type == Ability.PersistenceType.ACQUIRED
	)


func get_temporary_abilities() -> Array[Ability]:
	return abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type == Ability.PersistenceType.TEMPORARY
	)


func get_enhancement_abilities() -> Array[Ability]:
	return abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type == Ability.PersistenceType.ENHANCEMENT
	)


func clear_temporary_abilities() -> void:
	abilities = abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type != Ability.PersistenceType.TEMPORARY
	)


func upgrade_unit_to_level(_new_level: int) -> void:
	level = int(_new_level)
	upgrade_stats_to_new_level(level)


func upgrade_stats_to_new_level(_level: int) -> void:
	UnitBehavior.upgrade_unit_stats(self, _level)


func select_action(_battle_context: BattleContext) -> Dictionary:
	return {"action": Battle.BattleAction.ATTACK_REGULAR}


func draft_post_event_response(
	pos: int, _u: Block, _context: DraftContext, event: core.CoreEvent
) -> void:
	check_draft_abilities(core.Tempus.POST, pos, _context, event, _u)


func draft_pre_event_response(
	pos: int, _u: Block, _context: DraftContext, event: core.CoreEvent
) -> void:
	check_draft_abilities(core.Tempus.PRE, pos, _context, event, _u)


func pre_event_response(
	_u_pos: int, _u_side: int, _battle_context: BattleContext, _event: Context.Event
) -> void:
	check_abilities(core.Tempus.PRE, _u_pos, _u_side, _battle_context, _event)


func post_event_response(
	_u_pos: int, _u_side: int, _battle_context: BattleContext, _event: Context.Event
) -> void:
	check_abilities(core.Tempus.POST, _u_pos, _u_side, _battle_context, _event)


func check_abilities(
	tempus: int, u_pos: int, u_side: int, battle_context: BattleContext, _event: Context.Event
) -> void:
	for _ability: Ability in get_active_abilities():
		var unit_context: BattleAbilityEvent = BattleAbilityEvent.create(
			u_pos, u_side, battle_context, _event, tempus
		)
		_ability.handle_battle_event(unit_context)


func check_draft_abilities(
	tempus: int, pos: int, context: DraftContext, event: core.CoreEvent, u: Block
) -> void:
	for _ability: Ability in get_active_abilities():
		var draft_event: DraftAbilityEvent = DraftAbilityEvent.create(
			pos, u, context, event, tempus
		)
		_ability.handle_draft_event(draft_event)


func deep_duplicate_abilities() -> Array[Ability]:
	var duplicated_abilities: Array[Ability] = []
	for ability: Ability in abilities:
		duplicated_abilities.append(ability.deep_duplicate())
	return duplicated_abilities


func deep_duplicate_effects_perm() -> Array[Variant]:
	var duplicated_effects: Array[Variant] = []
	for effect: Variant in effects_perm:
		if effect is StatEffect:
			var stat_effect: StatEffect = effect
			if not stat_effect:
				Log.error(
					"Invalid StatEffect during duplication",
					{"card_id": card_definition.id},
					[Log.TAG_ERROR]
				)
				continue
			duplicated_effects.append(stat_effect.deep_duplicate())
		else:
			duplicated_effects.append(effect.duplicate(true) if effect is Resource else effect)
	return duplicated_effects


func apply_permanent_effects_to_current_stats() -> void:
	UnitBehavior.apply_permanent_effects_to_stats(self)


func transfer_acquired_abilities_from(source_units: Array[UnitData]) -> void:
	for source_unit: UnitData in source_units:
		var acquired_abilities: Array[Ability] = source_unit.get_acquired_abilities()
		for acquired_ability: Ability in acquired_abilities:
			abilities.append(acquired_ability)
			Log.debug(
				"Transferred acquired ability from merge",
				{"ability": Utils.get_type(acquired_ability)},
				[Log.TAG_CARD, Log.TAG_MERGE, Log.TAG_ABILITY]
			)


func transfer_stat_effects_from(source_units: Array[UnitData]) -> void:
	UnitBehavior.transfer_stat_effects(self, source_units)


func transfer_merge_effects_from(source_units: Array[UnitData]) -> void:
	UnitBehavior.transfer_merge_effects(self, source_units)


func transfer_merge_effects_from_cards(source_cards: Array[Card]) -> void:
	var source_units: Array[UnitData] = []
	for card: Card in source_cards:
		source_units.append(card.unit_info)
	transfer_merge_effects_from(source_units)


func apply_permanent_changes_from(final_battle_state: UnitData) -> void:
	UnitBehavior.apply_permanent_changes_from_battle(self, final_battle_state)


func get_state_checksum() -> String:
	"""Generate deterministic checksum for complete unit state including stats, abilities, and effects"""
	return UnitBehavior.get_state_checksum(self)
