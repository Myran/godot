# rules/damage_shield_ability.gd
class_name DamageShieldAbility extends Ability

var shield_used: bool = false


func handle_battle_event(
	phase: core.Tempus,
	unit_position: int,
	is_allied_unit: bool,
	_battle_context: BattleContext,
	battle_event: Context.Event
) -> void:
	if shield_used:
		return

	if phase == core.Tempus.PRE and battle_event is BattleContext.DamageEvent:
		var damage_event: BattleContext.DamageEvent = battle_event as BattleContext.DamageEvent
		var is_target_unit: bool = (
			damage_event.is_allied_side == is_allied_unit and damage_event.target_position == unit_position
		)
		if is_target_unit:
			damage_event.damage_effects.append({"effect_type": "shield", "ability": self})
			#shield_used = true


func handle_draft_event(
	phase: core.Tempus,
	_unit_position: int,
	unit: Block,
	_draft_context: DraftContext,
	draft_event: core.CoreEvent
) -> void:
	if phase == core.Tempus.POST and draft_event is core.BlockEntersPlay:
		var play_event: core.BlockEntersPlay = draft_event as core.BlockEntersPlay
		if unit == play_event.block and not shield_used:
			var card: Card = unit as Card
			card.show_shield()
