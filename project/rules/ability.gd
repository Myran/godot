class_name Ability extends Resource


func condition(
	_tempus: core.Tempus,
	_u_pos: int,
	_u_side: bool,
	_context: BattleContext,
	_event: BattleContext.BaseEvent
) -> bool:
	return false


func action(
	_tempus: core.Tempus,
	_u_pos: int,
	_u_side: bool,
	_battle_context: BattleContext,
	_event: BattleContext.BaseEvent
):
	pass


func draft_condition(
	_tempus: core.Tempus,
	_pos: int,
	_u: Block,
	_context: DraftContext,
	_event: core.CoreEvent,
):
	return false


func draft_action(
	_tempus: core.Tempus,
	_pos: int,
	_u: Block,
	_context: DraftContext,
	_event: core.CoreEvent,
):
	pass
