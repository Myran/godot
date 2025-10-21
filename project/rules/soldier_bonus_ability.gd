class_name SoldierBonusAbility extends Ability

var health_per_soldier: int
var attack_per_soldier: int


func _init(health_bonus: int = 1, attack_bonus: int = 1) -> void:
	health_per_soldier = health_bonus
	attack_per_soldier = attack_bonus


func deep_duplicate() -> Ability:
	var copy: SoldierBonusAbility = SoldierBonusAbility.new(health_per_soldier, attack_per_soldier)
	copy.persistence_type = self.persistence_type
	return copy


func serialize_to_dict() -> Dictionary:
	var base_data: Dictionary = super.serialize_to_dict()
	base_data["health_per_soldier"] = health_per_soldier
	base_data["attack_per_soldier"] = attack_per_soldier
	return base_data


@warning_ignore("unused_parameter")
func handle_battle_event(_event: BattleAbilityEvent) -> void:
	pass


func handle_draft_event(event: DraftAbilityEvent) -> void:
	if event.phase != core.Tempus.POST:
		return

	# Only trigger when this Guard moves from draft to lineup
	if not event.event is core.LineupAddCardFromDraftEvent:
		return

	var add_event: core.LineupAddCardFromDraftEvent = event.event
	var added_card: Card = add_event.card
	if added_card != event.unit:
		return

	var soldier_unit_count: int = AbilityHelper.count_units_with_tags_in_lineup(
		event.draft_context.lineup, [GameConstants.UnitTags.SOLDIER], event.unit
	)

	if soldier_unit_count > 0:
		var total_health_bonus: int = health_per_soldier * soldier_unit_count
		var total_attack_bonus: int = attack_per_soldier * soldier_unit_count
		AbilityHelper.apply_permanent_stat_bonus(event, total_health_bonus, total_attack_bonus)
