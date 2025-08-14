class_name EvilSynergyAbility extends Ability

var health_per_evil: int
var attack_per_evil: int


func _init(health_bonus: int = 1, attack_bonus: int = 1) -> void:
	health_per_evil = health_bonus
	attack_per_evil = attack_bonus


func deep_duplicate() -> Ability:
	var copy: EvilSynergyAbility = EvilSynergyAbility.new(health_per_evil, attack_per_evil)
	copy.persistence_type = self.persistence_type
	return copy


func handle_battle_event(event: BattleAbilityEvent) -> void:
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

	var evil_unit_count: int = AbilityHelper.count_units_with_tags_in_lineup(
		event.draft_context.lineup, [GameConstants.UnitTags.EVIL], event.unit
	)

	if evil_unit_count > 0:
		var total_health_bonus: int = health_per_evil * evil_unit_count
		var total_attack_bonus: int = attack_per_evil * evil_unit_count
		AbilityHelper.apply_permanent_stat_bonus(event, total_health_bonus, total_attack_bonus)
