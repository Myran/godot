class_name BarbarianAbility extends Ability

## Barbarian ally bonus mechanics (task-044)
## Death-triggered ability: Grants +1/+1 to all allies when any ENEMY dies

var health_bonus: int
var attack_bonus: int


func _init(health: int = 1, attack: int = 1) -> void:
	health_bonus = health
	attack_bonus = attack


func get_handled_event_classes() -> Array:
	return [BattleContext.DeathEvent]


func handle_battle_event(event: BattleAbilityEvent) -> void:
	if not AbilityHelper.should_process_event(self, event.event):
		return

	if AbilityHelper.is_death_post(event) and not event.is_allied:
		AbilityHelper.grant_ally_bonuses(event, health_bonus, attack_bonus)


func deep_duplicate() -> Ability:
	var copy: BarbarianAbility = BarbarianAbility.new(health_bonus, attack_bonus)
	copy.persistence_type = self.persistence_type
	return copy


func serialize_to_dict() -> Dictionary:
	var base_data: Dictionary = super.serialize_to_dict()
	base_data["health_bonus"] = health_bonus
	base_data["attack_bonus"] = attack_bonus
	return base_data
