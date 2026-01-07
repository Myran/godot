class_name TargetingPreferenceAbility extends Ability

## Targeting preference ability (task-394)
## Combat-triggered ability: Prefers targeting back row units

enum TargetRow {
	FRONT,  # Front row (positions 0-4)
	BACK,  # Back row (positions 5-9)
}

var target_row: TargetRow


func _init(preferred_row: TargetRow = TargetRow.BACK) -> void:
	target_row = preferred_row


func get_handled_event_classes() -> Array:
	return [BattleContext.CombatEvent]


func handle_battle_event(event: BattleAbilityEvent) -> void:
	if not AbilityHelper.should_process_event(self, event.event):
		return

	# Set targeting preference before combat resolution
	if AbilityHelper.is_combat_pre(event) and event.is_event_from_this_unit():
		# Store targeting preference in unit data for combat system to use
		var self_unit: UnitData = event.get_self_unit()
		if self_unit:
			self_unit.targeting_preference = target_row


func deep_duplicate() -> Ability:
	var copy: TargetingPreferenceAbility = TargetingPreferenceAbility.new(target_row)
	copy.persistence_type = self.persistence_type
	return copy


func serialize_to_dict() -> Dictionary:
	var base_data: Dictionary = super.serialize_to_dict()
	base_data["target_row"] = target_row
	return base_data
