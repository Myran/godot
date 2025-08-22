class_name Ability extends Resource

# Inherent to card template, never removed
# Gained during combat, converted to ENHANCEMENT post-battle
# Combat-only effects, cleared after battle
# Permanent effects from any source, transferable in merges
enum PersistenceType { TEMPLATE, ACQUIRED, TEMPORARY, ENHANCEMENT }

var persistence_type: PersistenceType = PersistenceType.TEMPLATE

@warning_ignore("unused_parameter")


func get_handled_event_classes() -> Array:
	return []


func handle_battle_event(_event: BattleAbilityEvent) -> void:
	pass


@warning_ignore("unused_parameter")


func handle_draft_event(_event: DraftAbilityEvent) -> void:
	pass


func deep_duplicate() -> Ability:
	var copy: Ability = self.duplicate(true)
	copy.persistence_type = self.persistence_type
	return copy


func serialize_to_dict() -> Dictionary:
	var class_name_result: String = get_script().get_global_name()
	Log.debug(
		"Ability serialization - class name detected",
		{
			"detected_class_name": class_name_result,
			"get_class_result": get_class(),
			"persistence_type": persistence_type
		},
		["serialization", "ability", "debug"]
	)
	return {"type": class_name_result, "persistence_type": persistence_type}


func debug_trigger_effect(_target_card: Card) -> bool:
	Log.warning(
		"debug_trigger_effect not implemented for ability type",
		{"ability_type": get_class()},
		["debug", "ability"]
	)
	return false
