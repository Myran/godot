class_name SpearmanAbility extends Ability

## Spearman breakthrough damage mechanics (task-043)
## Combat-triggered ability: Damages unit behind primary target (same column, back row)

var breakthrough_damage: int


func _init(damage: int = 1) -> void:
	breakthrough_damage = damage


func get_handled_event_classes() -> Array:
	return [BattleContext.CombatEvent]


func handle_battle_event(event: BattleAbilityEvent) -> void:
	if not AbilityHelper.should_process_event(self, event.event):
		return

	# Trigger after successful combat (primary attack resolved)
	if AbilityHelper.is_combat_post(event) and event.is_event_from_this_unit():
		var combat_event: BattleContext.CombatEvent = event.event as BattleContext.CombatEvent
		if not combat_event:
			return

		# Get the defender position (primary target of the attack)
		var defender_position: int = combat_event.defender_position

		# Deal breakthrough damage to unit(s) behind the primary target
		AbilityHelper.deal_breakthrough_damage(event, defender_position, breakthrough_damage)


func deep_duplicate() -> Ability:
	var copy: SpearmanAbility = SpearmanAbility.new(breakthrough_damage)
	copy.persistence_type = self.persistence_type
	return copy


func serialize_to_dict() -> Dictionary:
	var base_data: Dictionary = super.serialize_to_dict()
	base_data["breakthrough_damage"] = breakthrough_damage
	return base_data
