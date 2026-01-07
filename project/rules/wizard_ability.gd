class_name WizardAbility extends Ability

## Wizard zap mechanics (task-041)
## Combat-triggered ability: Chain lightning dealing damage to random enemies

var zap_damage: int
var zaps_per_level: int


func _init(damage: int = 1, per_level: int = 1) -> void:
	zap_damage = damage
	zaps_per_level = per_level


func get_handled_event_classes() -> Array:
	return [BattleContext.CombatEvent]


func handle_battle_event(event: BattleAbilityEvent) -> void:
	if not AbilityHelper.should_process_event(self, event.event):
		return

	if AbilityHelper.is_combat_pre(event) and event.is_event_from_this_unit():
		var self_unit: UnitData = event.get_self_unit()
		if not self_unit:
			return

		var total_zaps: int = self_unit.level * zaps_per_level
		for i: int in range(total_zaps):
			AbilityHelper.deal_damage_to_random_enemy(event, zap_damage, 1)


func deep_duplicate() -> Ability:
	var copy: WizardAbility = WizardAbility.new(zap_damage, zaps_per_level)
	copy.persistence_type = self.persistence_type
	return copy


func serialize_to_dict() -> Dictionary:
	var base_data: Dictionary = super.serialize_to_dict()
	base_data["zap_damage"] = zap_damage
	base_data["zaps_per_level"] = zaps_per_level
	return base_data
