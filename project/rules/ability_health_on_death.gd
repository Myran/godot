class_name AbilityHealthOnDeath extends Ability
var health_add = 1


func _init(_health_add = 1):
	health_add = _health_add


func condition(
	_tempus: core.Tempus,
	_u_pos: int,
	_u_side: bool,
	_context: BattleContext,
	_event: BattleContext.BaseEvent
) -> bool:
	if _tempus == core.Tempus.POST:
		return _event is BattleContext.DeathEvent
	return false


func action(
	_tempus: core.Tempus,
	_u_pos: int,
	_u_side: bool,
	_battle_context: BattleContext,
	_event: BattleContext.BaseEvent
):
	var new_event = BattleContext.StatChangeEvent.new("current_health", _u_pos, _u_side, health_add)
	_battle_context.add_event(new_event)
