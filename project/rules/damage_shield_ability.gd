class_name DamageShieldAbility extends Ability

var shield_used: bool = false


func deep_duplicate() -> Ability:
	var copy: DamageShieldAbility = DamageShieldAbility.new()
	copy.persistence_type = self.persistence_type
	copy.shield_used = self.shield_used
	return copy


func handle_battle_event(unit: UnitContext) -> void:
	if shield_used:
		return

	if unit.phase == core.Tempus.PRE and unit.event is BattleContext.DamageEvent:
		var damage_event: BattleContext.DamageEvent = unit.event as BattleContext.DamageEvent
		var is_target_unit: bool = (
			damage_event.is_allied_side == unit.is_allied
			and damage_event.target_position == unit.position
		)
		if is_target_unit:
			damage_event.damage_effects.append({"effect_type": "shield", "ability": self})


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
