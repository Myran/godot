# abilities/merge_bonus_ability.gd
class_name MergeBonusAbility extends Ability

var health_bonus: int
var attack_bonus: int

func _init(bonus_health: int = 1, bonus_attack: int = 1) -> void:
	health_bonus = bonus_health
	attack_bonus = bonus_attack

func handle_draft_event(phase: core.Tempus, _unit_position: int, unit: Block, draft_context: DraftContext, draft_event: core.CoreEvent) -> void:
	if phase != core.Tempus.POST:
		return

	if not draft_event is core.DraftMergeEvent:
		return

	if not unit.block_context == Cards.CONTEXT.LINEUP:
		return

	var card: Card = unit as Card
	var stat_event: core.CardStatChangeEvent = core.CardStatChangeEvent.new(
		card,
		health_bonus,
		attack_bonus
	)
	draft_context.add_event(stat_event)
