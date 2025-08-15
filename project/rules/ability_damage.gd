class_name AbilityDamage extends Ability

var damage_type: String


func _init(type: String) -> void:
	damage_type = type


func deep_duplicate() -> Ability:
	var copy: AbilityDamage = AbilityDamage.new(damage_type)
	copy.persistence_type = self.persistence_type
	return copy


@warning_ignore("unused_parameter")


func handle_battle_event(event: BattleAbilityEvent) -> void:
	pass


@warning_ignore("unused_parameter")


func handle_draft_event(event: DraftAbilityEvent) -> void:
	print("Draft action processing")
