class_name MergeBonusAbility
extends Ability

var base_health_bonus: int
var base_attack_bonus: int


func _init(base_health: int = 1, base_attack: int = 1) -> void:
	base_health_bonus = base_health
	base_attack_bonus = base_attack


func deep_duplicate() -> Ability:
	var copy: MergeBonusAbility = MergeBonusAbility.new(base_health_bonus, base_attack_bonus)
	copy.persistence_type = self.persistence_type
	return copy


func handle_battle_event(unit: UnitContext) -> void:
	pass


func handle_draft_event(
	phase: core.Tempus,
	_unit_position: int,
	unit: Block,
	draft_context: DraftContext,
	draft_event: core.CoreEvent
) -> void:
	if phase != core.Tempus.POST:
		return

	if not draft_event is core.DraftMergeEvent:
		return

	if not unit.block_context == Cards.CONTEXT.LINEUP:
		return

	var merge_event: core.DraftMergeEvent = draft_event
	var card: Card = unit

	var card_id: String = card.unit_info.card_info.get("id", "")
	var merged_card_ids: Array[String] = []
	for match_card: Card in merge_event.matches:
		merged_card_ids.append(match_card.unit_info.card_info.get("id", ""))
	var level: int = card.level
	var calc_attack_bonus: int = base_attack_bonus * level
	var calc_health_bonus: int = base_health_bonus * level

	Log.debug(
		"MergeBonusAbility: Evaluating merge event",
		{
			"evaluating_card_id": card_id,
			"merged_card_ids": merged_card_ids,
			"matches_count": merge_event.matches.size(),
			"card_instance_in_merge": merge_event.matches.has(card)
		},
		[Log.TAG_ABILITY, Log.TAG_MERGE, Log.TAG_DEBUG]
	)

	if merge_event.matches.has(card):
		Log.debug(
			"MergeBonusAbility: Skipping self-trigger - this card instance is being merged",
			{
				"card_id": card_id,
				"matches_count": merge_event.matches.size(),
				"card_instance_in_merge": true
			},
			[Log.TAG_ABILITY, Log.TAG_MERGE, Log.TAG_EFFECT]
		)
		return

	var stat_effect_event: core.StatEffectEvent = core.StatEffectEvent.new(
		card, calc_health_bonus, calc_attack_bonus, core.EventSource.SYSTEM_CASCADE
	)
	draft_context.add_event(stat_effect_event)

	Log.debug(
		"MergeBonusAbility: Triggered bonus for other card merge",
		{
			"bonus_recipient": card_id,
			"merged_card_ids": merged_card_ids,
			"matches_count": merge_event.matches.size(),
			"health_bonus": calc_health_bonus,
			"attack_bonus": calc_attack_bonus
		},
		[Log.TAG_ABILITY, Log.TAG_MERGE, Log.TAG_EFFECT]
	)
