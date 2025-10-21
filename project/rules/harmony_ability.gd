class_name HarmonyAbility extends Ability

var health_bonus: int = 2
var attack_bonus: int = 2


func _init(health_per_tribe: int = 2, attack_per_tribe: int = 2) -> void:
	health_bonus = health_per_tribe
	attack_bonus = attack_per_tribe


func deep_duplicate() -> Ability:
	var copy: HarmonyAbility = HarmonyAbility.new(health_bonus, attack_bonus)
	copy.persistence_type = self.persistence_type
	return copy


func serialize_to_dict() -> Dictionary:
	var base_data: Dictionary = super.serialize_to_dict()
	base_data["health_bonus"] = health_bonus
	base_data["attack_bonus"] = attack_bonus
	return base_data


@warning_ignore("unused_parameter")
func handle_battle_event(_event: BattleAbilityEvent) -> void:
	pass


func handle_draft_event(event: DraftAbilityEvent) -> void:
	if event.phase != core.Tempus.POST:
		return

	if not event.event is core.LineupAddCardFromDraftEvent:
		return

	var add_event: core.LineupAddCardFromDraftEvent = event.event
	var added_card: Card = add_event.card
	if added_card != event.unit:
		return

	var target_tribes: Array[String] = [
		GameConstants.UnitTags.SOLDIER,
		GameConstants.UnitTags.FOREST,
		GameConstants.UnitTags.EVIL,
		GameConstants.UnitTags.MAGIC
	]

	for tribe: String in target_tribes:
		apply_tribal_bonus(event, tribe)


func apply_tribal_bonus(event: DraftAbilityEvent, tribe: String) -> void:
	var tribal_units: Array[Card] = AbilityHelper.get_units_with_tag_in_lineup(
		event.draft_context.lineup, tribe, event.unit
	)

	if tribal_units.is_empty():
		return

	var random_unit: Card = tribal_units[rng.seeded_rng.next() % tribal_units.size()]
	AbilityHelper.apply_permanent_stat_bonus_to_unit(event, random_unit, health_bonus, attack_bonus)
