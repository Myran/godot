class_name AbilityShield extends Ability

var shield_used: bool = false


func action(
	_tempus: core.Tempus,
	_u_pos: int,
	_u_side: bool,
	_context: BattleContext,
	_event: BattleContext.BaseEvent
) -> void:
	if _tempus == core.Tempus.PRE and _event is BattleContext.DamageEvent:
		var valid_target: bool = _event.side == _u_side and _event.target == _u_pos
		if valid_target and not shield_used:
			_event.effects.append({"name": "shield", "ability": self})


func draft_action(
	_tempus: core.Tempus,
	_pos: int,
	_u: Block,
	_context: DraftContext,
	_event: core.CoreEvent,
) -> void:
	if _tempus == core.Tempus.POST and _event is core.BlockEntersPlay:
		printt("u and event.block", _u, _event.block)
		if _u == _event.block:
			if shield_used == false:
				var card: Card = _u
				card.show_shield()
