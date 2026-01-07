class_name ArcherAbility extends Ability

## Archer first strike and arrow volley mechanics (task-034)
## Combat-triggered ability: First strike + arrow volley based on forest allies

var arrow_damage: int


func _init(damage: int = 1) -> void:
	arrow_damage = damage


func get_handled_event_classes() -> Array:
	return [BattleContext.CombatEvent, BattleContext.StartOfTurnEvent]


func handle_battle_event(event: BattleAbilityEvent) -> void:
	if not AbilityHelper.should_process_event(self, event.event):
		return

	# First Strike - handled automatically by combat system timing
	# No custom logic needed as combat_pre phase gives this unit priority

	# Arrow Volley - triggers at start of battle (first turn)
	if event.event is BattleContext.StartOfTurnEvent:
		# Only trigger on first turn of battle for initial volley
		if AbilityHelper.is_start_of_turn_post(event):
			_firing_arrow_volley(event)


func _firing_arrow_volley(event: BattleAbilityEvent) -> void:
	"""Fire arrows at random enemies, one per forest ally"""
	var forest_count: int = AbilityHelper.count_battle_units_with_tags(event, ["forest"])

	if forest_count > 0:
		# Shoot one arrow per forest ally at random enemies
		AbilityHelper.deal_damage_to_random_enemy(event, arrow_damage, forest_count)


func deep_duplicate() -> Ability:
	var copy: ArcherAbility = ArcherAbility.new(arrow_damage)
	copy.persistence_type = self.persistence_type
	return copy


func serialize_to_dict() -> Dictionary:
	var base_data: Dictionary = super.serialize_to_dict()
	base_data["arrow_damage"] = arrow_damage
	return base_data
