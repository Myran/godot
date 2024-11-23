class_name AbilityShield extends Ability

var shield_used: bool = false


func condition(
	_tempus: core.Tempus,
	_u_pos: int,
	_u_side: bool,
	_context: BattleContext,
	_event: BattleContext.BaseEvent
) -> bool:
	if not (_tempus == core.Tempus.PRE and _event is BattleContext.DamageEvent):
		return false

	var valid_target: bool = _event.side == _u_side and _event.target == _u_pos

	return valid_target and not shield_used


func action(
	_tempus: core.Tempus,
	_u_pos: int,
	_u_side: bool,
	_battle_context: BattleContext,
	_event: BattleContext.BaseEvent
):
	_event.effects.append({"name": "shield", "ability": self})
