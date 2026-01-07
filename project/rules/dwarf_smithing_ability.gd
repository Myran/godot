class_name DwarfSmithingAbility extends Ability

## Dwarf smithing synergy (task-394)
## Draft-triggered ability: Grants soldier allies bonuses per dwarf level in play

var health_per_dwarf: int
var attack_per_dwarf: int


func _init(health_bonus: int = 1, attack_bonus: int = 1) -> void:
	health_per_dwarf = health_bonus
	attack_per_dwarf = attack_bonus


func get_handled_event_classes() -> Array:
	return [core.LineupAddCardFromDraftEvent]


func handle_draft_event(event: DraftAbilityEvent) -> void:
	if event.phase != core.Tempus.POST:
		return

	# Trigger when any card is added to lineup (dwarf affects soldiers)
	if not event.event is core.LineupAddCardFromDraftEvent:
		return

	var add_event: core.LineupAddCardFromDraftEvent = event.event
	var added_card: Card = add_event.card

	# Only trigger for soldiers when dwarves are added
	var added_tribe: String = added_card.unit_info.card_definition.tribe
	if added_tribe != "soldier":
		return

	# Count dwarves in lineup
	var dwarf_count: int = AbilityHelper.count_units_with_tags_in_lineup(
		event.draft_context.lineup, ["dwarf"], event.unit
	)

	if dwarf_count > 0:
		var total_health_bonus: int = health_per_dwarf * dwarf_count
		var total_attack_bonus: int = attack_per_dwarf * dwarf_count
		AbilityHelper.apply_permanent_stat_bonus_to_unit(
			event, added_card, total_health_bonus, total_attack_bonus
		)


func deep_duplicate() -> Ability:
	var copy: DwarfSmithingAbility = DwarfSmithingAbility.new(health_per_dwarf, attack_per_dwarf)
	copy.persistence_type = self.persistence_type
	return copy


func serialize_to_dict() -> Dictionary:
	var base_data: Dictionary = super.serialize_to_dict()
	base_data["health_per_dwarf"] = health_per_dwarf
	base_data["attack_per_dwarf"] = attack_per_dwarf
	return base_data
