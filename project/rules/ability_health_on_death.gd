class_name DeathTriggerHealthAbility extends Ability

var health_bonus: int


func _init(bonus_health: int = 1) -> void:
	health_bonus = bonus_health


func deep_duplicate() -> Ability:
	var copy: DeathTriggerHealthAbility = DeathTriggerHealthAbility.new(health_bonus)
	copy.persistence_type = self.persistence_type
	return copy


func handle_battle_event(unit: UnitContext) -> void:
	if unit.phase == core.Tempus.POST and unit.event is BattleContext.DeathEvent:
		var stat_event: BattleContext.StatChangeEvent = BattleContext.StatChangeEvent.new(
			Battle.UNIT_HEALTH, unit.position, unit.is_allied, health_bonus
		)
		unit.battle_context.add_event(stat_event)
