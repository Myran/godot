class_name AbilityDamage extends Ability

var damage_type: String


func _init(type: String) -> void:
	damage_type = type


func deep_duplicate() -> Ability:
	var copy: AbilityDamage = AbilityDamage.new(damage_type)
	copy.persistence_type = self.persistence_type
	return copy


func serialize_to_dict() -> Dictionary:
	var base_data: Dictionary = super.serialize_to_dict()
	base_data["damage_type"] = damage_type
	return base_data


@warning_ignore("unused_parameter")
func handle_battle_event(_event: BattleAbilityEvent) -> void:
	pass


@warning_ignore("unused_parameter")
func handle_draft_event(_event: DraftAbilityEvent) -> void:
	Log.debug("Draft action processing", {}, [Log.TAG_DRAFT, Log.TAG_ABILITY])
