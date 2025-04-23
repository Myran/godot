# abilities/death_trigger_health_ability.gd
class_name DeathTriggerHealthAbility extends Ability

var health_bonus: int


func _init(bonus_health: int = 1) -> void:
	health_bonus = bonus_health


func handle_battle_event(
	phase: core.Tempus,
	unit_position: int,
	is_allied_unit: bool,
	battle_context: BattleContext,
	battle_event: Context.Event
) -> void:
	if phase == core.Tempus.POST and battle_event is BattleContext.DeathEvent:
		var stat_event: BattleContext.StatChangeEvent = BattleContext.StatChangeEvent.new(
			Battle.UNIT_HEALTH, unit_position, is_allied_unit, health_bonus
		)
		battle_context.add_event(stat_event)