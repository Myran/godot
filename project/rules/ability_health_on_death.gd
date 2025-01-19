class_name AbilityHealthOnDeath extends Ability
var health_add: int = 1


func _init(_health_add: int = 1) -> void:
	health_add = _health_add


func action(
	_tempus: core.Tempus,
	_u_pos: int,
	_u_side: bool,
	_battle_context: BattleContext,
	_event: BattleContext.BaseEvent
) -> void:
	if _tempus == core.Tempus.POST:
		if _event is BattleContext.DeathEvent:
			_battle_context.add_event(
				BattleContext.StatChangeEvent.new("current_health", _u_pos, _u_side, health_add)
			)
