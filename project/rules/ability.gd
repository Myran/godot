class_name Ability extends Resource


func action(
	_tempus: core.Tempus,
	_u_pos: int,
	_u_side: bool,
	_battle_context: BattleContext,
	_event: BattleContext.BaseEvent
) -> void:
	pass


func draft_action(
	_tempus: core.Tempus,
	_pos: int,
	_u: Block,
	_context: DraftContext,
	_event: core.CoreEvent,
) -> void:
	pass
