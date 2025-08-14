class_name AbilityDamage extends Ability

var damage_type: String


func _init(type: String) -> void:
	damage_type = type


func deep_duplicate() -> Ability:
	var copy: AbilityDamage = AbilityDamage.new(damage_type)
	copy.persistence_type = self.persistence_type
	return copy


func handle_battle_event(unit: UnitContext) -> void:
	pass


func handle_draft_event(
	_phase: core.Tempus,
	_unit_pos: int,
	_unit: Block,
	_draft_context: DraftContext,
	_event: core.CoreEvent
) -> void:
	print("Draft action processing")
