class_name MergeBonusAbility extends Ability

var health_bonus: int
var attack_bonus: int


func _init(bonus_health: int = 1, bonus_attack: int = 1) -> void:
	health_bonus = bonus_health
	attack_bonus = bonus_attack


## Override deep_duplicate to ensure stat bonuses are properly copied
func deep_duplicate() -> Ability:
	var copy: MergeBonusAbility = MergeBonusAbility.new(health_bonus, attack_bonus)
	copy.persistence_type = self.persistence_type
	return copy


func handle_battle_event(
	_phase: core.Tempus,
	_unit_position: int,
	_is_allied_unit: bool,
	_battle_context: BattleContext,
	_battle_event: Context.Event
) -> void:
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

	var merge_event: core.DraftMergeEvent = draft_event as core.DraftMergeEvent
	var card: Card = unit as Card

	# Enhanced logging for debugging the self-exclusion logic
	var card_id: String = card.unit_info.card_info.get("id", "")
	var merged_card_ids: Array[String] = []
	for match_card: Card in merge_event.matches:
		merged_card_ids.append(match_card.unit_info.card_info.get("id", ""))

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

	# Exclude self - don't trigger bonus if this specific card instance is being merged
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

	# Create StatEffectEvent and add to context - this will handle the proper flow
	var stat_effect_event: core.StatEffectEvent = core.StatEffectEvent.new(
		card, health_bonus, attack_bonus, core.EventSource.SYSTEM_CASCADE
	)
	draft_context.add_event(stat_effect_event)

	Log.debug(
		"MergeBonusAbility: Triggered bonus for other card merge",
		{
			"bonus_recipient": card_id,
			"merged_card_ids": merged_card_ids,
			"matches_count": merge_event.matches.size(),
			"health_bonus": health_bonus,
			"attack_bonus": attack_bonus
		},
		[Log.TAG_ABILITY, Log.TAG_MERGE, Log.TAG_EFFECT]
	)


func debug_trigger_effect(target_card: Card) -> bool:
	# Create StatEffectEvent and process directly via core.action
	var stat_effect_event: core.StatEffectEvent = core.StatEffectEvent.new(
		target_card, health_bonus, attack_bonus, core.EventSource.DEBUG_SETUP
	)
	core.action(stat_effect_event)
	return true
